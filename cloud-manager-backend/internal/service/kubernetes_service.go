package service

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/cloud"
	"github.com/vide/cloud-manager-backend/internal/models"
	"github.com/vide/cloud-manager-backend/internal/repository"
	"go.uber.org/zap"
)

// KubernetesService handles Kubernetes business logic
type KubernetesService struct {
	providerRepo    *repository.CloudProviderRepository
	resourceRepo    *repository.CloudResourceRepository
	auditLogRepo    *repository.AuditLogRepository
	providerFactory *cloud.ProviderFactory
	logger          *zap.Logger
}

// NewKubernetesService creates a new KubernetesService
func NewKubernetesService(
	providerRepo *repository.CloudProviderRepository,
	resourceRepo *repository.CloudResourceRepository,
	auditLogRepo *repository.AuditLogRepository,
	providerFactory *cloud.ProviderFactory,
	logger *zap.Logger,
) *KubernetesService {
	return &KubernetesService{
		providerRepo:    providerRepo,
		resourceRepo:    resourceRepo,
		auditLogRepo:    auditLogRepo,
		providerFactory: providerFactory,
		logger:          logger,
	}
}

// ListClusters lists all Kubernetes clusters
func (s *KubernetesService) ListClusters(ctx context.Context, providerID uuid.UUID, region string) ([]*cloud.KubernetesCluster, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	clusters, err := cloudProvider.ListClusters(ctx, region)
	if err != nil {
		s.logger.Error("Failed to list clusters", zap.Error(err))
		return nil, err
	}

	return clusters, nil
}

// GetCluster gets a specific Kubernetes cluster
func (s *KubernetesService) GetCluster(ctx context.Context, providerID uuid.UUID, clusterID, region string) (*cloud.KubernetesCluster, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	cluster, err := cloudProvider.GetCluster(ctx, clusterID, region)
	if err != nil {
		s.logger.Error("Failed to get cluster", zap.Error(err), zap.String("cluster_id", clusterID))
		return nil, err
	}

	return cluster, nil
}

// CreateCluster creates a new Kubernetes cluster
func (s *KubernetesService) CreateCluster(ctx context.Context, userID, providerID uuid.UUID, config *cloud.ClusterConfig) (*cloud.KubernetesCluster, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	cluster, err := cloudProvider.CreateCluster(ctx, config)
	if err != nil {
		s.logger.Error("Failed to create cluster", zap.Error(err))
		return nil, err
	}

	// Create resource record
	resource := &models.CloudResource{
		ProviderID:   providerID,
		ResourceType: models.ResourceTypeKubernetes,
		ResourceID:   cluster.ID,
		Name:         cluster.Name,
		Region:       cluster.Region,
		Status:       cluster.Status,
	}
	s.resourceRepo.Create(ctx, resource)

	s.logAudit(ctx, userID, &resource.ID, "cluster_created", map[string]interface{}{
		"cluster_id":   cluster.ID,
		"cluster_name": cluster.Name,
		"version":      cluster.Version,
	})

	return cluster, nil
}

// DeleteCluster deletes a Kubernetes cluster
func (s *KubernetesService) DeleteCluster(ctx context.Context, userID, providerID uuid.UUID, clusterID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.DeleteCluster(ctx, clusterID, region); err != nil {
		s.logger.Error("Failed to delete cluster", zap.Error(err), zap.String("cluster_id", clusterID))
		return err
	}

	// Update resource record
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, clusterID)
	if resource != nil {
		resource.Status = "deleted"
		s.resourceRepo.Update(ctx, resource)

		s.logAudit(ctx, userID, &resource.ID, "cluster_deleted", map[string]interface{}{
			"cluster_id": clusterID,
		})
	}

	return nil
}

// GetClusterNodes gets nodes in a cluster
func (s *KubernetesService) GetClusterNodes(ctx context.Context, providerID uuid.UUID, clusterID, region string) ([]*cloud.ClusterNode, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	nodes, err := cloudProvider.GetClusterNodes(ctx, clusterID, region)
	if err != nil {
		s.logger.Error("Failed to get cluster nodes", zap.Error(err), zap.String("cluster_id", clusterID))
		return nil, err
	}

	return nodes, nil
}

// ScaleCluster scales a Kubernetes cluster
func (s *KubernetesService) ScaleCluster(ctx context.Context, userID, providerID uuid.UUID, clusterID, nodePoolID, region string, nodeCount int) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.ScaleCluster(ctx, clusterID, nodePoolID, nodeCount, region); err != nil {
		s.logger.Error("Failed to scale cluster", zap.Error(err), zap.String("cluster_id", clusterID))
		return err
	}

	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, clusterID)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "cluster_scaled", map[string]interface{}{
			"cluster_id":   clusterID,
			"node_pool_id": nodePoolID,
			"node_count":   nodeCount,
		})
	}

	return nil
}

// UpgradeCluster upgrades a Kubernetes cluster version
func (s *KubernetesService) UpgradeCluster(ctx context.Context, userID, providerID uuid.UUID, clusterID, targetVersion, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.UpgradeCluster(ctx, clusterID, targetVersion, region); err != nil {
		s.logger.Error("Failed to upgrade cluster", zap.Error(err), zap.String("cluster_id", clusterID))
		return err
	}

	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, clusterID)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "cluster_upgraded", map[string]interface{}{
			"cluster_id":     clusterID,
			"target_version": targetVersion,
		})
	}

	return nil
}

// GetKubeconfig gets kubeconfig for a cluster
func (s *KubernetesService) GetKubeconfig(ctx context.Context, providerID uuid.UUID, clusterID, region string) (string, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return "", err
	}

	if region == "" {
		region = provider.Region
	}

	kubeconfig, err := cloudProvider.GetKubeconfig(ctx, clusterID, region)
	if err != nil {
		s.logger.Error("Failed to get kubeconfig", zap.Error(err), zap.String("cluster_id", clusterID))
		return "", err
	}

	return kubeconfig, nil
}

// ListNodePools lists node pools in a cluster
func (s *KubernetesService) ListNodePools(ctx context.Context, providerID uuid.UUID, clusterID, region string) ([]*cloud.NodePool, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	pools, err := cloudProvider.ListNodePools(ctx, clusterID, region)
	if err != nil {
		s.logger.Error("Failed to list node pools", zap.Error(err), zap.String("cluster_id", clusterID))
		return nil, err
	}

	return pools, nil
}

// CreateNodePool creates a node pool in a cluster
func (s *KubernetesService) CreateNodePool(ctx context.Context, userID, providerID uuid.UUID, clusterID, region string, config *cloud.NodePoolConfig) (*cloud.NodePool, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	pool, err := cloudProvider.CreateNodePool(ctx, clusterID, config, region)
	if err != nil {
		s.logger.Error("Failed to create node pool", zap.Error(err), zap.String("cluster_id", clusterID))
		return nil, err
	}

	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, clusterID)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "node_pool_created", map[string]interface{}{
			"cluster_id":     clusterID,
			"node_pool_name": pool.Name,
			"node_count":     pool.NodeCount,
		})
	}

	return pool, nil
}

// DeleteNodePool deletes a node pool from a cluster
func (s *KubernetesService) DeleteNodePool(ctx context.Context, userID, providerID uuid.UUID, clusterID, nodePoolID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.DeleteNodePool(ctx, clusterID, nodePoolID, region); err != nil {
		s.logger.Error("Failed to delete node pool", zap.Error(err), zap.String("node_pool_id", nodePoolID))
		return err
	}

	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, clusterID)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "node_pool_deleted", map[string]interface{}{
			"cluster_id":   clusterID,
			"node_pool_id": nodePoolID,
		})
	}

	return nil
}

// getCloudProvider helper to get provider and cloud interface
func (s *KubernetesService) getCloudProvider(ctx context.Context, providerID uuid.UUID) (*models.CloudProvider, cloud.CloudProvider, error) {
	provider, err := s.providerRepo.GetByID(ctx, providerID)
	if err != nil {
		return nil, nil, errors.New("provider not found")
	}

	cloudProvider, err := s.providerFactory.GetProvider(provider)
	if err != nil {
		return nil, nil, err
	}

	return provider, cloudProvider, nil
}

func (s *KubernetesService) logAudit(ctx context.Context, userID uuid.UUID, resourceID *uuid.UUID, action string, details map[string]interface{}) {
	audit := &models.AuditLog{
		UserID:     userID,
		ResourceID: resourceID,
		Action:     action,
		Details:    details,
	}
	_ = s.auditLogRepo.Create(ctx, audit)
}

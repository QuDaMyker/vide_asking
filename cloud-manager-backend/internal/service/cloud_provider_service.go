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

// CloudProviderService handles cloud provider business logic
type CloudProviderService struct {
	providerRepo   *repository.CloudProviderRepository
	resourceRepo   *repository.CloudResourceRepository
	auditLogRepo   *repository.AuditLogRepository
	providerFactory *cloud.ProviderFactory
	logger         *zap.Logger
}

// NewCloudProviderService creates a new CloudProviderService
func NewCloudProviderService(
	providerRepo *repository.CloudProviderRepository,
	resourceRepo *repository.CloudResourceRepository,
	auditLogRepo *repository.AuditLogRepository,
	providerFactory *cloud.ProviderFactory,
	logger *zap.Logger,
) *CloudProviderService {
	return &CloudProviderService{
		providerRepo:   providerRepo,
		resourceRepo:   resourceRepo,
		auditLogRepo:   auditLogRepo,
		providerFactory: providerFactory,
		logger:         logger,
	}
}

// ListProviders returns all providers for a user
func (s *CloudProviderService) ListProviders(ctx context.Context, userID uuid.UUID, offset, limit int) ([]*models.CloudProvider, int, error) {
	providers, err := s.providerRepo.ListByUserID(ctx, userID, offset, limit)
	if err != nil {
		return nil, 0, err
	}

	total, err := s.providerRepo.CountByUserID(ctx, userID)
	if err != nil {
		return nil, 0, err
	}

	return providers, total, nil
}

// GetProvider returns a provider by ID
func (s *CloudProviderService) GetProvider(ctx context.Context, providerID uuid.UUID) (*models.CloudProvider, error) {
	return s.providerRepo.GetByID(ctx, providerID)
}

// CreateProvider creates a new cloud provider
func (s *CloudProviderService) CreateProvider(ctx context.Context, provider *models.CloudProvider) error {
	if err := s.providerRepo.Create(ctx, provider); err != nil {
		return err
	}

	s.logAudit(ctx, provider.UserID, nil, "provider_created", map[string]interface{}{
		"provider_id":   provider.ID,
		"provider_type": provider.ProviderType,
	})

	return nil
}

// UpdateProvider updates a cloud provider
func (s *CloudProviderService) UpdateProvider(ctx context.Context, provider *models.CloudProvider) error {
	if err := s.providerRepo.Update(ctx, provider); err != nil {
		return err
	}

	s.logAudit(ctx, provider.UserID, nil, "provider_updated", map[string]interface{}{
		"provider_id": provider.ID,
	})

	return nil
}

// DeleteProvider deletes a cloud provider
func (s *CloudProviderService) DeleteProvider(ctx context.Context, providerID uuid.UUID) error {
	provider, err := s.providerRepo.GetByID(ctx, providerID)
	if err != nil {
		return err
	}

	if err := s.providerRepo.Delete(ctx, providerID); err != nil {
		return err
	}

	s.logAudit(ctx, provider.UserID, nil, "provider_deleted", map[string]interface{}{
		"provider_id": providerID,
	})

	return nil
}

// TestConnection tests the connection to a cloud provider
func (s *CloudProviderService) TestConnection(ctx context.Context, providerID uuid.UUID) error {
	provider, err := s.providerRepo.GetByID(ctx, providerID)
	if err != nil {
		return err
	}

	cloudProvider, err := s.providerFactory.GetProvider(provider)
	if err != nil {
		return err
	}

	// Try to list instances as a connection test
	_, err = cloudProvider.ListInstances(ctx, provider.Region, nil)
	if err != nil {
		provider.Status = "error"
		s.providerRepo.Update(ctx, provider)
		return errors.New("failed to connect to provider: " + err.Error())
	}

	provider.Status = "active"
	s.providerRepo.Update(ctx, provider)
	return nil
}

// SyncResources synchronizes resources from the cloud provider
func (s *CloudProviderService) SyncResources(ctx context.Context, providerID uuid.UUID) (int, error) {
	provider, err := s.providerRepo.GetByID(ctx, providerID)
	if err != nil {
		return 0, err
	}

	cloudProvider, err := s.providerFactory.GetProvider(provider)
	if err != nil {
		return 0, err
	}

	totalSynced := 0

	// Sync compute instances
	instances, err := cloudProvider.ListInstances(ctx, provider.Region, nil)
	if err == nil {
		for _, instance := range instances {
			resource := &models.CloudResource{
				ProviderID:   providerID,
				ResourceType: models.ResourceTypeCompute,
				ResourceID:   instance.ID,
				Name:         instance.Name,
				Region:       instance.Region,
				Status:       instance.Status,
				Tags:         instance.Tags,
			}

			existing, _ := s.resourceRepo.GetByResourceID(ctx, providerID, instance.ID)
			if existing != nil {
				resource.ID = existing.ID
				s.resourceRepo.Update(ctx, resource)
			} else {
				s.resourceRepo.Create(ctx, resource)
			}
			totalSynced++
		}
	}

	// Sync storage buckets
	buckets, err := cloudProvider.ListBuckets(ctx)
	if err == nil {
		for _, bucket := range buckets {
			resource := &models.CloudResource{
				ProviderID:   providerID,
				ResourceType: models.ResourceTypeStorage,
				ResourceID:   bucket.Name,
				Name:         bucket.Name,
				Region:       bucket.Region,
				Status:       "active",
			}

			existing, _ := s.resourceRepo.GetByResourceID(ctx, providerID, bucket.Name)
			if existing != nil {
				resource.ID = existing.ID
				s.resourceRepo.Update(ctx, resource)
			} else {
				s.resourceRepo.Create(ctx, resource)
			}
			totalSynced++
		}
	}

	// Sync databases
	databases, err := cloudProvider.ListDatabases(ctx, provider.Region)
	if err == nil {
		for _, db := range databases {
			resource := &models.CloudResource{
				ProviderID:   providerID,
				ResourceType: models.ResourceTypeDatabase,
				ResourceID:   db.ID,
				Name:         db.Name,
				Region:       db.Region,
				Status:       db.Status,
			}

			existing, _ := s.resourceRepo.GetByResourceID(ctx, providerID, db.ID)
			if existing != nil {
				resource.ID = existing.ID
				s.resourceRepo.Update(ctx, resource)
			} else {
				s.resourceRepo.Create(ctx, resource)
			}
			totalSynced++
		}
	}

	// Sync Kubernetes clusters
	clusters, err := cloudProvider.ListClusters(ctx, provider.Region)
	if err == nil {
		for _, cluster := range clusters {
			resource := &models.CloudResource{
				ProviderID:   providerID,
				ResourceType: models.ResourceTypeKubernetes,
				ResourceID:   cluster.ID,
				Name:         cluster.Name,
				Region:       cluster.Region,
				Status:       cluster.Status,
			}

			existing, _ := s.resourceRepo.GetByResourceID(ctx, providerID, cluster.ID)
			if existing != nil {
				resource.ID = existing.ID
				s.resourceRepo.Update(ctx, resource)
			} else {
				s.resourceRepo.Create(ctx, resource)
			}
			totalSynced++
		}
	}

	s.logAudit(ctx, provider.UserID, nil, "resources_synced", map[string]interface{}{
		"provider_id":   providerID,
		"synced_count": totalSynced,
	})

	return totalSynced, nil
}

// GetProviderStats returns statistics for a provider
func (s *CloudProviderService) GetProviderStats(ctx context.Context, providerID uuid.UUID) (map[string]interface{}, error) {
	provider, err := s.providerRepo.GetByID(ctx, providerID)
	if err != nil {
		return nil, err
	}

	resources, err := s.resourceRepo.ListByProviderID(ctx, providerID, 0, 1000)
	if err != nil {
		return nil, err
	}

	stats := map[string]interface{}{
		"provider_id":   providerID,
		"provider_type": provider.ProviderType,
		"status":        provider.Status,
		"total_resources": len(resources),
		"resource_types": make(map[string]int),
		"status_breakdown": make(map[string]int),
	}

	resourceTypes := make(map[string]int)
	statusBreakdown := make(map[string]int)

	for _, r := range resources {
		resourceTypes[string(r.ResourceType)]++
		statusBreakdown[r.Status]++
	}

	stats["resource_types"] = resourceTypes
	stats["status_breakdown"] = statusBreakdown

	return stats, nil
}

// ListRegions returns available regions for a provider type
func (s *CloudProviderService) ListRegions(ctx context.Context, providerType models.ProviderType) ([]string, error) {
	switch providerType {
	case models.ProviderAWS:
		return []string{
			"us-east-1", "us-east-2", "us-west-1", "us-west-2",
			"eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1",
			"ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
			"sa-east-1", "ca-central-1",
		}, nil
	case models.ProviderGCP:
		return []string{
			"us-central1", "us-east1", "us-west1", "us-west2",
			"europe-west1", "europe-west2", "europe-west3", "europe-west4",
			"asia-east1", "asia-east2", "asia-northeast1", "asia-southeast1",
			"australia-southeast1",
		}, nil
	case models.ProviderAzure:
		return []string{
			"eastus", "eastus2", "westus", "westus2",
			"northeurope", "westeurope", "uksouth", "ukwest",
			"eastasia", "southeastasia", "japaneast", "japanwest",
			"australiaeast", "australiasoutheast",
		}, nil
	default:
		return nil, errors.New("unknown provider type")
	}
}

func (s *CloudProviderService) logAudit(ctx context.Context, userID uuid.UUID, resourceID *uuid.UUID, action string, details map[string]interface{}) {
	audit := &models.AuditLog{
		UserID:     userID,
		ResourceID: resourceID,
		Action:     action,
		Details:    details,
	}
	_ = s.auditLogRepo.Create(ctx, audit)
}

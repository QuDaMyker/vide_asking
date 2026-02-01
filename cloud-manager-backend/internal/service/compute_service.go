package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/cloud"
	"github.com/vide/cloud-manager-backend/internal/models"
	"github.com/vide/cloud-manager-backend/internal/repository"
	"go.uber.org/zap"
)

// ComputeService handles compute instance business logic
type ComputeService struct {
	providerRepo    *repository.CloudProviderRepository
	resourceRepo    *repository.CloudResourceRepository
	auditLogRepo    *repository.AuditLogRepository
	providerFactory *cloud.ProviderFactory
	logger          *zap.Logger
}

// NewComputeService creates a new ComputeService
func NewComputeService(
	providerRepo *repository.CloudProviderRepository,
	resourceRepo *repository.CloudResourceRepository,
	auditLogRepo *repository.AuditLogRepository,
	providerFactory *cloud.ProviderFactory,
	logger *zap.Logger,
) *ComputeService {
	return &ComputeService{
		providerRepo:    providerRepo,
		resourceRepo:    resourceRepo,
		auditLogRepo:    auditLogRepo,
		providerFactory: providerFactory,
		logger:          logger,
	}
}

// ListInstances lists compute instances
func (s *ComputeService) ListInstances(ctx context.Context, providerID uuid.UUID, region string, filters map[string]string) ([]*cloud.Instance, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	instances, err := cloudProvider.ListInstances(ctx, region, filters)
	if err != nil {
		s.logger.Error("Failed to list instances", zap.Error(err))
		return nil, err
	}

	return instances, nil
}

// GetInstance gets a specific compute instance
func (s *ComputeService) GetInstance(ctx context.Context, providerID uuid.UUID, instanceID, region string) (*cloud.Instance, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	instance, err := cloudProvider.GetInstance(ctx, instanceID, region)
	if err != nil {
		s.logger.Error("Failed to get instance", zap.Error(err), zap.String("instance_id", instanceID))
		return nil, err
	}

	return instance, nil
}

// CreateInstance creates a new compute instance
func (s *ComputeService) CreateInstance(ctx context.Context, userID, providerID uuid.UUID, config *cloud.InstanceConfig) (*cloud.Instance, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	instance, err := cloudProvider.CreateInstance(ctx, config)
	if err != nil {
		s.logger.Error("Failed to create instance", zap.Error(err))
		return nil, err
	}

	// Create resource record
	resource := &models.CloudResource{
		ProviderID:   providerID,
		ResourceType: models.ResourceTypeCompute,
		ResourceID:   instance.ID,
		Name:         instance.Name,
		Region:       instance.Region,
		Status:       instance.Status,
		Tags:         instance.Tags,
	}
	s.resourceRepo.Create(ctx, resource)

	s.logAudit(ctx, userID, &resource.ID, "instance_created", map[string]interface{}{
		"instance_id":   instance.ID,
		"instance_name": instance.Name,
		"instance_type": instance.InstanceType,
		"provider":      provider.ProviderType,
	})

	return instance, nil
}

// StartInstance starts a compute instance
func (s *ComputeService) StartInstance(ctx context.Context, userID, providerID uuid.UUID, instanceID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.StartInstance(ctx, instanceID, region); err != nil {
		s.logger.Error("Failed to start instance", zap.Error(err), zap.String("instance_id", instanceID))
		return err
	}

	// Update resource status
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, instanceID)
	if resource != nil {
		resource.Status = "running"
		s.resourceRepo.Update(ctx, resource)
		
		s.logAudit(ctx, userID, &resource.ID, "instance_started", map[string]interface{}{
			"instance_id": instanceID,
		})
	}

	return nil
}

// StopInstance stops a compute instance
func (s *ComputeService) StopInstance(ctx context.Context, userID, providerID uuid.UUID, instanceID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.StopInstance(ctx, instanceID, region); err != nil {
		s.logger.Error("Failed to stop instance", zap.Error(err), zap.String("instance_id", instanceID))
		return err
	}

	// Update resource status
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, instanceID)
	if resource != nil {
		resource.Status = "stopped"
		s.resourceRepo.Update(ctx, resource)
		
		s.logAudit(ctx, userID, &resource.ID, "instance_stopped", map[string]interface{}{
			"instance_id": instanceID,
		})
	}

	return nil
}

// RebootInstance reboots a compute instance
func (s *ComputeService) RebootInstance(ctx context.Context, userID, providerID uuid.UUID, instanceID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.RebootInstance(ctx, instanceID, region); err != nil {
		s.logger.Error("Failed to reboot instance", zap.Error(err), zap.String("instance_id", instanceID))
		return err
	}

	// Log audit
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, instanceID)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "instance_rebooted", map[string]interface{}{
			"instance_id": instanceID,
		})
	}

	return nil
}

// TerminateInstance terminates a compute instance
func (s *ComputeService) TerminateInstance(ctx context.Context, userID, providerID uuid.UUID, instanceID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.TerminateInstance(ctx, instanceID, region); err != nil {
		s.logger.Error("Failed to terminate instance", zap.Error(err), zap.String("instance_id", instanceID))
		return err
	}

	// Update resource status
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, instanceID)
	if resource != nil {
		resource.Status = "terminated"
		s.resourceRepo.Update(ctx, resource)
		
		s.logAudit(ctx, userID, &resource.ID, "instance_terminated", map[string]interface{}{
			"instance_id": instanceID,
		})
	}

	return nil
}

// GetInstanceMetrics gets metrics for a compute instance
func (s *ComputeService) GetInstanceMetrics(ctx context.Context, providerID uuid.UUID, instanceID string, metricNames []string, startTime, endTime time.Time, period int64) ([]*cloud.MetricData, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if len(metricNames) == 0 {
		// Default metrics
		metricNames = []string{"CPUUtilization", "NetworkIn", "NetworkOut", "DiskReadBytes", "DiskWriteBytes"}
	}

	query := &cloud.MetricQuery{
		ResourceID:  instanceID,
		MetricNames: metricNames,
		StartTime:   startTime,
		EndTime:     endTime,
		Period:      period,
		Region:      provider.Region,
	}

	metrics, err := cloudProvider.GetMetrics(ctx, query)
	if err != nil {
		s.logger.Error("Failed to get instance metrics", zap.Error(err), zap.String("instance_id", instanceID))
		return nil, err
	}

	return metrics, nil
}

// getCloudProvider helper to get provider and cloud interface
func (s *ComputeService) getCloudProvider(ctx context.Context, providerID uuid.UUID) (*models.CloudProvider, cloud.CloudProvider, error) {
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

func (s *ComputeService) logAudit(ctx context.Context, userID uuid.UUID, resourceID *uuid.UUID, action string, details map[string]interface{}) {
	audit := &models.AuditLog{
		UserID:     userID,
		ResourceID: resourceID,
		Action:     action,
		Details:    details,
	}
	_ = s.auditLogRepo.Create(ctx, audit)
}

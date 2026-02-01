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

// DatabaseService handles database business logic
type DatabaseService struct {
	providerRepo    *repository.CloudProviderRepository
	resourceRepo    *repository.CloudResourceRepository
	auditLogRepo    *repository.AuditLogRepository
	providerFactory *cloud.ProviderFactory
	logger          *zap.Logger
}

// NewDatabaseService creates a new DatabaseService
func NewDatabaseService(
	providerRepo *repository.CloudProviderRepository,
	resourceRepo *repository.CloudResourceRepository,
	auditLogRepo *repository.AuditLogRepository,
	providerFactory *cloud.ProviderFactory,
	logger *zap.Logger,
) *DatabaseService {
	return &DatabaseService{
		providerRepo:    providerRepo,
		resourceRepo:    resourceRepo,
		auditLogRepo:    auditLogRepo,
		providerFactory: providerFactory,
		logger:          logger,
	}
}

// ListDatabases lists all databases
func (s *DatabaseService) ListDatabases(ctx context.Context, providerID uuid.UUID, region string) ([]*cloud.Database, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	databases, err := cloudProvider.ListDatabases(ctx, region)
	if err != nil {
		s.logger.Error("Failed to list databases", zap.Error(err))
		return nil, err
	}

	return databases, nil
}

// GetDatabase gets a specific database
func (s *DatabaseService) GetDatabase(ctx context.Context, providerID uuid.UUID, databaseID, region string) (*cloud.Database, error) {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	if region == "" {
		region = provider.Region
	}

	database, err := cloudProvider.GetDatabase(ctx, databaseID, region)
	if err != nil {
		s.logger.Error("Failed to get database", zap.Error(err), zap.String("database_id", databaseID))
		return nil, err
	}

	return database, nil
}

// CreateDatabase creates a new database
func (s *DatabaseService) CreateDatabase(ctx context.Context, userID, providerID uuid.UUID, config *cloud.DatabaseConfig) (*cloud.Database, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	database, err := cloudProvider.CreateDatabase(ctx, config)
	if err != nil {
		s.logger.Error("Failed to create database", zap.Error(err))
		return nil, err
	}

	// Create resource record
	resource := &models.CloudResource{
		ProviderID:   providerID,
		ResourceType: models.ResourceTypeDatabase,
		ResourceID:   database.ID,
		Name:         database.Name,
		Region:       database.Region,
		Status:       database.Status,
	}
	s.resourceRepo.Create(ctx, resource)

	s.logAudit(ctx, userID, &resource.ID, "database_created", map[string]interface{}{
		"database_id":   database.ID,
		"database_name": database.Name,
		"engine":        database.Engine,
	})

	return database, nil
}

// DeleteDatabase deletes a database
func (s *DatabaseService) DeleteDatabase(ctx context.Context, userID, providerID uuid.UUID, databaseID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.DeleteDatabase(ctx, databaseID, region); err != nil {
		s.logger.Error("Failed to delete database", zap.Error(err), zap.String("database_id", databaseID))
		return err
	}

	// Update resource record
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, databaseID)
	if resource != nil {
		resource.Status = "deleted"
		s.resourceRepo.Update(ctx, resource)

		s.logAudit(ctx, userID, &resource.ID, "database_deleted", map[string]interface{}{
			"database_id": databaseID,
		})
	}

	return nil
}

// StartDatabase starts a database
func (s *DatabaseService) StartDatabase(ctx context.Context, userID, providerID uuid.UUID, databaseID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.StartDatabase(ctx, databaseID, region); err != nil {
		s.logger.Error("Failed to start database", zap.Error(err), zap.String("database_id", databaseID))
		return err
	}

	// Update resource status
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, databaseID)
	if resource != nil {
		resource.Status = "available"
		s.resourceRepo.Update(ctx, resource)

		s.logAudit(ctx, userID, &resource.ID, "database_started", map[string]interface{}{
			"database_id": databaseID,
		})
	}

	return nil
}

// StopDatabase stops a database
func (s *DatabaseService) StopDatabase(ctx context.Context, userID, providerID uuid.UUID, databaseID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.StopDatabase(ctx, databaseID, region); err != nil {
		s.logger.Error("Failed to stop database", zap.Error(err), zap.String("database_id", databaseID))
		return err
	}

	// Update resource status
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, databaseID)
	if resource != nil {
		resource.Status = "stopped"
		s.resourceRepo.Update(ctx, resource)

		s.logAudit(ctx, userID, &resource.ID, "database_stopped", map[string]interface{}{
			"database_id": databaseID,
		})
	}

	return nil
}

// CreateSnapshot creates a database snapshot
func (s *DatabaseService) CreateSnapshot(ctx context.Context, userID, providerID uuid.UUID, databaseID, snapshotName, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.CreateDatabaseSnapshot(ctx, databaseID, snapshotName, region); err != nil {
		s.logger.Error("Failed to create snapshot", zap.Error(err), zap.String("database_id", databaseID))
		return err
	}

	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, databaseID)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "snapshot_created", map[string]interface{}{
			"database_id":   databaseID,
			"snapshot_name": snapshotName,
		})
	}

	return nil
}

// RestoreSnapshot restores a database from a snapshot
func (s *DatabaseService) RestoreSnapshot(ctx context.Context, userID, providerID uuid.UUID, snapshotID, newDatabaseID, region string) error {
	provider, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if region == "" {
		region = provider.Region
	}

	if err := cloudProvider.RestoreDatabaseSnapshot(ctx, snapshotID, newDatabaseID, region); err != nil {
		s.logger.Error("Failed to restore snapshot", zap.Error(err), zap.String("snapshot_id", snapshotID))
		return err
	}

	s.logAudit(ctx, userID, nil, "database_restored", map[string]interface{}{
		"snapshot_id":     snapshotID,
		"new_database_id": newDatabaseID,
	})

	return nil
}

// getCloudProvider helper to get provider and cloud interface
func (s *DatabaseService) getCloudProvider(ctx context.Context, providerID uuid.UUID) (*models.CloudProvider, cloud.CloudProvider, error) {
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

func (s *DatabaseService) logAudit(ctx context.Context, userID uuid.UUID, resourceID *uuid.UUID, action string, details map[string]interface{}) {
	audit := &models.AuditLog{
		UserID:     userID,
		ResourceID: resourceID,
		Action:     action,
		Details:    details,
	}
	_ = s.auditLogRepo.Create(ctx, audit)
}

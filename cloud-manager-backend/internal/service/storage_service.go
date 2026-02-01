package service

import (
	"context"
	"errors"
	"io"

	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/cloud"
	"github.com/vide/cloud-manager-backend/internal/models"
	"github.com/vide/cloud-manager-backend/internal/repository"
	"go.uber.org/zap"
)

// StorageService handles storage business logic
type StorageService struct {
	providerRepo    *repository.CloudProviderRepository
	resourceRepo    *repository.CloudResourceRepository
	auditLogRepo    *repository.AuditLogRepository
	providerFactory *cloud.ProviderFactory
	logger          *zap.Logger
}

// NewStorageService creates a new StorageService
func NewStorageService(
	providerRepo *repository.CloudProviderRepository,
	resourceRepo *repository.CloudResourceRepository,
	auditLogRepo *repository.AuditLogRepository,
	providerFactory *cloud.ProviderFactory,
	logger *zap.Logger,
) *StorageService {
	return &StorageService{
		providerRepo:    providerRepo,
		resourceRepo:    resourceRepo,
		auditLogRepo:    auditLogRepo,
		providerFactory: providerFactory,
		logger:          logger,
	}
}

// ListBuckets lists all storage buckets
func (s *StorageService) ListBuckets(ctx context.Context, providerID uuid.UUID) ([]*cloud.Bucket, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	buckets, err := cloudProvider.ListBuckets(ctx)
	if err != nil {
		s.logger.Error("Failed to list buckets", zap.Error(err))
		return nil, err
	}

	return buckets, nil
}

// GetBucket gets a specific bucket
func (s *StorageService) GetBucket(ctx context.Context, providerID uuid.UUID, bucketName string) (*cloud.Bucket, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	bucket, err := cloudProvider.GetBucket(ctx, bucketName)
	if err != nil {
		s.logger.Error("Failed to get bucket", zap.Error(err), zap.String("bucket", bucketName))
		return nil, err
	}

	return bucket, nil
}

// CreateBucket creates a new bucket
func (s *StorageService) CreateBucket(ctx context.Context, userID, providerID uuid.UUID, config *cloud.BucketConfig) (*cloud.Bucket, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	bucket, err := cloudProvider.CreateBucket(ctx, config)
	if err != nil {
		s.logger.Error("Failed to create bucket", zap.Error(err))
		return nil, err
	}

	// Create resource record
	resource := &models.CloudResource{
		ProviderID:   providerID,
		ResourceType: models.ResourceTypeStorage,
		ResourceID:   bucket.Name,
		Name:         bucket.Name,
		Region:       bucket.Region,
		Status:       "active",
	}
	s.resourceRepo.Create(ctx, resource)

	s.logAudit(ctx, userID, &resource.ID, "bucket_created", map[string]interface{}{
		"bucket_name": bucket.Name,
		"region":      bucket.Region,
	})

	return bucket, nil
}

// DeleteBucket deletes a bucket
func (s *StorageService) DeleteBucket(ctx context.Context, userID, providerID uuid.UUID, bucketName string) error {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if err := cloudProvider.DeleteBucket(ctx, bucketName); err != nil {
		s.logger.Error("Failed to delete bucket", zap.Error(err), zap.String("bucket", bucketName))
		return err
	}

	// Update resource record
	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, bucketName)
	if resource != nil {
		resource.Status = "deleted"
		s.resourceRepo.Update(ctx, resource)

		s.logAudit(ctx, userID, &resource.ID, "bucket_deleted", map[string]interface{}{
			"bucket_name": bucketName,
		})
	}

	return nil
}

// ListObjects lists objects in a bucket
func (s *StorageService) ListObjects(ctx context.Context, providerID uuid.UUID, bucketName, prefix string, maxKeys int) ([]*cloud.ObjectInfo, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	objects, err := cloudProvider.ListObjects(ctx, bucketName, prefix, maxKeys)
	if err != nil {
		s.logger.Error("Failed to list objects", zap.Error(err), zap.String("bucket", bucketName))
		return nil, err
	}

	return objects, nil
}

// UploadObject uploads an object to a bucket
func (s *StorageService) UploadObject(ctx context.Context, userID, providerID uuid.UUID, bucketName, key, contentType string, body io.Reader) error {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if err := cloudProvider.UploadObject(ctx, bucketName, key, body, contentType); err != nil {
		s.logger.Error("Failed to upload object", zap.Error(err), zap.String("bucket", bucketName), zap.String("key", key))
		return err
	}

	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, bucketName)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "object_uploaded", map[string]interface{}{
			"bucket_name": bucketName,
			"key":         key,
		})
	}

	return nil
}

// DownloadObject downloads an object from a bucket
func (s *StorageService) DownloadObject(ctx context.Context, providerID uuid.UUID, bucketName, key string) (io.ReadCloser, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return nil, err
	}

	reader, err := cloudProvider.DownloadObject(ctx, bucketName, key)
	if err != nil {
		s.logger.Error("Failed to download object", zap.Error(err), zap.String("bucket", bucketName), zap.String("key", key))
		return nil, err
	}

	return reader, nil
}

// DeleteObject deletes an object from a bucket
func (s *StorageService) DeleteObject(ctx context.Context, userID, providerID uuid.UUID, bucketName, key string) error {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return err
	}

	if err := cloudProvider.DeleteObject(ctx, bucketName, key); err != nil {
		s.logger.Error("Failed to delete object", zap.Error(err), zap.String("bucket", bucketName), zap.String("key", key))
		return err
	}

	resource, _ := s.resourceRepo.GetByResourceID(ctx, providerID, bucketName)
	if resource != nil {
		s.logAudit(ctx, userID, &resource.ID, "object_deleted", map[string]interface{}{
			"bucket_name": bucketName,
			"key":         key,
		})
	}

	return nil
}

// GetPresignedURL gets a presigned URL for an object
func (s *StorageService) GetPresignedURL(ctx context.Context, providerID uuid.UUID, bucketName, key, operation string, expiry int64) (string, error) {
	_, cloudProvider, err := s.getCloudProvider(ctx, providerID)
	if err != nil {
		return "", err
	}

	url, err := cloudProvider.GetPresignedURL(ctx, bucketName, key, operation, expiry)
	if err != nil {
		s.logger.Error("Failed to generate presigned URL", zap.Error(err))
		return "", err
	}

	return url, nil
}

// getCloudProvider helper to get provider and cloud interface
func (s *StorageService) getCloudProvider(ctx context.Context, providerID uuid.UUID) (*models.CloudProvider, cloud.CloudProvider, error) {
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

func (s *StorageService) logAudit(ctx context.Context, userID uuid.UUID, resourceID *uuid.UUID, action string, details map[string]interface{}) {
	audit := &models.AuditLog{
		UserID:     userID,
		ResourceID: resourceID,
		Action:     action,
		Details:    details,
	}
	_ = s.auditLogRepo.Create(ctx, audit)
}

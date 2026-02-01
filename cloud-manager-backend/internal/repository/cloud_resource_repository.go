package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/vide/cloud-manager-backend/internal/models"
)

// CloudResourceRepository handles cloud resource data operations
type CloudResourceRepository struct {
	pool *pgxpool.Pool
}

// NewCloudResourceRepository creates a new CloudResourceRepository
func NewCloudResourceRepository(pool *pgxpool.Pool) *CloudResourceRepository {
	return &CloudResourceRepository{pool: pool}
}

// Create creates a new cloud resource
func (r *CloudResourceRepository) Create(ctx context.Context, resource *models.CloudResource) error {
	tagsJSON, err := json.Marshal(resource.Tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	metadataJSON, err := json.Marshal(resource.Metadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	query := `
		INSERT INTO cloud_resources (provider_id, resource_id, resource_type, name, region, zone, status, tags, metadata, cost_hourly, cost_monthly)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		ON CONFLICT (provider_id, resource_id) DO UPDATE SET
			name = EXCLUDED.name,
			status = EXCLUDED.status,
			tags = EXCLUDED.tags,
			metadata = EXCLUDED.metadata,
			cost_hourly = EXCLUDED.cost_hourly,
			cost_monthly = EXCLUDED.cost_monthly,
			updated_at = NOW()
		RETURNING id, created_at, updated_at`

	return r.pool.QueryRow(ctx, query,
		resource.ProviderID,
		resource.ResourceID,
		resource.ResourceType,
		resource.Name,
		resource.Region,
		resource.Zone,
		resource.Status,
		tagsJSON,
		metadataJSON,
		resource.CostHourly,
		resource.CostMonthly,
	).Scan(&resource.ID, &resource.CreatedAt, &resource.UpdatedAt)
}

// GetByID retrieves a cloud resource by ID
func (r *CloudResourceRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.CloudResource, error) {
	query := `
		SELECT id, provider_id, resource_id, resource_type, name, region, zone, status, tags, metadata, cost_hourly, cost_monthly, created_at, updated_at
		FROM cloud_resources WHERE id = $1`

	resource := &models.CloudResource{}
	var tagsJSON, metadataJSON []byte
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&resource.ID, &resource.ProviderID, &resource.ResourceID, &resource.ResourceType,
		&resource.Name, &resource.Region, &resource.Zone, &resource.Status,
		&tagsJSON, &metadataJSON, &resource.CostHourly, &resource.CostMonthly,
		&resource.CreatedAt, &resource.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("cloud resource not found")
		}
		return nil, err
	}

	if err := json.Unmarshal(tagsJSON, &resource.Tags); err != nil {
		resource.Tags = make(map[string]string)
	}
	if err := json.Unmarshal(metadataJSON, &resource.Metadata); err != nil {
		resource.Metadata = make(map[string]interface{})
	}

	return resource, nil
}

// GetByProviderID retrieves all resources for a provider
func (r *CloudResourceRepository) GetByProviderID(ctx context.Context, providerID uuid.UUID, resourceType string, offset, limit int) ([]*models.CloudResource, int, error) {
	countQuery := `SELECT COUNT(*) FROM cloud_resources WHERE provider_id = $1`
	args := []interface{}{providerID}
	
	if resourceType != "" {
		countQuery += ` AND resource_type = $2`
		args = append(args, resourceType)
	}

	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT id, provider_id, resource_id, resource_type, name, region, zone, status, tags, metadata, cost_hourly, cost_monthly, created_at, updated_at
		FROM cloud_resources WHERE provider_id = $1`
	
	if resourceType != "" {
		query += ` AND resource_type = $2`
		args = append(args, limit, offset)
		query += ` ORDER BY created_at DESC LIMIT $3 OFFSET $4`
	} else {
		args = append(args, limit, offset)
		query += ` ORDER BY created_at DESC LIMIT $2 OFFSET $3`
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var resources []*models.CloudResource
	for rows.Next() {
		resource := &models.CloudResource{}
		var tagsJSON, metadataJSON []byte
		if err := rows.Scan(
			&resource.ID, &resource.ProviderID, &resource.ResourceID, &resource.ResourceType,
			&resource.Name, &resource.Region, &resource.Zone, &resource.Status,
			&tagsJSON, &metadataJSON, &resource.CostHourly, &resource.CostMonthly,
			&resource.CreatedAt, &resource.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		if err := json.Unmarshal(tagsJSON, &resource.Tags); err != nil {
			resource.Tags = make(map[string]string)
		}
		if err := json.Unmarshal(metadataJSON, &resource.Metadata); err != nil {
			resource.Metadata = make(map[string]interface{})
		}
		resources = append(resources, resource)
	}

	return resources, total, nil
}

// Update updates a cloud resource
func (r *CloudResourceRepository) Update(ctx context.Context, resource *models.CloudResource) error {
	tagsJSON, err := json.Marshal(resource.Tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	metadataJSON, err := json.Marshal(resource.Metadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	query := `
		UPDATE cloud_resources 
		SET name = $2, status = $3, tags = $4, metadata = $5, cost_hourly = $6, cost_monthly = $7
		WHERE id = $1
		RETURNING updated_at`

	return r.pool.QueryRow(ctx, query,
		resource.ID, resource.Name, resource.Status,
		tagsJSON, metadataJSON, resource.CostHourly, resource.CostMonthly,
	).Scan(&resource.UpdatedAt)
}

// Delete deletes a cloud resource
func (r *CloudResourceRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM cloud_resources WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// DeleteByProviderID deletes all resources for a provider
func (r *CloudResourceRepository) DeleteByProviderID(ctx context.Context, providerID uuid.UUID) error {
	query := `DELETE FROM cloud_resources WHERE provider_id = $1`
	_, err := r.pool.Exec(ctx, query, providerID)
	return err
}

// GetResourceCounts gets resource counts by type for a provider
func (r *CloudResourceRepository) GetResourceCounts(ctx context.Context, providerID uuid.UUID) (map[string]int, error) {
	query := `
		SELECT resource_type, COUNT(*) 
		FROM cloud_resources 
		WHERE provider_id = $1 
		GROUP BY resource_type`

	rows, err := r.pool.Query(ctx, query, providerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	counts := make(map[string]int)
	for rows.Next() {
		var resourceType string
		var count int
		if err := rows.Scan(&resourceType, &count); err != nil {
			return nil, err
		}
		counts[resourceType] = count
	}

	return counts, nil
}

// GetTotalCost gets the total monthly cost for a provider
func (r *CloudResourceRepository) GetTotalCost(ctx context.Context, providerID uuid.UUID) (float64, error) {
	query := `SELECT COALESCE(SUM(cost_monthly), 0) FROM cloud_resources WHERE provider_id = $1`
	var total float64
	err := r.pool.QueryRow(ctx, query, providerID).Scan(&total)
	return total, err
}

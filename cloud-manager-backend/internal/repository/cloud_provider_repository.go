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

// CloudProviderRepository handles cloud provider data operations
type CloudProviderRepository struct {
	pool *pgxpool.Pool
}

// NewCloudProviderRepository creates a new CloudProviderRepository
func NewCloudProviderRepository(pool *pgxpool.Pool) *CloudProviderRepository {
	return &CloudProviderRepository{pool: pool}
}

// Create creates a new cloud provider
func (r *CloudProviderRepository) Create(ctx context.Context, provider *models.CloudProvider) error {
	credentialsJSON, err := json.Marshal(provider.Credentials)
	if err != nil {
		return fmt.Errorf("failed to marshal credentials: %w", err)
	}

	query := `
		INSERT INTO cloud_providers (user_id, name, provider_type, credentials, region, is_default, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at`

	return r.pool.QueryRow(ctx, query,
		provider.UserID,
		provider.Name,
		provider.ProviderType,
		credentialsJSON,
		provider.Region,
		provider.IsDefault,
		provider.Status,
	).Scan(&provider.ID, &provider.CreatedAt, &provider.UpdatedAt)
}

// GetByID retrieves a cloud provider by ID
func (r *CloudProviderRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.CloudProvider, error) {
	query := `
		SELECT id, user_id, name, provider_type, credentials, region, is_default, status,
		       last_synced_at, created_at, updated_at
		FROM cloud_providers WHERE id = $1`

	provider := &models.CloudProvider{}
	var credentialsJSON []byte
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&provider.ID, &provider.UserID, &provider.Name, &provider.ProviderType,
		&credentialsJSON, &provider.Region, &provider.IsDefault, &provider.Status,
		&provider.LastSyncedAt, &provider.CreatedAt, &provider.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("cloud provider not found")
		}
		return nil, err
	}

	if err := json.Unmarshal(credentialsJSON, &provider.Credentials); err != nil {
		return nil, fmt.Errorf("failed to unmarshal credentials: %w", err)
	}

	return provider, nil
}

// GetByUserID retrieves all cloud providers for a user
func (r *CloudProviderRepository) GetByUserID(ctx context.Context, userID uuid.UUID) ([]*models.CloudProvider, error) {
	query := `
		SELECT id, user_id, name, provider_type, credentials, region, is_default, status,
		       last_synced_at, created_at, updated_at
		FROM cloud_providers WHERE user_id = $1
		ORDER BY created_at DESC`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var providers []*models.CloudProvider
	for rows.Next() {
		provider := &models.CloudProvider{}
		var credentialsJSON []byte
		if err := rows.Scan(
			&provider.ID, &provider.UserID, &provider.Name, &provider.ProviderType,
			&credentialsJSON, &provider.Region, &provider.IsDefault, &provider.Status,
			&provider.LastSyncedAt, &provider.CreatedAt, &provider.UpdatedAt,
		); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(credentialsJSON, &provider.Credentials); err != nil {
			return nil, fmt.Errorf("failed to unmarshal credentials: %w", err)
		}
		providers = append(providers, provider)
	}

	return providers, nil
}

// Update updates a cloud provider
func (r *CloudProviderRepository) Update(ctx context.Context, provider *models.CloudProvider) error {
	credentialsJSON, err := json.Marshal(provider.Credentials)
	if err != nil {
		return fmt.Errorf("failed to marshal credentials: %w", err)
	}

	query := `
		UPDATE cloud_providers 
		SET name = $2, credentials = $3, region = $4, is_default = $5, status = $6
		WHERE id = $1
		RETURNING updated_at`

	return r.pool.QueryRow(ctx, query,
		provider.ID, provider.Name, credentialsJSON,
		provider.Region, provider.IsDefault, provider.Status,
	).Scan(&provider.UpdatedAt)
}

// Delete deletes a cloud provider
func (r *CloudProviderRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM cloud_providers WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// UpdateLastSynced updates the last synced timestamp
func (r *CloudProviderRepository) UpdateLastSynced(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE cloud_providers SET last_synced_at = NOW() WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// SetDefault sets a provider as default and unsets others
func (r *CloudProviderRepository) SetDefault(ctx context.Context, userID, providerID uuid.UUID) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Unset all defaults for user
	_, err = tx.Exec(ctx, `UPDATE cloud_providers SET is_default = false WHERE user_id = $1`, userID)
	if err != nil {
		return err
	}

	// Set new default
	_, err = tx.Exec(ctx, `UPDATE cloud_providers SET is_default = true WHERE id = $1`, providerID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

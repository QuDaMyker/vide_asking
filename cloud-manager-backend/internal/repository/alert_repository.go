package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/vide/cloud-manager-backend/internal/models"
)

// AlertRepository handles alert data operations
type AlertRepository struct {
	pool *pgxpool.Pool
}

// NewAlertRepository creates a new AlertRepository
func NewAlertRepository(pool *pgxpool.Pool) *AlertRepository {
	return &AlertRepository{pool: pool}
}

// Create creates a new alert
func (r *AlertRepository) Create(ctx context.Context, alert *models.Alert) error {
	conditionJSON, err := json.Marshal(alert.Condition)
	if err != nil {
		return fmt.Errorf("failed to marshal condition: %w", err)
	}

	channelsJSON, err := json.Marshal(alert.NotificationChannels)
	if err != nil {
		return fmt.Errorf("failed to marshal notification channels: %w", err)
	}

	query := `
		INSERT INTO alerts (user_id, resource_id, name, description, alert_type, condition, severity, status, notification_channels)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, created_at, updated_at`

	return r.pool.QueryRow(ctx, query,
		alert.UserID,
		alert.ResourceID,
		alert.Name,
		alert.Description,
		alert.AlertType,
		conditionJSON,
		alert.Severity,
		alert.Status,
		channelsJSON,
	).Scan(&alert.ID, &alert.CreatedAt, &alert.UpdatedAt)
}

// GetByID retrieves an alert by ID
func (r *AlertRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Alert, error) {
	query := `
		SELECT id, user_id, resource_id, name, description, alert_type, condition, severity, status, 
		       notification_channels, last_triggered_at, created_at, updated_at
		FROM alerts WHERE id = $1`

	alert := &models.Alert{}
	var conditionJSON, channelsJSON []byte
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&alert.ID, &alert.UserID, &alert.ResourceID, &alert.Name, &alert.Description,
		&alert.AlertType, &conditionJSON, &alert.Severity, &alert.Status,
		&channelsJSON, &alert.LastTriggeredAt, &alert.CreatedAt, &alert.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("alert not found")
		}
		return nil, err
	}

	if err := json.Unmarshal(conditionJSON, &alert.Condition); err != nil {
		return nil, fmt.Errorf("failed to unmarshal condition: %w", err)
	}
	if err := json.Unmarshal(channelsJSON, &alert.NotificationChannels); err != nil {
		alert.NotificationChannels = []string{}
	}

	return alert, nil
}

// GetByUserID retrieves all alerts for a user
func (r *AlertRepository) GetByUserID(ctx context.Context, userID uuid.UUID, status string, offset, limit int) ([]*models.Alert, int, error) {
	countQuery := `SELECT COUNT(*) FROM alerts WHERE user_id = $1`
	args := []interface{}{userID}
	
	if status != "" {
		countQuery += ` AND status = $2`
		args = append(args, status)
	}

	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT id, user_id, resource_id, name, description, alert_type, condition, severity, status,
		       notification_channels, last_triggered_at, created_at, updated_at
		FROM alerts WHERE user_id = $1`
	
	if status != "" {
		query += ` AND status = $2 ORDER BY created_at DESC LIMIT $3 OFFSET $4`
		args = append(args, limit, offset)
	} else {
		query += ` ORDER BY created_at DESC LIMIT $2 OFFSET $3`
		args = append(args, limit, offset)
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var alerts []*models.Alert
	for rows.Next() {
		alert := &models.Alert{}
		var conditionJSON, channelsJSON []byte
		if err := rows.Scan(
			&alert.ID, &alert.UserID, &alert.ResourceID, &alert.Name, &alert.Description,
			&alert.AlertType, &conditionJSON, &alert.Severity, &alert.Status,
			&channelsJSON, &alert.LastTriggeredAt, &alert.CreatedAt, &alert.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		json.Unmarshal(conditionJSON, &alert.Condition)
		json.Unmarshal(channelsJSON, &alert.NotificationChannels)
		alerts = append(alerts, alert)
	}

	return alerts, total, nil
}

// Update updates an alert
func (r *AlertRepository) Update(ctx context.Context, alert *models.Alert) error {
	conditionJSON, err := json.Marshal(alert.Condition)
	if err != nil {
		return fmt.Errorf("failed to marshal condition: %w", err)
	}

	channelsJSON, err := json.Marshal(alert.NotificationChannels)
	if err != nil {
		return fmt.Errorf("failed to marshal notification channels: %w", err)
	}

	query := `
		UPDATE alerts 
		SET name = $2, description = $3, condition = $4, severity = $5, status = $6, notification_channels = $7
		WHERE id = $1
		RETURNING updated_at`

	return r.pool.QueryRow(ctx, query,
		alert.ID, alert.Name, alert.Description, conditionJSON, alert.Severity, alert.Status, channelsJSON,
	).Scan(&alert.UpdatedAt)
}

// Delete deletes an alert
func (r *AlertRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM alerts WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// UpdateLastTriggered updates the last triggered timestamp
func (r *AlertRepository) UpdateLastTriggered(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE alerts SET last_triggered_at = $2 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id, time.Now())
	return err
}

// GetActiveAlerts retrieves all active alerts
func (r *AlertRepository) GetActiveAlerts(ctx context.Context) ([]*models.Alert, error) {
	query := `
		SELECT id, user_id, resource_id, name, description, alert_type, condition, severity, status,
		       notification_channels, last_triggered_at, created_at, updated_at
		FROM alerts WHERE status = 'active'`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var alerts []*models.Alert
	for rows.Next() {
		alert := &models.Alert{}
		var conditionJSON, channelsJSON []byte
		if err := rows.Scan(
			&alert.ID, &alert.UserID, &alert.ResourceID, &alert.Name, &alert.Description,
			&alert.AlertType, &conditionJSON, &alert.Severity, &alert.Status,
			&channelsJSON, &alert.LastTriggeredAt, &alert.CreatedAt, &alert.UpdatedAt,
		); err != nil {
			return nil, err
		}
		json.Unmarshal(conditionJSON, &alert.Condition)
		json.Unmarshal(channelsJSON, &alert.NotificationChannels)
		alerts = append(alerts, alert)
	}

	return alerts, nil
}

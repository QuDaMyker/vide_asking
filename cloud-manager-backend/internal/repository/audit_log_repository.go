package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/vide/cloud-manager-backend/internal/models"
)

// AuditLogRepository handles audit log data operations
type AuditLogRepository struct {
	pool *pgxpool.Pool
}

// NewAuditLogRepository creates a new AuditLogRepository
func NewAuditLogRepository(pool *pgxpool.Pool) *AuditLogRepository {
	return &AuditLogRepository{pool: pool}
}

// Create creates a new audit log entry
func (r *AuditLogRepository) Create(ctx context.Context, log *models.AuditLog) error {
	oldValueJSON, _ := json.Marshal(log.OldValue)
	newValueJSON, _ := json.Marshal(log.NewValue)

	query := `
		INSERT INTO audit_logs (user_id, action, resource_type, resource_id, provider_type, old_value, new_value, ip_address, user_agent, status, error_message)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, created_at`

	return r.pool.QueryRow(ctx, query,
		log.UserID,
		log.Action,
		log.ResourceType,
		log.ResourceID,
		log.ProviderType,
		oldValueJSON,
		newValueJSON,
		log.IPAddress,
		log.UserAgent,
		log.Status,
		log.ErrorMessage,
	).Scan(&log.ID, &log.CreatedAt)
}

// GetByUserID retrieves audit logs for a user
func (r *AuditLogRepository) GetByUserID(ctx context.Context, userID uuid.UUID, action string, from, to time.Time, offset, limit int) ([]*models.AuditLog, int, error) {
	baseQuery := `FROM audit_logs WHERE user_id = $1`
	args := []interface{}{userID}
	argCount := 1

	if action != "" {
		argCount++
		baseQuery += fmt.Sprintf(` AND action = $%d`, argCount)
		args = append(args, action)
	}

	if !from.IsZero() {
		argCount++
		baseQuery += fmt.Sprintf(` AND created_at >= $%d`, argCount)
		args = append(args, from)
	}

	if !to.IsZero() {
		argCount++
		baseQuery += fmt.Sprintf(` AND created_at <= $%d`, argCount)
		args = append(args, to)
	}

	countQuery := `SELECT COUNT(*) ` + baseQuery
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `SELECT id, user_id, action, resource_type, resource_id, provider_type, old_value, new_value, ip_address, user_agent, status, error_message, created_at ` + baseQuery
	query += fmt.Sprintf(` ORDER BY created_at DESC LIMIT $%d OFFSET $%d`, argCount+1, argCount+2)
	args = append(args, limit, offset)

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var logs []*models.AuditLog
	for rows.Next() {
		log := &models.AuditLog{}
		var oldValueJSON, newValueJSON []byte
		if err := rows.Scan(
			&log.ID, &log.UserID, &log.Action, &log.ResourceType, &log.ResourceID,
			&log.ProviderType, &oldValueJSON, &newValueJSON, &log.IPAddress,
			&log.UserAgent, &log.Status, &log.ErrorMessage, &log.CreatedAt,
		); err != nil {
			return nil, 0, err
		}
		json.Unmarshal(oldValueJSON, &log.OldValue)
		json.Unmarshal(newValueJSON, &log.NewValue)
		logs = append(logs, log)
	}

	return logs, total, nil
}

// GetRecent retrieves recent audit logs
func (r *AuditLogRepository) GetRecent(ctx context.Context, limit int) ([]*models.AuditLog, error) {
	query := `
		SELECT id, user_id, action, resource_type, resource_id, provider_type, old_value, new_value, ip_address, user_agent, status, error_message, created_at
		FROM audit_logs
		ORDER BY created_at DESC
		LIMIT $1`

	rows, err := r.pool.Query(ctx, query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []*models.AuditLog
	for rows.Next() {
		log := &models.AuditLog{}
		var oldValueJSON, newValueJSON []byte
		if err := rows.Scan(
			&log.ID, &log.UserID, &log.Action, &log.ResourceType, &log.ResourceID,
			&log.ProviderType, &oldValueJSON, &newValueJSON, &log.IPAddress,
			&log.UserAgent, &log.Status, &log.ErrorMessage, &log.CreatedAt,
		); err != nil {
			return nil, err
		}
		json.Unmarshal(oldValueJSON, &log.OldValue)
		json.Unmarshal(newValueJSON, &log.NewValue)
		logs = append(logs, log)
	}

	return logs, nil
}

// DeleteOlderThan deletes audit logs older than the specified duration
func (r *AuditLogRepository) DeleteOlderThan(ctx context.Context, days int) (int64, error) {
	query := `DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '1 day' * $1`
	result, err := r.pool.Exec(ctx, query, days)
	if err != nil {
		return 0, err
	}
	return result.RowsAffected(), nil
}

package service

import (
	"context"

	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/models"
	"github.com/vide/cloud-manager-backend/internal/notification"
	"github.com/vide/cloud-manager-backend/internal/repository"
	"go.uber.org/zap"
)

// AlertService handles alert business logic
type AlertService struct {
	alertRepo           *repository.AlertRepository
	auditLogRepo        *repository.AuditLogRepository
	notificationManager *notification.NotificationManager
	logger              *zap.Logger
}

// NewAlertService creates a new AlertService
func NewAlertService(
	alertRepo *repository.AlertRepository,
	auditLogRepo *repository.AuditLogRepository,
	notificationManager *notification.NotificationManager,
	logger *zap.Logger,
) *AlertService {
	return &AlertService{
		alertRepo:           alertRepo,
		auditLogRepo:        auditLogRepo,
		notificationManager: notificationManager,
		logger:              logger,
	}
}

// AlertHistory represents alert trigger history
type AlertHistory struct {
	ID        uuid.UUID              `json:"id"`
	AlertID   uuid.UUID              `json:"alert_id"`
	Status    string                 `json:"status"`
	Details   map[string]interface{} `json:"details"`
	CreatedAt string                 `json:"created_at"`
}

// ListAlerts returns alerts for a user
func (s *AlertService) ListAlerts(ctx context.Context, userID uuid.UUID, status string, offset, limit int) ([]*models.Alert, int, error) {
	alerts, err := s.alertRepo.ListByUserID(ctx, userID, offset, limit)
	if err != nil {
		return nil, 0, err
	}

	// Filter by status if provided
	if status != "" {
		filtered := make([]*models.Alert, 0)
		for _, alert := range alerts {
			if alert.Status == status {
				filtered = append(filtered, alert)
			}
		}
		alerts = filtered
	}

	total, err := s.alertRepo.CountByUserID(ctx, userID)
	if err != nil {
		return nil, 0, err
	}

	return alerts, total, nil
}

// GetAlert returns an alert by ID
func (s *AlertService) GetAlert(ctx context.Context, alertID uuid.UUID) (*models.Alert, error) {
	return s.alertRepo.GetByID(ctx, alertID)
}

// CreateAlert creates a new alert
func (s *AlertService) CreateAlert(ctx context.Context, alert *models.Alert) error {
	if err := s.alertRepo.Create(ctx, alert); err != nil {
		return err
	}

	s.logAudit(ctx, alert.UserID, nil, "alert_created", map[string]interface{}{
		"alert_id":   alert.ID,
		"alert_name": alert.Name,
		"alert_type": alert.AlertType,
	})

	return nil
}

// UpdateAlert updates an alert
func (s *AlertService) UpdateAlert(ctx context.Context, alert *models.Alert) error {
	existing, err := s.alertRepo.GetByID(ctx, alert.ID)
	if err != nil {
		return err
	}

	// Update only allowed fields
	existing.Name = alert.Name
	existing.Description = alert.Description
	existing.Condition = alert.Condition
	existing.Severity = alert.Severity
	existing.NotificationChannels = alert.NotificationChannels

	if err := s.alertRepo.Update(ctx, existing); err != nil {
		return err
	}

	s.logAudit(ctx, existing.UserID, nil, "alert_updated", map[string]interface{}{
		"alert_id": alert.ID,
	})

	return nil
}

// DeleteAlert deletes an alert
func (s *AlertService) DeleteAlert(ctx context.Context, alertID uuid.UUID) error {
	alert, err := s.alertRepo.GetByID(ctx, alertID)
	if err != nil {
		return err
	}

	if err := s.alertRepo.Delete(ctx, alertID); err != nil {
		return err
	}

	s.logAudit(ctx, alert.UserID, nil, "alert_deleted", map[string]interface{}{
		"alert_id": alertID,
	})

	return nil
}

// EnableAlert enables an alert
func (s *AlertService) EnableAlert(ctx context.Context, alertID uuid.UUID) error {
	alert, err := s.alertRepo.GetByID(ctx, alertID)
	if err != nil {
		return err
	}

	alert.Status = "active"
	if err := s.alertRepo.Update(ctx, alert); err != nil {
		return err
	}

	s.logAudit(ctx, alert.UserID, nil, "alert_enabled", map[string]interface{}{
		"alert_id": alertID,
	})

	return nil
}

// DisableAlert disables an alert
func (s *AlertService) DisableAlert(ctx context.Context, alertID uuid.UUID) error {
	alert, err := s.alertRepo.GetByID(ctx, alertID)
	if err != nil {
		return err
	}

	alert.Status = "disabled"
	if err := s.alertRepo.Update(ctx, alert); err != nil {
		return err
	}

	s.logAudit(ctx, alert.UserID, nil, "alert_disabled", map[string]interface{}{
		"alert_id": alertID,
	})

	return nil
}

// GetAlertHistory returns alert trigger history
func (s *AlertService) GetAlertHistory(ctx context.Context, alertID uuid.UUID, offset, limit int) ([]*AlertHistory, int, error) {
	// In a real implementation, this would query alert_history table
	// For now, return empty list
	return []*AlertHistory{}, 0, nil
}

// TestAlert sends a test notification for an alert
func (s *AlertService) TestAlert(ctx context.Context, alertID uuid.UUID) error {
	alert, err := s.alertRepo.GetByID(ctx, alertID)
	if err != nil {
		return err
	}

	// Send test notification
	msg := &notification.Message{
		Subject: "Test Alert: " + alert.Name,
		Body:    "This is a test notification for your alert configuration.",
		HTMLBody: `<h2>Test Alert</h2>
<p>This is a test notification for your alert: <strong>` + alert.Name + `</strong></p>
<p>Alert Type: ` + string(alert.AlertType) + `</p>
<p>Severity: ` + string(alert.Severity) + `</p>
<p>If you received this notification, your alert is configured correctly.</p>`,
		Severity: string(alert.Severity),
	}

	// Send to configured channels
	for _, channel := range alert.NotificationChannels {
		switch channel {
		case "email":
			_ = s.notificationManager.SendEmail(ctx, msg)
		case "slack":
			_ = s.notificationManager.SendSlack(ctx, msg)
		case "telegram":
			_ = s.notificationManager.SendTelegram(ctx, msg)
		}
	}

	s.logger.Info("Test alert sent", zap.String("alert_id", alertID.String()))
	return nil
}

// TriggerAlert triggers an alert (called by monitoring system)
func (s *AlertService) TriggerAlert(ctx context.Context, alertID uuid.UUID, details map[string]interface{}) error {
	alert, err := s.alertRepo.GetByID(ctx, alertID)
	if err != nil {
		return err
	}

	if alert.Status != "active" {
		return nil
	}

	// Build notification message
	msg := &notification.Message{
		Subject:  "Alert Triggered: " + alert.Name,
		Body:     alert.Description,
		Severity: string(alert.Severity),
		Metadata: details,
	}

	// Send to all configured channels
	for _, channel := range alert.NotificationChannels {
		switch channel {
		case "email":
			_ = s.notificationManager.SendEmail(ctx, msg)
		case "slack":
			_ = s.notificationManager.SendSlack(ctx, msg)
		case "telegram":
			_ = s.notificationManager.SendTelegram(ctx, msg)
		}
	}

	// Update last triggered
	_ = s.alertRepo.UpdateLastTriggered(ctx, alertID)

	s.logger.Info("Alert triggered", 
		zap.String("alert_id", alertID.String()),
		zap.String("severity", string(alert.Severity)),
	)

	return nil
}

func (s *AlertService) logAudit(ctx context.Context, userID uuid.UUID, resourceID *uuid.UUID, action string, details map[string]interface{}) {
	audit := &models.AuditLog{
		UserID:     userID,
		ResourceID: resourceID,
		Action:     action,
		Details:    details,
	}
	_ = s.auditLogRepo.Create(ctx, audit)
}

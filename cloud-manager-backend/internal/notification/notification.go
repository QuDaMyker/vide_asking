package notification

import (
	"context"
	"fmt"

	"github.com/vide/cloud-manager-backend/internal/config"
	"go.uber.org/fx"
	"go.uber.org/zap"
)

// Module provides notification dependencies
var Module = fx.Options(
	fx.Provide(NewNotificationManager),
	fx.Provide(NewEmailNotifier),
	fx.Provide(NewTelegramNotifier),
	fx.Provide(NewSlackNotifier),
)

// Notifier defines the interface for sending notifications
type Notifier interface {
	Send(ctx context.Context, message *Message) error
	IsEnabled() bool
	GetChannel() string
}

// Message represents a notification message
type Message struct {
	Subject  string            `json:"subject"`
	Body     string            `json:"body"`
	Type     MessageType       `json:"type"`
	Priority Priority          `json:"priority"`
	Data     map[string]string `json:"data,omitempty"`
}

// MessageType represents the type of notification message
type MessageType string

const (
	MessageTypeAlert   MessageType = "alert"
	MessageTypeInfo    MessageType = "info"
	MessageTypeWarning MessageType = "warning"
	MessageTypeError   MessageType = "error"
	MessageTypeSuccess MessageType = "success"
)

// Priority represents notification priority
type Priority string

const (
	PriorityLow      Priority = "low"
	PriorityMedium   Priority = "medium"
	PriorityHigh     Priority = "high"
	PriorityCritical Priority = "critical"
)

// NotificationManager manages multiple notification channels
type NotificationManager struct {
	notifiers map[string]Notifier
	logger    *zap.Logger
}

// NewNotificationManager creates a new NotificationManager
func NewNotificationManager(
	email *EmailNotifier,
	telegram *TelegramNotifier,
	slack *SlackNotifier,
	logger *zap.Logger,
) *NotificationManager {
	notifiers := make(map[string]Notifier)

	if email.IsEnabled() {
		notifiers["email"] = email
	}
	if telegram.IsEnabled() {
		notifiers["telegram"] = telegram
	}
	if slack.IsEnabled() {
		notifiers["slack"] = slack
	}

	return &NotificationManager{
		notifiers: notifiers,
		logger:    logger,
	}
}

// Send sends a notification to specified channels
func (m *NotificationManager) Send(ctx context.Context, channels []string, message *Message) error {
	var errors []error

	for _, channel := range channels {
		notifier, ok := m.notifiers[channel]
		if !ok {
			m.logger.Warn("Unknown notification channel", zap.String("channel", channel))
			continue
		}

		if err := notifier.Send(ctx, message); err != nil {
			m.logger.Error("Failed to send notification",
				zap.String("channel", channel),
				zap.Error(err),
			)
			errors = append(errors, err)
		} else {
			m.logger.Info("Notification sent successfully",
				zap.String("channel", channel),
				zap.String("subject", message.Subject),
			)
		}
	}

	if len(errors) > 0 {
		return fmt.Errorf("failed to send %d notifications", len(errors))
	}

	return nil
}

// SendAll sends a notification to all enabled channels
func (m *NotificationManager) SendAll(ctx context.Context, message *Message) error {
	var channels []string
	for channel := range m.notifiers {
		channels = append(channels, channel)
	}
	return m.Send(ctx, channels, message)
}

// GetEnabledChannels returns a list of enabled notification channels
func (m *NotificationManager) GetEnabledChannels() []string {
	var channels []string
	for channel := range m.notifiers {
		channels = append(channels, channel)
	}
	return channels
}

// AlertTemplates provides pre-formatted messages for common alerts
type AlertTemplates struct{}

// NewAlertTemplates creates a new AlertTemplates
func NewAlertTemplates() *AlertTemplates {
	return &AlertTemplates{}
}

// ResourceDown creates a message for a resource down alert
func (t *AlertTemplates) ResourceDown(resourceName, resourceType, provider string) *Message {
	return &Message{
		Subject:  fmt.Sprintf("🔴 ALERT: %s is DOWN", resourceName),
		Body:     fmt.Sprintf("Resource %s (%s) on %s is not responding.\n\nPlease investigate immediately.", resourceName, resourceType, provider),
		Type:     MessageTypeAlert,
		Priority: PriorityCritical,
		Data: map[string]string{
			"resource_name": resourceName,
			"resource_type": resourceType,
			"provider":      provider,
		},
	}
}

// ResourceRecovered creates a message for a resource recovery alert
func (t *AlertTemplates) ResourceRecovered(resourceName, resourceType, provider string) *Message {
	return &Message{
		Subject:  fmt.Sprintf("✅ RESOLVED: %s is back UP", resourceName),
		Body:     fmt.Sprintf("Resource %s (%s) on %s has recovered.", resourceName, resourceType, provider),
		Type:     MessageTypeSuccess,
		Priority: PriorityMedium,
		Data: map[string]string{
			"resource_name": resourceName,
			"resource_type": resourceType,
			"provider":      provider,
		},
	}
}

// HighCPUUsage creates a message for high CPU usage alert
func (t *AlertTemplates) HighCPUUsage(resourceName string, cpuPercent float64, threshold float64) *Message {
	return &Message{
		Subject: fmt.Sprintf("⚠️ High CPU Usage: %s at %.1f%%", resourceName, cpuPercent),
		Body: fmt.Sprintf(
			"Resource %s has high CPU usage.\n\nCurrent: %.1f%%\nThreshold: %.1f%%\n\nConsider scaling or optimizing workloads.",
			resourceName, cpuPercent, threshold,
		),
		Type:     MessageTypeWarning,
		Priority: PriorityHigh,
		Data: map[string]string{
			"resource_name": resourceName,
			"cpu_percent":   fmt.Sprintf("%.1f", cpuPercent),
			"threshold":     fmt.Sprintf("%.1f", threshold),
		},
	}
}

// HighMemoryUsage creates a message for high memory usage alert
func (t *AlertTemplates) HighMemoryUsage(resourceName string, memoryPercent float64, threshold float64) *Message {
	return &Message{
		Subject: fmt.Sprintf("⚠️ High Memory Usage: %s at %.1f%%", resourceName, memoryPercent),
		Body: fmt.Sprintf(
			"Resource %s has high memory usage.\n\nCurrent: %.1f%%\nThreshold: %.1f%%\n\nConsider adding more memory or optimizing memory usage.",
			resourceName, memoryPercent, threshold,
		),
		Type:     MessageTypeWarning,
		Priority: PriorityHigh,
		Data: map[string]string{
			"resource_name":  resourceName,
			"memory_percent": fmt.Sprintf("%.1f", memoryPercent),
			"threshold":      fmt.Sprintf("%.1f", threshold),
		},
	}
}

// BillingAlert creates a message for billing alerts
func (t *AlertTemplates) BillingAlert(provider string, currentCost, threshold float64, currency string) *Message {
	return &Message{
		Subject: fmt.Sprintf("💰 Billing Alert: %s costs exceeding threshold", provider),
		Body: fmt.Sprintf(
			"Your %s billing has exceeded the threshold.\n\nCurrent Cost: %s%.2f\nThreshold: %s%.2f\n\nReview your resources and optimize costs.",
			provider, currency, currentCost, currency, threshold,
		),
		Type:     MessageTypeWarning,
		Priority: PriorityHigh,
		Data: map[string]string{
			"provider":     provider,
			"current_cost": fmt.Sprintf("%.2f", currentCost),
			"threshold":    fmt.Sprintf("%.2f", threshold),
			"currency":     currency,
		},
	}
}

// DailyReport creates a message for daily summary reports
func (t *AlertTemplates) DailyReport(summary string) *Message {
	return &Message{
		Subject:  "📊 Daily Cloud Infrastructure Report",
		Body:     summary,
		Type:     MessageTypeInfo,
		Priority: PriorityLow,
	}
}

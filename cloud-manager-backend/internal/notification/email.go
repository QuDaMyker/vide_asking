package notification

import (
	"context"
	"fmt"

	"github.com/vide/cloud-manager-backend/internal/config"
	"github.com/wneessen/go-mail"
	"go.uber.org/zap"
)

// EmailNotifier sends notifications via email
type EmailNotifier struct {
	config  config.EmailConfig
	client  *mail.Client
	logger  *zap.Logger
	enabled bool
}

// NewEmailNotifier creates a new EmailNotifier
func NewEmailNotifier(cfg *config.Config, logger *zap.Logger) *EmailNotifier {
	notifier := &EmailNotifier{
		config:  cfg.Email,
		logger:  logger,
		enabled: cfg.Email.Enabled,
	}

	if !cfg.Email.Enabled {
		logger.Info("Email notifications disabled")
		return notifier
	}

	// Create mail client
	opts := []mail.Option{
		mail.WithPort(cfg.Email.SMTPPort),
		mail.WithSMTPAuth(mail.SMTPAuthPlain),
		mail.WithUsername(cfg.Email.Username),
		mail.WithPassword(cfg.Email.Password),
	}

	if cfg.Email.UseTLS {
		opts = append(opts, mail.WithTLSPortPolicy(mail.TLSMandatory))
	}

	client, err := mail.NewClient(cfg.Email.SMTPHost, opts...)
	if err != nil {
		logger.Error("Failed to create email client", zap.Error(err))
		notifier.enabled = false
		return notifier
	}

	notifier.client = client
	logger.Info("Email notifications enabled",
		zap.String("host", cfg.Email.SMTPHost),
		zap.Int("port", cfg.Email.SMTPPort),
	)

	return notifier
}

// Send sends an email notification
func (n *EmailNotifier) Send(ctx context.Context, message *Message) error {
	if !n.enabled {
		return fmt.Errorf("email notifications are disabled")
	}

	msg := mail.NewMsg()
	if err := msg.From(n.config.FromEmail); err != nil {
		return fmt.Errorf("failed to set from address: %w", err)
	}

	// Get recipients from message data or use default
	recipients := []string{}
	if to, ok := message.Data["to"]; ok {
		recipients = append(recipients, to)
	}

	if len(recipients) == 0 {
		return fmt.Errorf("no recipients specified")
	}

	if err := msg.To(recipients...); err != nil {
		return fmt.Errorf("failed to set recipients: %w", err)
	}

	msg.Subject(message.Subject)
	msg.SetBodyString(mail.TypeTextPlain, message.Body)

	// Add HTML version
	htmlBody := n.formatHTMLBody(message)
	msg.AddAlternativeString(mail.TypeTextHTML, htmlBody)

	// Set priority header
	switch message.Priority {
	case PriorityCritical, PriorityHigh:
		msg.SetImportance(mail.ImportanceHigh)
	case PriorityLow:
		msg.SetImportance(mail.ImportanceLow)
	}

	if err := n.client.DialAndSend(msg); err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	n.logger.Info("Email sent successfully",
		zap.String("subject", message.Subject),
		zap.Strings("to", recipients),
	)

	return nil
}

// formatHTMLBody formats the message as HTML
func (n *EmailNotifier) formatHTMLBody(message *Message) string {
	priorityColor := "#333333"
	switch message.Priority {
	case PriorityCritical:
		priorityColor = "#dc3545"
	case PriorityHigh:
		priorityColor = "#fd7e14"
	case PriorityMedium:
		priorityColor = "#ffc107"
	case PriorityLow:
		priorityColor = "#28a745"
	}

	typeIcon := "ℹ️"
	switch message.Type {
	case MessageTypeAlert:
		typeIcon = "🚨"
	case MessageTypeWarning:
		typeIcon = "⚠️"
	case MessageTypeError:
		typeIcon = "❌"
	case MessageTypeSuccess:
		typeIcon = "✅"
	}

	return fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: %s; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        .priority-badge { 
            display: inline-block; 
            padding: 4px 8px; 
            border-radius: 4px; 
            background-color: %s; 
            color: white; 
            font-size: 12px;
            text-transform: uppercase;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>%s Cloud Manager Alert</h1>
        </div>
        <div class="content">
            <span class="priority-badge">%s Priority</span>
            <h2>%s</h2>
            <p>%s</p>
        </div>
        <div class="footer">
            <p>This is an automated message from Cloud Manager.</p>
            <p>Do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
`, priorityColor, priorityColor, typeIcon, message.Priority, message.Subject, message.Body)
}

// IsEnabled returns whether email notifications are enabled
func (n *EmailNotifier) IsEnabled() bool {
	return n.enabled
}

// GetChannel returns the channel name
func (n *EmailNotifier) GetChannel() string {
	return "email"
}

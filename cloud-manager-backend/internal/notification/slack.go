package notification

import (
	"context"
	"fmt"

	"github.com/slack-go/slack"
	"github.com/vide/cloud-manager-backend/internal/config"
	"go.uber.org/zap"
)

// SlackNotifier sends notifications via Slack
type SlackNotifier struct {
	config  config.SlackConfig
	client  *slack.Client
	logger  *zap.Logger
	enabled bool
}

// NewSlackNotifier creates a new SlackNotifier
func NewSlackNotifier(cfg *config.Config, logger *zap.Logger) *SlackNotifier {
	notifier := &SlackNotifier{
		config:  cfg.Slack,
		logger:  logger,
		enabled: cfg.Slack.Enabled,
	}

	if !cfg.Slack.Enabled {
		logger.Info("Slack notifications disabled")
		return notifier
	}

	notifier.client = slack.New(cfg.Slack.Token)
	logger.Info("Slack notifications enabled",
		zap.String("channel_id", cfg.Slack.ChannelID),
	)

	return notifier
}

// Send sends a Slack notification
func (n *SlackNotifier) Send(ctx context.Context, message *Message) error {
	if !n.enabled {
		return fmt.Errorf("slack notifications are disabled")
	}

	// Get channel from message data or use default
	channelID := n.config.ChannelID
	if channel, ok := message.Data["channel"]; ok && channel != "" {
		channelID = channel
	}

	// Build the message blocks
	blocks := n.buildMessageBlocks(message)

	// Send the message
	_, _, err := n.client.PostMessageContext(
		ctx,
		channelID,
		slack.MsgOptionBlocks(blocks...),
		slack.MsgOptionText(message.Subject, false),
	)
	if err != nil {
		return fmt.Errorf("failed to send Slack message: %w", err)
	}

	n.logger.Info("Slack message sent successfully",
		zap.String("channel_id", channelID),
		zap.String("subject", message.Subject),
	)

	return nil
}

// buildMessageBlocks builds Slack message blocks
func (n *SlackNotifier) buildMessageBlocks(message *Message) []slack.Block {
	// Determine color based on priority/type
	color := "#0066ff" // Default blue
	switch message.Type {
	case MessageTypeAlert:
		color = "#ff0000"
	case MessageTypeWarning:
		color = "#ff9900"
	case MessageTypeError:
		color = "#cc0000"
	case MessageTypeSuccess:
		color = "#00cc00"
	}

	// Type emoji
	typeEmoji := ":information_source:"
	switch message.Type {
	case MessageTypeAlert:
		typeEmoji = ":rotating_light:"
	case MessageTypeWarning:
		typeEmoji = ":warning:"
	case MessageTypeError:
		typeEmoji = ":x:"
	case MessageTypeSuccess:
		typeEmoji = ":white_check_mark:"
	}

	// Priority text
	priorityText := fmt.Sprintf("*Priority:* %s", string(message.Priority))

	blocks := []slack.Block{
		// Header
		slack.NewHeaderBlock(
			slack.NewTextBlockObject("plain_text", fmt.Sprintf("%s %s", typeEmoji, message.Subject), true, false),
		),

		// Divider
		slack.NewDividerBlock(),

		// Body section
		slack.NewSectionBlock(
			slack.NewTextBlockObject("mrkdwn", message.Body, false, false),
			nil,
			nil,
		),

		// Priority
		slack.NewContextBlock(
			"priority_context",
			slack.NewTextBlockObject("mrkdwn", priorityText, false, false),
		),
	}

	// Add metadata fields if present
	if len(message.Data) > 0 {
		var fields []*slack.TextBlockObject
		for key, value := range message.Data {
			if key != "channel" && key != "to" && key != "chat_id" {
				fields = append(fields, slack.NewTextBlockObject(
					"mrkdwn",
					fmt.Sprintf("*%s:*\n%s", key, value),
					false,
					false,
				))
			}
		}

		if len(fields) > 0 {
			blocks = append(blocks,
				slack.NewDividerBlock(),
				slack.NewSectionBlock(
					slack.NewTextBlockObject("mrkdwn", "*Details:*", false, false),
					fields,
					nil,
				),
			)
		}
	}

	// Footer with timestamp
	blocks = append(blocks,
		slack.NewContextBlock(
			"footer_context",
			slack.NewTextBlockObject("mrkdwn", ":cloud: Cloud Manager", false, false),
		),
	)

	return blocks
}

// IsEnabled returns whether Slack notifications are enabled
func (n *SlackNotifier) IsEnabled() bool {
	return n.enabled
}

// GetChannel returns the channel name
func (n *SlackNotifier) GetChannel() string {
	return "slack"
}

// SendWithWebhook sends a notification using webhook URL
func (n *SlackNotifier) SendWithWebhook(ctx context.Context, message *Message) error {
	if n.config.WebhookURL == "" {
		return fmt.Errorf("slack webhook URL not configured")
	}

	// Determine color based on priority/type
	color := "#0066ff"
	switch message.Type {
	case MessageTypeAlert:
		color = "#ff0000"
	case MessageTypeWarning:
		color = "#ff9900"
	case MessageTypeError:
		color = "#cc0000"
	case MessageTypeSuccess:
		color = "#00cc00"
	}

	// Build attachment
	attachment := slack.Attachment{
		Color:      color,
		Title:      message.Subject,
		Text:       message.Body,
		Footer:     "Cloud Manager",
		FooterIcon: "https://example.com/cloud-icon.png",
	}

	// Add fields for metadata
	for key, value := range message.Data {
		if key != "channel" && key != "to" && key != "chat_id" {
			attachment.Fields = append(attachment.Fields, slack.AttachmentField{
				Title: key,
				Value: value,
				Short: true,
			})
		}
	}

	webhookMsg := slack.WebhookMessage{
		Attachments: []slack.Attachment{attachment},
	}

	err := slack.PostWebhookContext(ctx, n.config.WebhookURL, &webhookMsg)
	if err != nil {
		return fmt.Errorf("failed to send Slack webhook: %w", err)
	}

	n.logger.Info("Slack webhook sent successfully",
		zap.String("subject", message.Subject),
	)

	return nil
}

// SendDM sends a direct message to a user
func (n *SlackNotifier) SendDM(ctx context.Context, userID string, message *Message) error {
	if !n.enabled {
		return fmt.Errorf("slack notifications are disabled")
	}

	// Open conversation with user
	channel, _, _, err := n.client.OpenConversationContext(ctx, &slack.OpenConversationParameters{
		Users: []string{userID},
	})
	if err != nil {
		return fmt.Errorf("failed to open DM channel: %w", err)
	}

	// Build and send message
	blocks := n.buildMessageBlocks(message)
	_, _, err = n.client.PostMessageContext(
		ctx,
		channel.ID,
		slack.MsgOptionBlocks(blocks...),
		slack.MsgOptionText(message.Subject, false),
	)
	if err != nil {
		return fmt.Errorf("failed to send Slack DM: %w", err)
	}

	return nil
}

// UpdateMessage updates an existing Slack message
func (n *SlackNotifier) UpdateMessage(ctx context.Context, channelID, timestamp string, message *Message) error {
	if !n.enabled {
		return fmt.Errorf("slack notifications are disabled")
	}

	blocks := n.buildMessageBlocks(message)
	_, _, _, err := n.client.UpdateMessageContext(
		ctx,
		channelID,
		timestamp,
		slack.MsgOptionBlocks(blocks...),
		slack.MsgOptionText(message.Subject, false),
	)
	if err != nil {
		return fmt.Errorf("failed to update Slack message: %w", err)
	}

	return nil
}

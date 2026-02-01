package notification

import (
	"context"
	"fmt"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
	"github.com/vide/cloud-manager-backend/internal/config"
	"go.uber.org/zap"
)

// TelegramNotifier sends notifications via Telegram
type TelegramNotifier struct {
	config  config.TelegramConfig
	bot     *tgbotapi.BotAPI
	logger  *zap.Logger
	enabled bool
}

// NewTelegramNotifier creates a new TelegramNotifier
func NewTelegramNotifier(cfg *config.Config, logger *zap.Logger) *TelegramNotifier {
	notifier := &TelegramNotifier{
		config:  cfg.Telegram,
		logger:  logger,
		enabled: cfg.Telegram.Enabled,
	}

	if !cfg.Telegram.Enabled {
		logger.Info("Telegram notifications disabled")
		return notifier
	}

	bot, err := tgbotapi.NewBotAPI(cfg.Telegram.Token)
	if err != nil {
		logger.Error("Failed to create Telegram bot", zap.Error(err))
		notifier.enabled = false
		return notifier
	}

	notifier.bot = bot
	logger.Info("Telegram notifications enabled",
		zap.String("bot_username", bot.Self.UserName),
		zap.Int64("chat_id", cfg.Telegram.ChatID),
	)

	return notifier
}

// Send sends a Telegram notification
func (n *TelegramNotifier) Send(ctx context.Context, message *Message) error {
	if !n.enabled {
		return fmt.Errorf("telegram notifications are disabled")
	}

	// Get chat ID from message data or use default
	chatID := n.config.ChatID
	if chatIDStr, ok := message.Data["chat_id"]; ok {
		var parsedChatID int64
		fmt.Sscanf(chatIDStr, "%d", &parsedChatID)
		if parsedChatID != 0 {
			chatID = parsedChatID
		}
	}

	// Format the message
	text := n.formatMessage(message)

	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "HTML"

	// Disable notification for low priority
	if message.Priority == PriorityLow {
		msg.DisableNotification = true
	}

	_, err := n.bot.Send(msg)
	if err != nil {
		return fmt.Errorf("failed to send Telegram message: %w", err)
	}

	n.logger.Info("Telegram message sent successfully",
		zap.Int64("chat_id", chatID),
		zap.String("subject", message.Subject),
	)

	return nil
}

// formatMessage formats the notification message for Telegram
func (n *TelegramNotifier) formatMessage(message *Message) string {
	// Priority emoji
	priorityEmoji := "🔵"
	switch message.Priority {
	case PriorityCritical:
		priorityEmoji = "🔴"
	case PriorityHigh:
		priorityEmoji = "🟠"
	case PriorityMedium:
		priorityEmoji = "🟡"
	case PriorityLow:
		priorityEmoji = "🟢"
	}

	// Type emoji
	typeEmoji := "ℹ️"
	switch message.Type {
	case MessageTypeAlert:
		typeEmoji = "🚨"
	case MessageTypeWarning:
		typeEmoji = "⚠️"
	case MessageTypeError:
		typeEmoji = "❌"
	case MessageTypeSuccess:
		typeEmoji = "✅"
	}

	text := fmt.Sprintf(
		"%s <b>%s</b>\n\n%s %s\n\n%s",
		typeEmoji,
		escapeHTML(message.Subject),
		priorityEmoji,
		string(message.Priority),
		escapeHTML(message.Body),
	)

	// Add metadata if present
	if len(message.Data) > 0 {
		text += "\n\n<b>Details:</b>"
		for key, value := range message.Data {
			if key != "chat_id" && key != "to" {
				text += fmt.Sprintf("\n• <code>%s</code>: %s", key, escapeHTML(value))
			}
		}
	}

	return text
}

// escapeHTML escapes HTML special characters
func escapeHTML(s string) string {
	replacer := map[string]string{
		"&":  "&amp;",
		"<":  "&lt;",
		">":  "&gt;",
		"\"": "&quot;",
	}
	
	result := s
	for old, new := range replacer {
		result = replaceAll(result, old, new)
	}
	return result
}

func replaceAll(s, old, new string) string {
	result := ""
	for i := 0; i < len(s); i++ {
		if i+len(old) <= len(s) && s[i:i+len(old)] == old {
			result += new
			i += len(old) - 1
		} else {
			result += string(s[i])
		}
	}
	return result
}

// IsEnabled returns whether Telegram notifications are enabled
func (n *TelegramNotifier) IsEnabled() bool {
	return n.enabled
}

// GetChannel returns the channel name
func (n *TelegramNotifier) GetChannel() string {
	return "telegram"
}

// SendWithKeyboard sends a message with inline keyboard
func (n *TelegramNotifier) SendWithKeyboard(ctx context.Context, message *Message, buttons [][]tgbotapi.InlineKeyboardButton) error {
	if !n.enabled {
		return fmt.Errorf("telegram notifications are disabled")
	}

	chatID := n.config.ChatID
	text := n.formatMessage(message)

	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "HTML"
	msg.ReplyMarkup = tgbotapi.NewInlineKeyboardMarkup(buttons...)

	_, err := n.bot.Send(msg)
	if err != nil {
		return fmt.Errorf("failed to send Telegram message with keyboard: %w", err)
	}

	return nil
}

// SendPhoto sends a photo with caption
func (n *TelegramNotifier) SendPhoto(ctx context.Context, chatID int64, photoURL, caption string) error {
	if !n.enabled {
		return fmt.Errorf("telegram notifications are disabled")
	}

	if chatID == 0 {
		chatID = n.config.ChatID
	}

	photo := tgbotapi.NewPhoto(chatID, tgbotapi.FileURL(photoURL))
	photo.Caption = caption
	photo.ParseMode = "HTML"

	_, err := n.bot.Send(photo)
	if err != nil {
		return fmt.Errorf("failed to send Telegram photo: %w", err)
	}

	return nil
}

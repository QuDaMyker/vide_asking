package app

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/vide/cloud-manager-backend/internal/cloud"
	"github.com/vide/cloud-manager-backend/internal/config"
	"github.com/vide/cloud-manager-backend/internal/database"
	"github.com/vide/cloud-manager-backend/internal/handlers"
	"github.com/vide/cloud-manager-backend/internal/middleware"
	"github.com/vide/cloud-manager-backend/internal/notification"
	"github.com/vide/cloud-manager-backend/internal/repository"
	"github.com/vide/cloud-manager-backend/internal/routes"
	"github.com/vide/cloud-manager-backend/internal/service"
	"go.uber.org/fx"
	"go.uber.org/zap"
)

// Module provides all application dependencies
var Module = fx.Options(
	// Core
	fx.Provide(NewLogger),
	fx.Provide(config.Load),

	// Database
	fx.Provide(ProvideDatabase),

	// Repositories
	fx.Provide(repository.NewUserRepository),
	fx.Provide(repository.NewCloudProviderRepository),
	fx.Provide(repository.NewCloudResourceRepository),
	fx.Provide(repository.NewAlertRepository),
	fx.Provide(repository.NewAuditLogRepository),

	// Cloud
	fx.Provide(cloud.NewProviderFactory),

	// Notifications
	fx.Provide(ProvideNotificationManager),

	// Services
	fx.Provide(service.NewAuthService),
	fx.Provide(service.NewCloudProviderService),
	fx.Provide(service.NewComputeService),
	fx.Provide(service.NewStorageService),
	fx.Provide(service.NewDatabaseService),
	fx.Provide(service.NewKubernetesService),
	fx.Provide(service.NewAlertService),
	fx.Provide(service.NewMonitoringService),

	// Middleware
	fx.Provide(middleware.NewAuthMiddleware),
	fx.Provide(middleware.NewLoggingMiddleware),
	fx.Provide(ProvideRateLimiter),

	// Handlers
	fx.Provide(handlers.NewAuthHandler),
	fx.Provide(handlers.NewCloudProviderHandler),
	fx.Provide(handlers.NewComputeHandler),
	fx.Provide(handlers.NewStorageHandler),
	fx.Provide(handlers.NewDatabaseHandler),
	fx.Provide(handlers.NewKubernetesHandler),
	fx.Provide(handlers.NewAlertHandler),
	fx.Provide(handlers.NewMonitoringHandler),

	// Router
	fx.Provide(routes.NewRouter),

	// HTTP Server
	fx.Provide(NewHTTPServer),

	// Lifecycle
	fx.Invoke(RegisterLifecycleHooks),
)

// NewLogger creates a new zap logger
func NewLogger(cfg *config.Config) (*zap.Logger, error) {
	var logger *zap.Logger
	var err error

	if cfg.Logging.Development {
		logger, err = zap.NewDevelopment()
	} else {
		zapCfg := zap.NewProductionConfig()
		zapCfg.Level = zap.NewAtomicLevelAt(getLogLevel(cfg.Logging.Level))
		logger, err = zapCfg.Build()
	}

	if err != nil {
		return nil, err
	}

	return logger, nil
}

func getLogLevel(level string) zap.AtomicLevel {
	switch level {
	case "debug":
		return zap.NewAtomicLevelAt(zap.DebugLevel)
	case "info":
		return zap.NewAtomicLevelAt(zap.InfoLevel)
	case "warn":
		return zap.NewAtomicLevelAt(zap.WarnLevel)
	case "error":
		return zap.NewAtomicLevelAt(zap.ErrorLevel)
	default:
		return zap.NewAtomicLevelAt(zap.InfoLevel)
	}
}

// ProvideDatabase creates a database connection pool
func ProvideDatabase(cfg *config.Config, logger *zap.Logger) (*pgxpool.Pool, error) {
	pool, err := database.NewPool(cfg)
	if err != nil {
		return nil, err
	}

	// Run migrations
	if err := database.RunMigrations(cfg); err != nil {
		logger.Warn("Failed to run migrations", zap.Error(err))
	}

	return pool, nil
}

// ProvideNotificationManager creates a notification manager
func ProvideNotificationManager(cfg *config.Config, logger *zap.Logger) *notification.NotificationManager {
	manager := notification.NewNotificationManager(logger)

	// Add email notifier
	if cfg.Email.Host != "" {
		emailNotifier := notification.NewEmailNotifier(&notification.EmailConfig{
			Host:       cfg.Email.Host,
			Port:       cfg.Email.Port,
			Username:   cfg.Email.Username,
			Password:   cfg.Email.Password,
			From:       cfg.Email.From,
			EnableTLS:  cfg.Email.EnableTLS,
		}, logger)
		manager.AddNotifier("email", emailNotifier)
	}

	// Add telegram notifier
	if cfg.Telegram.BotToken != "" {
		telegramNotifier := notification.NewTelegramNotifier(&notification.TelegramConfig{
			BotToken:      cfg.Telegram.BotToken,
			DefaultChatID: cfg.Telegram.DefaultChatID,
		}, logger)
		manager.AddNotifier("telegram", telegramNotifier)
	}

	// Add slack notifier
	if cfg.Slack.BotToken != "" || cfg.Slack.WebhookURL != "" {
		slackNotifier := notification.NewSlackNotifier(&notification.SlackConfig{
			BotToken:       cfg.Slack.BotToken,
			WebhookURL:     cfg.Slack.WebhookURL,
			DefaultChannel: cfg.Slack.DefaultChannel,
		}, logger)
		manager.AddNotifier("slack", slackNotifier)
	}

	return manager
}

// ProvideRateLimiter creates a rate limiter
func ProvideRateLimiter(cfg *config.Config, logger *zap.Logger) *middleware.RateLimiter {
	return middleware.NewRateLimiter(&middleware.RateLimitConfig{
		RequestsPerSecond: 10,
		Burst:             50,
	}, logger)
}

// HTTPServer represents the HTTP server
type HTTPServer struct {
	server *http.Server
	router *routes.Router
	logger *zap.Logger
}

// NewHTTPServer creates a new HTTP server
func NewHTTPServer(cfg *config.Config, router *routes.Router, logger *zap.Logger) *HTTPServer {
	// Set gin mode
	if !cfg.Logging.Development {
		gin.SetMode(gin.ReleaseMode)
	}

	engine := router.Setup()

	server := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port),
		Handler:      engine,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
		IdleTimeout:  120 * time.Second,
	}

	return &HTTPServer{
		server: server,
		router: router,
		logger: logger,
	}
}

// Start starts the HTTP server
func (s *HTTPServer) Start() error {
	s.logger.Info("Starting HTTP server", zap.String("addr", s.server.Addr))
	if err := s.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return err
	}
	return nil
}

// Stop stops the HTTP server
func (s *HTTPServer) Stop(ctx context.Context) error {
	s.logger.Info("Stopping HTTP server")
	return s.server.Shutdown(ctx)
}

// RegisterLifecycleHooks registers fx lifecycle hooks
func RegisterLifecycleHooks(
	lc fx.Lifecycle,
	server *HTTPServer,
	pool *pgxpool.Pool,
	logger *zap.Logger,
) {
	lc.Append(fx.Hook{
		OnStart: func(ctx context.Context) error {
			// Start server in goroutine
			go func() {
				if err := server.Start(); err != nil {
					logger.Error("Server error", zap.Error(err))
				}
			}()
			return nil
		},
		OnStop: func(ctx context.Context) error {
			// Stop server
			if err := server.Stop(ctx); err != nil {
				logger.Error("Error stopping server", zap.Error(err))
			}

			// Close database pool
			pool.Close()
			logger.Info("Database connection closed")

			// Sync logger
			logger.Sync()

			return nil
		},
	})
}

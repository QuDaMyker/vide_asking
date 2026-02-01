package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/vide/cloud-manager-backend/internal/app"
	"github.com/vide/cloud-manager-backend/internal/config"
	"go.uber.org/fx"
	"go.uber.org/zap"
)

// @title Cloud Manager API
// @version 1.0
// @description API for managing Google Cloud, Azure, and AWS resources
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url http://www.example.com/support
// @contact.email support@example.com

// @license.name Apache 2.0
// @license.url http://www.apache.org/licenses/LICENSE-2.0.html

// @host localhost:8080
// @BasePath /api/v1

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Create the application with dependency injection
	application := fx.New(
		// Provide configuration
		fx.Provide(func() *config.Config { return cfg }),

		// Register all modules
		app.Module,

		// Lifecycle hooks
		fx.Invoke(startServer),
	)

	// Start the application
	startCtx, cancel := context.WithTimeout(context.Background(), cfg.Server.StartupTimeout)
	defer cancel()

	if err := application.Start(startCtx); err != nil {
		log.Fatalf("Failed to start application: %v", err)
	}

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	// Graceful shutdown
	stopCtx, stopCancel := context.WithTimeout(context.Background(), cfg.Server.ShutdownTimeout)
	defer stopCancel()

	if err := application.Stop(stopCtx); err != nil {
		log.Fatalf("Failed to stop application: %v", err)
	}
}

func startServer(lc fx.Lifecycle, logger *zap.Logger) {
	lc.Append(fx.Hook{
		OnStart: func(ctx context.Context) error {
			logger.Info("🚀 Cloud Manager Backend starting...")
			return nil
		},
		OnStop: func(ctx context.Context) error {
			logger.Info("🛑 Cloud Manager Backend shutting down...")
			return nil
		},
	})
}

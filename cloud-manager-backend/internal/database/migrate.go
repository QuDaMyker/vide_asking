package database

import (
	"errors"
	"fmt"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/vide/cloud-manager-backend/internal/config"
	"go.uber.org/zap"
)

// Migrator handles database migrations
type Migrator struct {
	migrate *migrate.Migrate
	logger  *zap.Logger
}

// NewMigrator creates a new Migrator instance
func NewMigrator(cfg *config.Config, logger *zap.Logger) (*Migrator, error) {
	// Build database URL
	dbURL := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		cfg.Database.User,
		cfg.Database.Password,
		cfg.Database.Host,
		cfg.Database.Port,
		cfg.Database.Database,
		cfg.Database.SSLMode,
	)

	m, err := migrate.New(cfg.Database.MigrationPath, dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to create migrator: %w", err)
	}

	return &Migrator{
		migrate: m,
		logger:  logger,
	}, nil
}

// Up runs all available migrations
func (m *Migrator) Up() error {
	m.logger.Info("Running database migrations...")

	if err := m.migrate.Up(); err != nil {
		if errors.Is(err, migrate.ErrNoChange) {
			m.logger.Info("No new migrations to apply")
			return nil
		}
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	version, dirty, err := m.migrate.Version()
	if err != nil {
		return fmt.Errorf("failed to get migration version: %w", err)
	}

	m.logger.Info("Migrations completed successfully",
		zap.Uint("version", version),
		zap.Bool("dirty", dirty),
	)

	return nil
}

// Down rolls back the last migration
func (m *Migrator) Down() error {
	m.logger.Info("Rolling back last migration...")

	if err := m.migrate.Steps(-1); err != nil {
		if errors.Is(err, migrate.ErrNoChange) {
			m.logger.Info("No migrations to rollback")
			return nil
		}
		return fmt.Errorf("failed to rollback migration: %w", err)
	}

	m.logger.Info("Rollback completed successfully")
	return nil
}

// Reset rolls back all migrations and re-runs them
func (m *Migrator) Reset() error {
	m.logger.Info("Resetting database...")

	if err := m.migrate.Drop(); err != nil {
		return fmt.Errorf("failed to drop database: %w", err)
	}

	if err := m.migrate.Up(); err != nil {
		if errors.Is(err, migrate.ErrNoChange) {
			return nil
		}
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	m.logger.Info("Database reset completed successfully")
	return nil
}

// Version returns the current migration version
func (m *Migrator) Version() (uint, bool, error) {
	return m.migrate.Version()
}

// Force forces the migration version without running migrations
func (m *Migrator) Force(version int) error {
	return m.migrate.Force(version)
}

// Close closes the migrator
func (m *Migrator) Close() error {
	sourceErr, dbErr := m.migrate.Close()
	if sourceErr != nil {
		return sourceErr
	}
	return dbErr
}

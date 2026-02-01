package config

import (
	"fmt"
	"time"

	"github.com/spf13/viper"
)

// Config holds all configuration for the application
type Config struct {
	Server      ServerConfig      `mapstructure:"server"`
	Database    DatabaseConfig    `mapstructure:"database"`
	JWT         JWTConfig         `mapstructure:"jwt"`
	AWS         AWSConfig         `mapstructure:"aws"`
	GCP         GCPConfig         `mapstructure:"gcp"`
	Azure       AzureConfig       `mapstructure:"azure"`
	Email       EmailConfig       `mapstructure:"email"`
	Telegram    TelegramConfig    `mapstructure:"telegram"`
	Slack       SlackConfig       `mapstructure:"slack"`
	Logging     LoggingConfig     `mapstructure:"logging"`
}

// ServerConfig holds server configuration
type ServerConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	Mode            string        `mapstructure:"mode"` // debug, release, test
	StartupTimeout  time.Duration `mapstructure:"startup_timeout"`
	ShutdownTimeout time.Duration `mapstructure:"shutdown_timeout"`
	ReadTimeout     time.Duration `mapstructure:"read_timeout"`
	WriteTimeout    time.Duration `mapstructure:"write_timeout"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	User            string        `mapstructure:"user"`
	Password        string        `mapstructure:"password"`
	Database        string        `mapstructure:"database"`
	SSLMode         string        `mapstructure:"ssl_mode"`
	MaxOpenConns    int           `mapstructure:"max_open_conns"`
	MaxIdleConns    int           `mapstructure:"max_idle_conns"`
	ConnMaxLifetime time.Duration `mapstructure:"conn_max_lifetime"`
	MigrationPath   string        `mapstructure:"migration_path"`
}

// JWTConfig holds JWT configuration
type JWTConfig struct {
	Secret           string        `mapstructure:"secret"`
	AccessExpiry     time.Duration `mapstructure:"access_expiry"`
	RefreshExpiry    time.Duration `mapstructure:"refresh_expiry"`
	Issuer           string        `mapstructure:"issuer"`
}

// AWSConfig holds AWS configuration
type AWSConfig struct {
	AccessKeyID     string `mapstructure:"access_key_id"`
	SecretAccessKey string `mapstructure:"secret_access_key"`
	Region          string `mapstructure:"region"`
	AssumeRoleARN   string `mapstructure:"assume_role_arn"`
}

// GCPConfig holds Google Cloud configuration
type GCPConfig struct {
	ProjectID          string `mapstructure:"project_id"`
	CredentialsFile    string `mapstructure:"credentials_file"`
	Region             string `mapstructure:"region"`
	Zone               string `mapstructure:"zone"`
}

// AzureConfig holds Azure configuration
type AzureConfig struct {
	TenantID       string `mapstructure:"tenant_id"`
	ClientID       string `mapstructure:"client_id"`
	ClientSecret   string `mapstructure:"client_secret"`
	SubscriptionID string `mapstructure:"subscription_id"`
}

// EmailConfig holds email configuration
type EmailConfig struct {
	Enabled    bool   `mapstructure:"enabled"`
	SMTPHost   string `mapstructure:"smtp_host"`
	SMTPPort   int    `mapstructure:"smtp_port"`
	Username   string `mapstructure:"username"`
	Password   string `mapstructure:"password"`
	FromEmail  string `mapstructure:"from_email"`
	FromName   string `mapstructure:"from_name"`
	UseTLS     bool   `mapstructure:"use_tls"`
}

// TelegramConfig holds Telegram configuration
type TelegramConfig struct {
	Enabled bool   `mapstructure:"enabled"`
	Token   string `mapstructure:"token"`
	ChatID  int64  `mapstructure:"chat_id"`
}

// SlackConfig holds Slack configuration
type SlackConfig struct {
	Enabled    bool   `mapstructure:"enabled"`
	Token      string `mapstructure:"token"`
	ChannelID  string `mapstructure:"channel_id"`
	WebhookURL string `mapstructure:"webhook_url"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	Level      string `mapstructure:"level"`
	Format     string `mapstructure:"format"` // json, console
	OutputPath string `mapstructure:"output_path"`
}

// Load loads configuration from file and environment variables
func Load() (*Config, error) {
	v := viper.New()

	// Set config file path
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath(".")
	v.AddConfigPath("./config")
	v.AddConfigPath("/etc/cloud-manager/")

	// Set environment variable prefix
	v.SetEnvPrefix("CM")
	v.AutomaticEnv()

	// Set default values
	setDefaults(v)

	// Read configuration file
	if err := v.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		// Config file not found, use defaults and environment variables
	}

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return &cfg, nil
}

// setDefaults sets default configuration values
func setDefaults(v *viper.Viper) {
	// Server defaults
	v.SetDefault("server.host", "0.0.0.0")
	v.SetDefault("server.port", 8080)
	v.SetDefault("server.mode", "debug")
	v.SetDefault("server.startup_timeout", "30s")
	v.SetDefault("server.shutdown_timeout", "30s")
	v.SetDefault("server.read_timeout", "30s")
	v.SetDefault("server.write_timeout", "30s")

	// Database defaults
	v.SetDefault("database.host", "localhost")
	v.SetDefault("database.port", 5432)
	v.SetDefault("database.user", "postgres")
	v.SetDefault("database.password", "postgres")
	v.SetDefault("database.database", "cloud_manager")
	v.SetDefault("database.ssl_mode", "disable")
	v.SetDefault("database.max_open_conns", 25)
	v.SetDefault("database.max_idle_conns", 5)
	v.SetDefault("database.conn_max_lifetime", "5m")
	v.SetDefault("database.migration_path", "file://migrations")

	// JWT defaults
	v.SetDefault("jwt.secret", "your-super-secret-key-change-in-production")
	v.SetDefault("jwt.access_expiry", "24h")
	v.SetDefault("jwt.refresh_expiry", "168h")
	v.SetDefault("jwt.issuer", "cloud-manager")

	// AWS defaults
	v.SetDefault("aws.region", "us-east-1")

	// GCP defaults
	v.SetDefault("gcp.region", "us-central1")
	v.SetDefault("gcp.zone", "us-central1-a")

	// Email defaults
	v.SetDefault("email.enabled", false)
	v.SetDefault("email.smtp_port", 587)
	v.SetDefault("email.use_tls", true)

	// Telegram defaults
	v.SetDefault("telegram.enabled", false)

	// Slack defaults
	v.SetDefault("slack.enabled", false)

	// Logging defaults
	v.SetDefault("logging.level", "info")
	v.SetDefault("logging.format", "json")
	v.SetDefault("logging.output_path", "stdout")
}

// GetDSN returns the PostgreSQL connection string
func (c *DatabaseConfig) GetDSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.Database, c.SSLMode,
	)
}

// GetAddress returns the server address
func (c *ServerConfig) GetAddress() string {
	return fmt.Sprintf("%s:%d", c.Host, c.Port)
}

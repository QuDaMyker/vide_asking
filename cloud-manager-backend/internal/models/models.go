package models

import (
	"time"

	"github.com/google/uuid"
)

// User represents a user in the system
type User struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	Email        string     `json:"email" db:"email"`
	PasswordHash string     `json:"-" db:"password_hash"`
	FirstName    string     `json:"first_name" db:"first_name"`
	LastName     string     `json:"last_name" db:"last_name"`
	AvatarURL    string     `json:"avatar_url" db:"avatar_url"`
	Role         string     `json:"role" db:"role"`
	Status       string     `json:"status" db:"status"`
	LastLoginAt  *time.Time `json:"last_login_at" db:"last_login_at"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}

// UserRole constants
const (
	RoleAdmin     = "admin"
	RoleModerator = "moderator"
	RoleUser      = "user"
)

// UserStatus constants
const (
	StatusActive   = "active"
	StatusInactive = "inactive"
	StatusBanned   = "banned"
)

// CloudProvider represents a cloud provider configuration
type CloudProvider struct {
	ID           uuid.UUID              `json:"id" db:"id"`
	UserID       uuid.UUID              `json:"user_id" db:"user_id"`
	Name         string                 `json:"name" db:"name"`
	ProviderType ProviderType           `json:"provider_type" db:"provider_type"`
	Credentials  map[string]interface{} `json:"-" db:"credentials"`
	Region       string                 `json:"region" db:"region"`
	IsDefault    bool                   `json:"is_default" db:"is_default"`
	Status       string                 `json:"status" db:"status"`
	LastSyncedAt *time.Time             `json:"last_synced_at" db:"last_synced_at"`
	CreatedAt    time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time              `json:"updated_at" db:"updated_at"`
}

// ProviderType represents the type of cloud provider
type ProviderType string

const (
	ProviderAWS   ProviderType = "aws"
	ProviderGCP   ProviderType = "gcp"
	ProviderAzure ProviderType = "azure"
)

// CloudResource represents a cloud resource
type CloudResource struct {
	ID           uuid.UUID              `json:"id" db:"id"`
	ProviderID   uuid.UUID              `json:"provider_id" db:"provider_id"`
	ResourceID   string                 `json:"resource_id" db:"resource_id"`
	ResourceType ResourceType           `json:"resource_type" db:"resource_type"`
	Name         string                 `json:"name" db:"name"`
	Region       string                 `json:"region" db:"region"`
	Zone         string                 `json:"zone" db:"zone"`
	Status       string                 `json:"status" db:"status"`
	Tags         map[string]string      `json:"tags" db:"tags"`
	Metadata     map[string]interface{} `json:"metadata" db:"metadata"`
	CostHourly   float64                `json:"cost_hourly" db:"cost_hourly"`
	CostMonthly  float64                `json:"cost_monthly" db:"cost_monthly"`
	CreatedAt    time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time              `json:"updated_at" db:"updated_at"`
}

// ResourceType represents the type of cloud resource
type ResourceType string

// Compute resources
const (
	ResourceTypeEC2             ResourceType = "ec2"
	ResourceTypeAzureVM         ResourceType = "azure_vm"
	ResourceTypeGCEInstance     ResourceType = "gce_instance"
	ResourceTypeLambda          ResourceType = "lambda"
	ResourceTypeAzureFunction   ResourceType = "azure_function"
	ResourceTypeCloudFunction   ResourceType = "cloud_function"
)

// Storage resources
const (
	ResourceTypeS3          ResourceType = "s3"
	ResourceTypeAzureBlob   ResourceType = "azure_blob"
	ResourceTypeGCS         ResourceType = "gcs"
	ResourceTypeEBS         ResourceType = "ebs"
	ResourceTypeAzureDisk   ResourceType = "azure_disk"
	ResourceTypeGCEDisk     ResourceType = "gce_disk"
)

// Database resources
const (
	ResourceTypeRDS             ResourceType = "rds"
	ResourceTypeAzureSQL        ResourceType = "azure_sql"
	ResourceTypeCloudSQL        ResourceType = "cloud_sql"
	ResourceTypeDynamoDB        ResourceType = "dynamodb"
	ResourceTypeCosmosDB        ResourceType = "cosmos_db"
	ResourceTypeFirestore       ResourceType = "firestore"
)

// Container resources
const (
	ResourceTypeECS         ResourceType = "ecs"
	ResourceTypeEKS         ResourceType = "eks"
	ResourceTypeAKS         ResourceType = "aks"
	ResourceTypeGKE         ResourceType = "gke"
	ResourceTypeContainerApp ResourceType = "container_app"
	ResourceTypeCloudRun    ResourceType = "cloud_run"
)

// Network resources
const (
	ResourceTypeVPC            ResourceType = "vpc"
	ResourceTypeAzureVNet      ResourceType = "azure_vnet"
	ResourceTypeGCENetwork     ResourceType = "gce_network"
	ResourceTypeLoadBalancer   ResourceType = "load_balancer"
)

// ResourceMetric represents a metric for a cloud resource
type ResourceMetric struct {
	ID          uuid.UUID              `json:"id" db:"id"`
	ResourceID  uuid.UUID              `json:"resource_id" db:"resource_id"`
	MetricName  string                 `json:"metric_name" db:"metric_name"`
	MetricValue float64                `json:"metric_value" db:"metric_value"`
	Unit        string                 `json:"unit" db:"unit"`
	Timestamp   time.Time              `json:"timestamp" db:"timestamp"`
	Metadata    map[string]interface{} `json:"metadata" db:"metadata"`
}

// Alert represents an alert configuration
type Alert struct {
	ID                   uuid.UUID              `json:"id" db:"id"`
	UserID               uuid.UUID              `json:"user_id" db:"user_id"`
	ResourceID           *uuid.UUID             `json:"resource_id" db:"resource_id"`
	Name                 string                 `json:"name" db:"name"`
	Description          string                 `json:"description" db:"description"`
	AlertType            AlertType              `json:"alert_type" db:"alert_type"`
	Condition            map[string]interface{} `json:"condition" db:"condition"`
	Severity             Severity               `json:"severity" db:"severity"`
	Status               string                 `json:"status" db:"status"`
	NotificationChannels []string               `json:"notification_channels" db:"notification_channels"`
	LastTriggeredAt      *time.Time             `json:"last_triggered_at" db:"last_triggered_at"`
	CreatedAt            time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time              `json:"updated_at" db:"updated_at"`
}

// AlertType represents the type of alert
type AlertType string

const (
	AlertTypeThreshold AlertType = "threshold"
	AlertTypeAnomaly   AlertType = "anomaly"
	AlertTypeBilling   AlertType = "billing"
	AlertTypeHealth    AlertType = "health"
)

// Severity represents alert severity level
type Severity string

const (
	SeverityLow      Severity = "low"
	SeverityMedium   Severity = "medium"
	SeverityHigh     Severity = "high"
	SeverityCritical Severity = "critical"
)

// AlertHistory represents an alert event
type AlertHistory struct {
	ID               uuid.UUID  `json:"id" db:"id"`
	AlertID          uuid.UUID  `json:"alert_id" db:"alert_id"`
	TriggeredAt      time.Time  `json:"triggered_at" db:"triggered_at"`
	ResolvedAt       *time.Time `json:"resolved_at" db:"resolved_at"`
	Status           string     `json:"status" db:"status"`
	Message          string     `json:"message" db:"message"`
	MetricValue      float64    `json:"metric_value" db:"metric_value"`
	NotificationSent bool       `json:"notification_sent" db:"notification_sent"`
}

// CostReport represents a cost report
type CostReport struct {
	ID         uuid.UUID              `json:"id" db:"id"`
	ProviderID uuid.UUID              `json:"provider_id" db:"provider_id"`
	ReportDate time.Time              `json:"report_date" db:"report_date"`
	TotalCost  float64                `json:"total_cost" db:"total_cost"`
	Currency   string                 `json:"currency" db:"currency"`
	Breakdown  map[string]interface{} `json:"breakdown" db:"breakdown"`
	CreatedAt  time.Time              `json:"created_at" db:"created_at"`
}

// AuditLog represents an audit log entry
type AuditLog struct {
	ID           uuid.UUID              `json:"id" db:"id"`
	UserID       *uuid.UUID             `json:"user_id" db:"user_id"`
	Action       string                 `json:"action" db:"action"`
	ResourceType string                 `json:"resource_type" db:"resource_type"`
	ResourceID   string                 `json:"resource_id" db:"resource_id"`
	ProviderType string                 `json:"provider_type" db:"provider_type"`
	OldValue     map[string]interface{} `json:"old_value" db:"old_value"`
	NewValue     map[string]interface{} `json:"new_value" db:"new_value"`
	IPAddress    string                 `json:"ip_address" db:"ip_address"`
	UserAgent    string                 `json:"user_agent" db:"user_agent"`
	Status       string                 `json:"status" db:"status"`
	ErrorMessage string                 `json:"error_message" db:"error_message"`
	CreatedAt    time.Time              `json:"created_at" db:"created_at"`
}

// ScheduledJob represents a scheduled job
type ScheduledJob struct {
	ID               uuid.UUID              `json:"id" db:"id"`
	UserID           uuid.UUID              `json:"user_id" db:"user_id"`
	Name             string                 `json:"name" db:"name"`
	Description      string                 `json:"description" db:"description"`
	JobType          JobType                `json:"job_type" db:"job_type"`
	TargetResourceID *uuid.UUID             `json:"target_resource_id" db:"target_resource_id"`
	Schedule         string                 `json:"schedule" db:"schedule"`
	Parameters       map[string]interface{} `json:"parameters" db:"parameters"`
	IsEnabled        bool                   `json:"is_enabled" db:"is_enabled"`
	LastRunAt        *time.Time             `json:"last_run_at" db:"last_run_at"`
	NextRunAt        *time.Time             `json:"next_run_at" db:"next_run_at"`
	CreatedAt        time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time              `json:"updated_at" db:"updated_at"`
}

// JobType represents the type of scheduled job
type JobType string

const (
	JobTypeBackup   JobType = "backup"
	JobTypeSnapshot JobType = "snapshot"
	JobTypeStart    JobType = "start"
	JobTypeStop     JobType = "stop"
	JobTypeScale    JobType = "scale"
	JobTypeCleanup  JobType = "cleanup"
)

// JobExecution represents a job execution record
type JobExecution struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	JobID        uuid.UUID  `json:"job_id" db:"job_id"`
	StartedAt    time.Time  `json:"started_at" db:"started_at"`
	FinishedAt   *time.Time `json:"finished_at" db:"finished_at"`
	Status       string     `json:"status" db:"status"`
	Output       string     `json:"output" db:"output"`
	ErrorMessage string     `json:"error_message" db:"error_message"`
}

// NotificationPreference represents notification preferences
type NotificationPreference struct {
	ID        uuid.UUID              `json:"id" db:"id"`
	UserID    uuid.UUID              `json:"user_id" db:"user_id"`
	Channel   NotificationChannel    `json:"channel" db:"channel"`
	IsEnabled bool                   `json:"is_enabled" db:"is_enabled"`
	Config    map[string]interface{} `json:"config" db:"config"`
	CreatedAt time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt time.Time              `json:"updated_at" db:"updated_at"`
}

// NotificationChannel represents notification channel types
type NotificationChannel string

const (
	ChannelEmail    NotificationChannel = "email"
	ChannelTelegram NotificationChannel = "telegram"
	ChannelSlack    NotificationChannel = "slack"
)

// RefreshToken represents a refresh token
type RefreshToken struct {
	ID        uuid.UUID `json:"id" db:"id"`
	UserID    uuid.UUID `json:"user_id" db:"user_id"`
	Token     string    `json:"token" db:"token"`
	ExpiresAt time.Time `json:"expires_at" db:"expires_at"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

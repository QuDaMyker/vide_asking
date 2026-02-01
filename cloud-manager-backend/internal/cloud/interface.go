package cloud

import (
	"context"

	"github.com/vide/cloud-manager-backend/internal/models"
)

// CloudProvider defines the interface for cloud provider operations
type CloudProvider interface {
	// Connection
	Connect(ctx context.Context) error
	Disconnect() error
	HealthCheck(ctx context.Context) error

	// Compute Operations
	ListInstances(ctx context.Context, region string) ([]*ComputeInstance, error)
	GetInstance(ctx context.Context, instanceID string) (*ComputeInstance, error)
	StartInstance(ctx context.Context, instanceID string) error
	StopInstance(ctx context.Context, instanceID string) error
	RebootInstance(ctx context.Context, instanceID string) error
	TerminateInstance(ctx context.Context, instanceID string) error
	CreateInstance(ctx context.Context, params *CreateInstanceParams) (*ComputeInstance, error)

	// Storage Operations
	ListBuckets(ctx context.Context) ([]*StorageBucket, error)
	CreateBucket(ctx context.Context, params *CreateBucketParams) (*StorageBucket, error)
	DeleteBucket(ctx context.Context, bucketName string) error
	ListObjects(ctx context.Context, bucketName, prefix string, maxKeys int) ([]*StorageObject, error)

	// Database Operations
	ListDatabases(ctx context.Context, region string) ([]*DatabaseInstance, error)
	GetDatabase(ctx context.Context, instanceID string) (*DatabaseInstance, error)
	StartDatabase(ctx context.Context, instanceID string) error
	StopDatabase(ctx context.Context, instanceID string) error

	// Kubernetes Operations
	ListClusters(ctx context.Context, region string) ([]*KubernetesCluster, error)
	GetCluster(ctx context.Context, clusterName string) (*KubernetesCluster, error)

	// Serverless Operations
	ListFunctions(ctx context.Context, region string) ([]*ServerlessFunction, error)
	InvokeFunction(ctx context.Context, functionName string, payload []byte) ([]byte, error)

	// Network Operations
	ListVPCs(ctx context.Context, region string) ([]*VirtualNetwork, error)
	ListLoadBalancers(ctx context.Context, region string) ([]*LoadBalancer, error)

	// Monitoring Operations
	GetMetrics(ctx context.Context, params *MetricsParams) ([]*MetricData, error)
	GetLogs(ctx context.Context, params *LogsParams) ([]*LogEntry, error)

	// Cost Operations
	GetCostAndUsage(ctx context.Context, params *CostParams) (*CostReport, error)

	// IAM Operations
	ListUsers(ctx context.Context) ([]*IAMUser, error)
	ListRoles(ctx context.Context) ([]*IAMRole, error)

	// Regions and Availability
	ListRegions(ctx context.Context) ([]*Region, error)
	ListAvailabilityZones(ctx context.Context, region string) ([]*AvailabilityZone, error)

	// Resource Tagging
	TagResource(ctx context.Context, resourceID string, tags map[string]string) error
	UntagResource(ctx context.Context, resourceID string, tagKeys []string) error

	// Provider Info
	GetProviderType() models.ProviderType
}

// ComputeInstance represents a virtual machine instance
type ComputeInstance struct {
	ID               string            `json:"id"`
	Name             string            `json:"name"`
	State            string            `json:"state"`
	InstanceType     string            `json:"instance_type"`
	Region           string            `json:"region"`
	Zone             string            `json:"zone"`
	PublicIP         string            `json:"public_ip"`
	PrivateIP        string            `json:"private_ip"`
	Platform         string            `json:"platform"`
	LaunchTime       string            `json:"launch_time"`
	Tags             map[string]string `json:"tags"`
	CPUUtilization   float64           `json:"cpu_utilization"`
	MemoryUtilization float64          `json:"memory_utilization"`
	DiskSize         int64             `json:"disk_size"`
	NetworkIn        int64             `json:"network_in"`
	NetworkOut       int64             `json:"network_out"`
}

// CreateInstanceParams contains parameters for creating an instance
type CreateInstanceParams struct {
	Name         string            `json:"name"`
	InstanceType string            `json:"instance_type"`
	ImageID      string            `json:"image_id"`
	Region       string            `json:"region"`
	Zone         string            `json:"zone"`
	KeyName      string            `json:"key_name"`
	SecurityGroups []string        `json:"security_groups"`
	SubnetID     string            `json:"subnet_id"`
	Tags         map[string]string `json:"tags"`
	UserData     string            `json:"user_data"`
	DiskSize     int64             `json:"disk_size"`
	DiskType     string            `json:"disk_type"`
}

// StorageBucket represents a cloud storage bucket
type StorageBucket struct {
	Name         string `json:"name"`
	Region       string `json:"region"`
	CreationDate string `json:"creation_date"`
	Size         int64  `json:"size"`
	ObjectCount  int64  `json:"object_count"`
	Versioning   bool   `json:"versioning"`
	Encryption   string `json:"encryption"`
}

// CreateBucketParams contains parameters for creating a bucket
type CreateBucketParams struct {
	Name       string `json:"name"`
	Region     string `json:"region"`
	ACL        string `json:"acl"`
	Versioning bool   `json:"versioning"`
	Encryption string `json:"encryption"`
}

// StorageObject represents an object in storage
type StorageObject struct {
	Key          string `json:"key"`
	Size         int64  `json:"size"`
	LastModified string `json:"last_modified"`
	ETag         string `json:"etag"`
	StorageClass string `json:"storage_class"`
}

// DatabaseInstance represents a managed database instance
type DatabaseInstance struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Engine         string   `json:"engine"`
	EngineVersion  string   `json:"engine_version"`
	InstanceClass  string   `json:"instance_class"`
	Status         string   `json:"status"`
	Endpoint       string   `json:"endpoint"`
	Port           int      `json:"port"`
	Region         string   `json:"region"`
	Zone           string   `json:"zone"`
	StorageSize    int64    `json:"storage_size"`
	StorageType    string   `json:"storage_type"`
	MultiAZ        bool     `json:"multi_az"`
	BackupRetention int     `json:"backup_retention"`
}

// KubernetesCluster represents a managed Kubernetes cluster
type KubernetesCluster struct {
	ID               string `json:"id"`
	Name             string `json:"name"`
	Status           string `json:"status"`
	Version          string `json:"version"`
	Endpoint         string `json:"endpoint"`
	Region           string `json:"region"`
	NodeCount        int    `json:"node_count"`
	NodeInstanceType string `json:"node_instance_type"`
	CreatedAt        string `json:"created_at"`
}

// ServerlessFunction represents a serverless function
type ServerlessFunction struct {
	Name        string `json:"name"`
	Runtime     string `json:"runtime"`
	Handler     string `json:"handler"`
	MemorySize  int    `json:"memory_size"`
	Timeout     int    `json:"timeout"`
	CodeSize    int64  `json:"code_size"`
	LastModified string `json:"last_modified"`
	Description string `json:"description"`
}

// VirtualNetwork represents a virtual network/VPC
type VirtualNetwork struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	CIDRBlock string   `json:"cidr_block"`
	Region    string   `json:"region"`
	State     string   `json:"state"`
	IsDefault bool     `json:"is_default"`
	Subnets   []string `json:"subnets"`
}

// LoadBalancer represents a load balancer
type LoadBalancer struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	Type      string   `json:"type"`
	Scheme    string   `json:"scheme"`
	DNSName   string   `json:"dns_name"`
	State     string   `json:"state"`
	Region    string   `json:"region"`
	Zones     []string `json:"zones"`
}

// MetricsParams contains parameters for fetching metrics
type MetricsParams struct {
	ResourceID  string `json:"resource_id"`
	MetricName  string `json:"metric_name"`
	StartTime   string `json:"start_time"`
	EndTime     string `json:"end_time"`
	Period      int    `json:"period"`
	Statistics  string `json:"statistics"`
}

// MetricData represents metric data
type MetricData struct {
	Timestamp string  `json:"timestamp"`
	Value     float64 `json:"value"`
	Unit      string  `json:"unit"`
}

// LogsParams contains parameters for fetching logs
type LogsParams struct {
	LogGroup  string `json:"log_group"`
	StartTime string `json:"start_time"`
	EndTime   string `json:"end_time"`
	Filter    string `json:"filter"`
	Limit     int    `json:"limit"`
}

// LogEntry represents a log entry
type LogEntry struct {
	Timestamp string `json:"timestamp"`
	Message   string `json:"message"`
	LogStream string `json:"log_stream"`
}

// CostParams contains parameters for cost reports
type CostParams struct {
	StartDate   string   `json:"start_date"`
	EndDate     string   `json:"end_date"`
	Granularity string   `json:"granularity"`
	GroupBy     []string `json:"group_by"`
}

// CostReport represents cost and usage data
type CostReport struct {
	TotalCost  float64              `json:"total_cost"`
	Currency   string               `json:"currency"`
	Period     string               `json:"period"`
	ByService  map[string]float64   `json:"by_service"`
	ByRegion   map[string]float64   `json:"by_region"`
	ByResource map[string]float64   `json:"by_resource"`
	DailyCosts []DailyCost          `json:"daily_costs"`
}

// DailyCost represents daily cost data
type DailyCost struct {
	Date string  `json:"date"`
	Cost float64 `json:"cost"`
}

// IAMUser represents an IAM user
type IAMUser struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	ARN        string `json:"arn"`
	CreateDate string `json:"create_date"`
	LastLogin  string `json:"last_login"`
}

// IAMRole represents an IAM role
type IAMRole struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	ARN        string   `json:"arn"`
	CreateDate string   `json:"create_date"`
	Policies   []string `json:"policies"`
}

// Region represents a cloud region
type Region struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Endpoint string `json:"endpoint"`
}

// AvailabilityZone represents an availability zone
type AvailabilityZone struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	State  string `json:"state"`
	Region string `json:"region"`
}

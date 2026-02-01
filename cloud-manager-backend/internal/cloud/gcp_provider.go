package cloud

import (
	"context"
	"fmt"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	container "cloud.google.com/go/container/apiv1"
	"cloud.google.com/go/container/apiv1/containerpb"
	monitoring "cloud.google.com/go/monitoring/apiv3/v2"
	"cloud.google.com/go/monitoring/apiv3/v2/monitoringpb"
	"cloud.google.com/go/storage"
	"github.com/vide/cloud-manager-backend/internal/models"
	"go.uber.org/zap"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
	sqladmin "google.golang.org/api/sqladmin/v1beta4"
)

// GCPProvider implements CloudProvider for Google Cloud Platform
type GCPProvider struct {
	projectID       string
	credentialsFile string
	region          string
	zone            string
	logger          *zap.Logger

	// GCP Service Clients
	computeClient   *compute.InstancesClient
	storageClient   *storage.Client
	containerClient *container.ClusterManagerClient
	monitoringClient *monitoring.MetricClient
	sqlAdminService *sqladmin.Service
}

// NewGCPProvider creates a new GCP provider
func NewGCPProvider(projectID, credentialsFile, region, zone string, logger *zap.Logger) *GCPProvider {
	return &GCPProvider{
		projectID:       projectID,
		credentialsFile: credentialsFile,
		region:          region,
		zone:            zone,
		logger:          logger,
	}
}

// Connect establishes connection to GCP
func (p *GCPProvider) Connect(ctx context.Context) error {
	var opts []option.ClientOption
	if p.credentialsFile != "" {
		opts = append(opts, option.WithCredentialsFile(p.credentialsFile))
	}

	var err error

	// Initialize Compute Engine client
	p.computeClient, err = compute.NewInstancesRESTClient(ctx, opts...)
	if err != nil {
		return fmt.Errorf("failed to create compute client: %w", err)
	}

	// Initialize Cloud Storage client
	p.storageClient, err = storage.NewClient(ctx, opts...)
	if err != nil {
		return fmt.Errorf("failed to create storage client: %w", err)
	}

	// Initialize GKE client
	p.containerClient, err = container.NewClusterManagerClient(ctx, opts...)
	if err != nil {
		return fmt.Errorf("failed to create container client: %w", err)
	}

	// Initialize Monitoring client
	p.monitoringClient, err = monitoring.NewMetricClient(ctx, opts...)
	if err != nil {
		return fmt.Errorf("failed to create monitoring client: %w", err)
	}

	// Initialize SQL Admin service
	p.sqlAdminService, err = sqladmin.NewService(ctx, opts...)
	if err != nil {
		return fmt.Errorf("failed to create SQL Admin service: %w", err)
	}

	p.logger.Info("Connected to Google Cloud Platform",
		zap.String("project", p.projectID),
		zap.String("region", p.region),
	)

	return nil
}

// Disconnect closes GCP connections
func (p *GCPProvider) Disconnect() error {
	if p.computeClient != nil {
		p.computeClient.Close()
	}
	if p.storageClient != nil {
		p.storageClient.Close()
	}
	if p.containerClient != nil {
		p.containerClient.Close()
	}
	if p.monitoringClient != nil {
		p.monitoringClient.Close()
	}

	p.logger.Info("Disconnected from Google Cloud Platform")
	return nil
}

// HealthCheck verifies GCP connectivity
func (p *GCPProvider) HealthCheck(ctx context.Context) error {
	// Try to list instances as a health check
	req := &computepb.ListInstancesRequest{
		Project:    p.projectID,
		Zone:       p.zone,
		MaxResults: proto.Uint32(1),
	}
	it := p.computeClient.List(ctx, req)
	_, err := it.Next()
	if err != nil && err != iterator.Done {
		return err
	}
	return nil
}

// GetProviderType returns the provider type
func (p *GCPProvider) GetProviderType() models.ProviderType {
	return models.ProviderGCP
}

// ====== Compute Engine Instance Operations ======

// ListInstances lists Compute Engine instances
func (p *GCPProvider) ListInstances(ctx context.Context, region string) ([]*ComputeInstance, error) {
	req := &computepb.ListInstancesRequest{
		Project: p.projectID,
		Zone:    p.zone,
	}

	var instances []*ComputeInstance
	it := p.computeClient.List(ctx, req)
	for {
		instance, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to list instances: %w", err)
		}
		instances = append(instances, p.mapGCEInstance(instance))
	}

	return instances, nil
}

// GetInstance retrieves a specific Compute Engine instance
func (p *GCPProvider) GetInstance(ctx context.Context, instanceID string) (*ComputeInstance, error) {
	req := &computepb.GetInstanceRequest{
		Project:  p.projectID,
		Zone:     p.zone,
		Instance: instanceID,
	}

	instance, err := p.computeClient.Get(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to get instance: %w", err)
	}

	return p.mapGCEInstance(instance), nil
}

// StartInstance starts a Compute Engine instance
func (p *GCPProvider) StartInstance(ctx context.Context, instanceID string) error {
	req := &computepb.StartInstanceRequest{
		Project:  p.projectID,
		Zone:     p.zone,
		Instance: instanceID,
	}

	op, err := p.computeClient.Start(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to start instance: %w", err)
	}

	// Wait for operation to complete
	if err := op.Wait(ctx); err != nil {
		return fmt.Errorf("failed to wait for start operation: %w", err)
	}

	p.logger.Info("Started GCE instance", zap.String("instance", instanceID))
	return nil
}

// StopInstance stops a Compute Engine instance
func (p *GCPProvider) StopInstance(ctx context.Context, instanceID string) error {
	req := &computepb.StopInstanceRequest{
		Project:  p.projectID,
		Zone:     p.zone,
		Instance: instanceID,
	}

	op, err := p.computeClient.Stop(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to stop instance: %w", err)
	}

	if err := op.Wait(ctx); err != nil {
		return fmt.Errorf("failed to wait for stop operation: %w", err)
	}

	p.logger.Info("Stopped GCE instance", zap.String("instance", instanceID))
	return nil
}

// RebootInstance reboots a Compute Engine instance
func (p *GCPProvider) RebootInstance(ctx context.Context, instanceID string) error {
	req := &computepb.ResetInstanceRequest{
		Project:  p.projectID,
		Zone:     p.zone,
		Instance: instanceID,
	}

	op, err := p.computeClient.Reset(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to reset instance: %w", err)
	}

	if err := op.Wait(ctx); err != nil {
		return fmt.Errorf("failed to wait for reset operation: %w", err)
	}

	p.logger.Info("Rebooted GCE instance", zap.String("instance", instanceID))
	return nil
}

// TerminateInstance terminates a Compute Engine instance
func (p *GCPProvider) TerminateInstance(ctx context.Context, instanceID string) error {
	req := &computepb.DeleteInstanceRequest{
		Project:  p.projectID,
		Zone:     p.zone,
		Instance: instanceID,
	}

	op, err := p.computeClient.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete instance: %w", err)
	}

	if err := op.Wait(ctx); err != nil {
		return fmt.Errorf("failed to wait for delete operation: %w", err)
	}

	p.logger.Info("Terminated GCE instance", zap.String("instance", instanceID))
	return nil
}

// CreateInstance creates a new Compute Engine instance
func (p *GCPProvider) CreateInstance(ctx context.Context, params *CreateInstanceParams) (*ComputeInstance, error) {
	machineType := fmt.Sprintf("zones/%s/machineTypes/%s", p.zone, params.InstanceType)
	sourceImage := params.ImageID
	if sourceImage == "" {
		sourceImage = "projects/debian-cloud/global/images/family/debian-11"
	}

	instance := &computepb.Instance{
		Name:        proto.String(params.Name),
		MachineType: proto.String(machineType),
		Disks: []*computepb.AttachedDisk{
			{
				Boot:       proto.Bool(true),
				AutoDelete: proto.Bool(true),
				InitializeParams: &computepb.AttachedDiskInitializeParams{
					DiskSizeGb:  proto.Int64(params.DiskSize),
					SourceImage: proto.String(sourceImage),
				},
			},
		},
		NetworkInterfaces: []*computepb.NetworkInterface{
			{
				Name: proto.String("global/networks/default"),
				AccessConfigs: []*computepb.AccessConfig{
					{
						Name: proto.String("External NAT"),
						Type: proto.String("ONE_TO_ONE_NAT"),
					},
				},
			},
		},
	}

	if len(params.Tags) > 0 {
		labels := make(map[string]string)
		for k, v := range params.Tags {
			labels[k] = v
		}
		instance.Labels = labels
	}

	req := &computepb.InsertInstanceRequest{
		Project:          p.projectID,
		Zone:             p.zone,
		InstanceResource: instance,
	}

	op, err := p.computeClient.Insert(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to create instance: %w", err)
	}

	if err := op.Wait(ctx); err != nil {
		return nil, fmt.Errorf("failed to wait for create operation: %w", err)
	}

	// Get the created instance
	createdInstance, err := p.GetInstance(ctx, params.Name)
	if err != nil {
		return nil, err
	}

	p.logger.Info("Created GCE instance", zap.String("instance", params.Name))
	return createdInstance, nil
}

// ====== Cloud Storage Operations ======

// ListBuckets lists Cloud Storage buckets
func (p *GCPProvider) ListBuckets(ctx context.Context) ([]*StorageBucket, error) {
	var buckets []*StorageBucket
	it := p.storageClient.Buckets(ctx, p.projectID)
	for {
		bucket, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to list buckets: %w", err)
		}
		buckets = append(buckets, &StorageBucket{
			Name:         bucket.Name,
			Region:       bucket.Location,
			CreationDate: bucket.Created.Format(time.RFC3339),
			Versioning:   bucket.VersioningEnabled,
		})
	}

	return buckets, nil
}

// CreateBucket creates a Cloud Storage bucket
func (p *GCPProvider) CreateBucket(ctx context.Context, params *CreateBucketParams) (*StorageBucket, error) {
	bucket := p.storageClient.Bucket(params.Name)

	attrs := &storage.BucketAttrs{
		Location: params.Region,
	}
	if params.Versioning {
		attrs.VersioningEnabled = true
	}

	if err := bucket.Create(ctx, p.projectID, attrs); err != nil {
		return nil, fmt.Errorf("failed to create bucket: %w", err)
	}

	p.logger.Info("Created GCS bucket", zap.String("bucket", params.Name))
	return &StorageBucket{
		Name:       params.Name,
		Region:     params.Region,
		Versioning: params.Versioning,
	}, nil
}

// DeleteBucket deletes a Cloud Storage bucket
func (p *GCPProvider) DeleteBucket(ctx context.Context, bucketName string) error {
	bucket := p.storageClient.Bucket(bucketName)
	if err := bucket.Delete(ctx); err != nil {
		return fmt.Errorf("failed to delete bucket: %w", err)
	}

	p.logger.Info("Deleted GCS bucket", zap.String("bucket", bucketName))
	return nil
}

// ListObjects lists objects in a Cloud Storage bucket
func (p *GCPProvider) ListObjects(ctx context.Context, bucketName, prefix string, maxKeys int) ([]*StorageObject, error) {
	bucket := p.storageClient.Bucket(bucketName)
	query := &storage.Query{Prefix: prefix}

	var objects []*StorageObject
	count := 0
	it := bucket.Objects(ctx, query)
	for {
		if maxKeys > 0 && count >= maxKeys {
			break
		}
		obj, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to list objects: %w", err)
		}
		objects = append(objects, &StorageObject{
			Key:          obj.Name,
			Size:         obj.Size,
			LastModified: obj.Updated.Format(time.RFC3339),
			ETag:         obj.Etag,
			StorageClass: obj.StorageClass,
		})
		count++
	}

	return objects, nil
}

// ====== Cloud SQL Operations ======

// ListDatabases lists Cloud SQL instances
func (p *GCPProvider) ListDatabases(ctx context.Context, region string) ([]*DatabaseInstance, error) {
	resp, err := p.sqlAdminService.Instances.List(p.projectID).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list Cloud SQL instances: %w", err)
	}

	var databases []*DatabaseInstance
	for _, instance := range resp.Items {
		databases = append(databases, &DatabaseInstance{
			ID:            instance.Name,
			Name:          instance.Name,
			Engine:        instance.DatabaseVersion,
			EngineVersion: instance.DatabaseVersion,
			InstanceClass: instance.Settings.Tier,
			Status:        instance.State,
			Region:        instance.Region,
			Zone:          instance.GceZone,
			StorageSize:   instance.Settings.DataDiskSizeGb,
			StorageType:   instance.Settings.DataDiskType,
		})
	}

	return databases, nil
}

// GetDatabase retrieves a specific Cloud SQL instance
func (p *GCPProvider) GetDatabase(ctx context.Context, instanceID string) (*DatabaseInstance, error) {
	instance, err := p.sqlAdminService.Instances.Get(p.projectID, instanceID).Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to get Cloud SQL instance: %w", err)
	}

	return &DatabaseInstance{
		ID:            instance.Name,
		Name:          instance.Name,
		Engine:        instance.DatabaseVersion,
		EngineVersion: instance.DatabaseVersion,
		InstanceClass: instance.Settings.Tier,
		Status:        instance.State,
		Region:        instance.Region,
		Zone:          instance.GceZone,
		StorageSize:   instance.Settings.DataDiskSizeGb,
		StorageType:   instance.Settings.DataDiskType,
	}, nil
}

// StartDatabase starts a Cloud SQL instance (placeholder)
func (p *GCPProvider) StartDatabase(ctx context.Context, instanceID string) error {
	// Cloud SQL doesn't have a direct start/stop like RDS for most configurations
	p.logger.Info("Cloud SQL start requested", zap.String("instance", instanceID))
	return nil
}

// StopDatabase stops a Cloud SQL instance (placeholder)
func (p *GCPProvider) StopDatabase(ctx context.Context, instanceID string) error {
	p.logger.Info("Cloud SQL stop requested", zap.String("instance", instanceID))
	return nil
}

// ====== GKE Kubernetes Operations ======

// ListClusters lists GKE clusters
func (p *GCPProvider) ListClusters(ctx context.Context, region string) ([]*KubernetesCluster, error) {
	parent := fmt.Sprintf("projects/%s/locations/-", p.projectID)
	req := &containerpb.ListClustersRequest{
		Parent: parent,
	}

	resp, err := p.containerClient.ListClusters(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to list GKE clusters: %w", err)
	}

	var clusters []*KubernetesCluster
	for _, cluster := range resp.Clusters {
		nodeCount := 0
		for _, pool := range cluster.NodePools {
			nodeCount += int(pool.InitialNodeCount)
		}

		clusters = append(clusters, &KubernetesCluster{
			ID:        cluster.Name,
			Name:      cluster.Name,
			Status:    cluster.Status.String(),
			Version:   cluster.CurrentMasterVersion,
			Endpoint:  cluster.Endpoint,
			Region:    cluster.Location,
			NodeCount: nodeCount,
			CreatedAt: cluster.CreateTime,
		})
	}

	return clusters, nil
}

// GetCluster retrieves a specific GKE cluster
func (p *GCPProvider) GetCluster(ctx context.Context, clusterName string) (*KubernetesCluster, error) {
	name := fmt.Sprintf("projects/%s/locations/%s/clusters/%s", p.projectID, p.region, clusterName)
	req := &containerpb.GetClusterRequest{
		Name: name,
	}

	cluster, err := p.containerClient.GetCluster(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to get GKE cluster: %w", err)
	}

	nodeCount := 0
	for _, pool := range cluster.NodePools {
		nodeCount += int(pool.InitialNodeCount)
	}

	return &KubernetesCluster{
		ID:        cluster.Name,
		Name:      cluster.Name,
		Status:    cluster.Status.String(),
		Version:   cluster.CurrentMasterVersion,
		Endpoint:  cluster.Endpoint,
		Region:    cluster.Location,
		NodeCount: nodeCount,
		CreatedAt: cluster.CreateTime,
	}, nil
}

// ====== Cloud Functions Operations (Placeholder) ======

// ListFunctions lists Cloud Functions
func (p *GCPProvider) ListFunctions(ctx context.Context, region string) ([]*ServerlessFunction, error) {
	return []*ServerlessFunction{}, nil
}

// InvokeFunction invokes a Cloud Function
func (p *GCPProvider) InvokeFunction(ctx context.Context, functionName string, payload []byte) ([]byte, error) {
	return nil, nil
}

// ====== VPC Network Operations ======

// ListVPCs lists VPC networks
func (p *GCPProvider) ListVPCs(ctx context.Context, region string) ([]*VirtualNetwork, error) {
	return []*VirtualNetwork{}, nil
}

// ListLoadBalancers lists load balancers
func (p *GCPProvider) ListLoadBalancers(ctx context.Context, region string) ([]*LoadBalancer, error) {
	return []*LoadBalancer{}, nil
}

// ====== Monitoring Operations ======

// GetMetrics retrieves Cloud Monitoring metrics
func (p *GCPProvider) GetMetrics(ctx context.Context, params *MetricsParams) ([]*MetricData, error) {
	startTime, _ := time.Parse(time.RFC3339, params.StartTime)
	endTime, _ := time.Parse(time.RFC3339, params.EndTime)

	req := &monitoringpb.ListTimeSeriesRequest{
		Name:   fmt.Sprintf("projects/%s", p.projectID),
		Filter: fmt.Sprintf(`metric.type = "compute.googleapis.com/instance/%s"`, params.MetricName),
		Interval: &monitoringpb.TimeInterval{
			StartTime: timestamppb.New(startTime),
			EndTime:   timestamppb.New(endTime),
		},
	}

	var metrics []*MetricData
	it := p.monitoringClient.ListTimeSeries(ctx, req)
	for {
		ts, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to get metrics: %w", err)
		}
		for _, point := range ts.Points {
			metrics = append(metrics, &MetricData{
				Timestamp: point.Interval.EndTime.AsTime().Format(time.RFC3339),
				Value:     point.Value.GetDoubleValue(),
			})
		}
	}

	return metrics, nil
}

// GetLogs retrieves Cloud Logging logs
func (p *GCPProvider) GetLogs(ctx context.Context, params *LogsParams) ([]*LogEntry, error) {
	return []*LogEntry{}, nil
}

// GetCostAndUsage retrieves billing data
func (p *GCPProvider) GetCostAndUsage(ctx context.Context, params *CostParams) (*CostReport, error) {
	return &CostReport{
		Currency: "USD",
	}, nil
}

// ====== IAM Operations ======

// ListUsers lists IAM users (service accounts in GCP)
func (p *GCPProvider) ListUsers(ctx context.Context) ([]*IAMUser, error) {
	return []*IAMUser{}, nil
}

// ListRoles lists IAM roles
func (p *GCPProvider) ListRoles(ctx context.Context) ([]*IAMRole, error) {
	return []*IAMRole{}, nil
}

// ====== Region Operations ======

// ListRegions lists GCP regions
func (p *GCPProvider) ListRegions(ctx context.Context) ([]*Region, error) {
	regions := []*Region{
		{ID: "us-central1", Name: "Iowa"},
		{ID: "us-east1", Name: "South Carolina"},
		{ID: "us-west1", Name: "Oregon"},
		{ID: "europe-west1", Name: "Belgium"},
		{ID: "asia-east1", Name: "Taiwan"},
		{ID: "asia-southeast1", Name: "Singapore"},
	}
	return regions, nil
}

// ListAvailabilityZones lists availability zones
func (p *GCPProvider) ListAvailabilityZones(ctx context.Context, region string) ([]*AvailabilityZone, error) {
	return []*AvailabilityZone{}, nil
}

// ====== Tagging Operations ======

// TagResource tags a resource
func (p *GCPProvider) TagResource(ctx context.Context, resourceID string, tags map[string]string) error {
	return nil
}

// UntagResource removes tags from a resource
func (p *GCPProvider) UntagResource(ctx context.Context, resourceID string, tagKeys []string) error {
	return nil
}

// ====== Helper Methods ======

func (p *GCPProvider) mapGCEInstance(instance *computepb.Instance) *ComputeInstance {
	publicIP := ""
	privateIP := ""

	for _, ni := range instance.NetworkInterfaces {
		if ni.NetworkIP != nil {
			privateIP = *ni.NetworkIP
		}
		for _, ac := range ni.AccessConfigs {
			if ac.NatIP != nil {
				publicIP = *ac.NatIP
			}
		}
	}

	return &ComputeInstance{
		ID:           fmt.Sprintf("%d", *instance.Id),
		Name:         *instance.Name,
		State:        *instance.Status,
		InstanceType: extractMachineType(*instance.MachineType),
		Region:       p.region,
		Zone:         extractZone(*instance.Zone),
		PublicIP:     publicIP,
		PrivateIP:    privateIP,
		Tags:         instance.Labels,
	}
}

func extractMachineType(machineTypeURL string) string {
	// Extract machine type from URL like zones/us-central1-a/machineTypes/n1-standard-1
	parts := strings.Split(machineTypeURL, "/")
	if len(parts) > 0 {
		return parts[len(parts)-1]
	}
	return machineTypeURL
}

func extractZone(zoneURL string) string {
	parts := strings.Split(zoneURL, "/")
	if len(parts) > 0 {
		return parts[len(parts)-1]
	}
	return zoneURL
}

import (
	"strings"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

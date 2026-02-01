package cloud

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	cloudwatchtypes "github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/ecs"
	"github.com/aws/aws-sdk-go-v2/service/eks"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
	"github.com/aws/aws-sdk-go-v2/service/rds"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/vide/cloud-manager-backend/internal/models"
	"go.uber.org/zap"
)

// AWSProvider implements CloudProvider for AWS
type AWSProvider struct {
	config      aws.Config
	accessKeyID string
	secretKey   string
	region      string
	logger      *zap.Logger

	// AWS Service Clients
	ec2Client        *ec2.Client
	s3Client         *s3.Client
	rdsClient        *rds.Client
	lambdaClient     *lambda.Client
	ecsClient        *ecs.Client
	eksClient        *eks.Client
	cloudwatchClient *cloudwatch.Client
	iamClient        *iam.Client
}

// NewAWSProvider creates a new AWS provider
func NewAWSProvider(accessKeyID, secretKey, region string, logger *zap.Logger) *AWSProvider {
	return &AWSProvider{
		accessKeyID: accessKeyID,
		secretKey:   secretKey,
		region:      region,
		logger:      logger,
	}
}

// Connect establishes connection to AWS
func (p *AWSProvider) Connect(ctx context.Context) error {
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(p.region),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			p.accessKeyID,
			p.secretKey,
			"",
		)),
	)
	if err != nil {
		return fmt.Errorf("failed to load AWS config: %w", err)
	}

	p.config = cfg
	p.ec2Client = ec2.NewFromConfig(cfg)
	p.s3Client = s3.NewFromConfig(cfg)
	p.rdsClient = rds.NewFromConfig(cfg)
	p.lambdaClient = lambda.NewFromConfig(cfg)
	p.ecsClient = ecs.NewFromConfig(cfg)
	p.eksClient = eks.NewFromConfig(cfg)
	p.cloudwatchClient = cloudwatch.NewFromConfig(cfg)
	p.iamClient = iam.NewFromConfig(cfg)

	p.logger.Info("Connected to AWS",
		zap.String("region", p.region),
	)

	return nil
}

// Disconnect closes AWS connections
func (p *AWSProvider) Disconnect() error {
	p.logger.Info("Disconnected from AWS")
	return nil
}

// HealthCheck verifies AWS connectivity
func (p *AWSProvider) HealthCheck(ctx context.Context) error {
	_, err := p.ec2Client.DescribeRegions(ctx, &ec2.DescribeRegionsInput{})
	return err
}

// GetProviderType returns the provider type
func (p *AWSProvider) GetProviderType() models.ProviderType {
	return models.ProviderAWS
}

// ====== EC2 Instance Operations ======

// ListInstances lists EC2 instances
func (p *AWSProvider) ListInstances(ctx context.Context, region string) ([]*ComputeInstance, error) {
	input := &ec2.DescribeInstancesInput{}

	result, err := p.ec2Client.DescribeInstances(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to describe instances: %w", err)
	}

	var instances []*ComputeInstance
	for _, reservation := range result.Reservations {
		for _, instance := range reservation.Instances {
			instances = append(instances, p.mapEC2Instance(&instance))
		}
	}

	return instances, nil
}

// GetInstance retrieves a specific EC2 instance
func (p *AWSProvider) GetInstance(ctx context.Context, instanceID string) (*ComputeInstance, error) {
	input := &ec2.DescribeInstancesInput{
		InstanceIds: []string{instanceID},
	}

	result, err := p.ec2Client.DescribeInstances(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to describe instance: %w", err)
	}

	if len(result.Reservations) == 0 || len(result.Reservations[0].Instances) == 0 {
		return nil, fmt.Errorf("instance not found: %s", instanceID)
	}

	return p.mapEC2Instance(&result.Reservations[0].Instances[0]), nil
}

// StartInstance starts an EC2 instance
func (p *AWSProvider) StartInstance(ctx context.Context, instanceID string) error {
	input := &ec2.StartInstancesInput{
		InstanceIds: []string{instanceID},
	}

	_, err := p.ec2Client.StartInstances(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to start instance: %w", err)
	}

	p.logger.Info("Started EC2 instance", zap.String("instance_id", instanceID))
	return nil
}

// StopInstance stops an EC2 instance
func (p *AWSProvider) StopInstance(ctx context.Context, instanceID string) error {
	input := &ec2.StopInstancesInput{
		InstanceIds: []string{instanceID},
	}

	_, err := p.ec2Client.StopInstances(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to stop instance: %w", err)
	}

	p.logger.Info("Stopped EC2 instance", zap.String("instance_id", instanceID))
	return nil
}

// RebootInstance reboots an EC2 instance
func (p *AWSProvider) RebootInstance(ctx context.Context, instanceID string) error {
	input := &ec2.RebootInstancesInput{
		InstanceIds: []string{instanceID},
	}

	_, err := p.ec2Client.RebootInstances(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to reboot instance: %w", err)
	}

	p.logger.Info("Rebooted EC2 instance", zap.String("instance_id", instanceID))
	return nil
}

// TerminateInstance terminates an EC2 instance
func (p *AWSProvider) TerminateInstance(ctx context.Context, instanceID string) error {
	input := &ec2.TerminateInstancesInput{
		InstanceIds: []string{instanceID},
	}

	_, err := p.ec2Client.TerminateInstances(ctx, input)
	if err != nil {
		return fmt.Errorf("failed to terminate instance: %w", err)
	}

	p.logger.Info("Terminated EC2 instance", zap.String("instance_id", instanceID))
	return nil
}

// CreateInstance creates a new EC2 instance
func (p *AWSProvider) CreateInstance(ctx context.Context, params *CreateInstanceParams) (*ComputeInstance, error) {
	input := &ec2.RunInstancesInput{
		ImageId:      aws.String(params.ImageID),
		InstanceType: ec2types.InstanceType(params.InstanceType),
		MinCount:     aws.Int32(1),
		MaxCount:     aws.Int32(1),
		KeyName:      aws.String(params.KeyName),
	}

	if params.SubnetID != "" {
		input.SubnetId = aws.String(params.SubnetID)
	}

	if len(params.SecurityGroups) > 0 {
		input.SecurityGroupIds = params.SecurityGroups
	}

	if len(params.Tags) > 0 {
		var tags []ec2types.Tag
		for k, v := range params.Tags {
			tags = append(tags, ec2types.Tag{
				Key:   aws.String(k),
				Value: aws.String(v),
			})
		}
		input.TagSpecifications = []ec2types.TagSpecification{
			{
				ResourceType: ec2types.ResourceTypeInstance,
				Tags:         tags,
			},
		}
	}

	result, err := p.ec2Client.RunInstances(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to create instance: %w", err)
	}

	if len(result.Instances) == 0 {
		return nil, fmt.Errorf("no instance created")
	}

	p.logger.Info("Created EC2 instance", zap.String("instance_id", *result.Instances[0].InstanceId))
	return p.mapEC2Instance(&result.Instances[0]), nil
}

// ====== S3 Storage Operations ======

// ListBuckets lists S3 buckets
func (p *AWSProvider) ListBuckets(ctx context.Context) ([]*StorageBucket, error) {
	result, err := p.s3Client.ListBuckets(ctx, &s3.ListBucketsInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to list buckets: %w", err)
	}

	var buckets []*StorageBucket
	for _, bucket := range result.Buckets {
		buckets = append(buckets, &StorageBucket{
			Name:         aws.ToString(bucket.Name),
			CreationDate: bucket.CreationDate.Format(time.RFC3339),
		})
	}

	return buckets, nil
}

// CreateBucket creates an S3 bucket
func (p *AWSProvider) CreateBucket(ctx context.Context, params *CreateBucketParams) (*StorageBucket, error) {
	input := &s3.CreateBucketInput{
		Bucket: aws.String(params.Name),
	}

	if p.region != "us-east-1" {
		input.CreateBucketConfiguration = &s3types.CreateBucketConfiguration{
			LocationConstraint: s3types.BucketLocationConstraint(p.region),
		}
	}

	_, err := p.s3Client.CreateBucket(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to create bucket: %w", err)
	}

	if params.Versioning {
		_, err = p.s3Client.PutBucketVersioning(ctx, &s3.PutBucketVersioningInput{
			Bucket: aws.String(params.Name),
			VersioningConfiguration: &s3types.VersioningConfiguration{
				Status: s3types.BucketVersioningStatusEnabled,
			},
		})
		if err != nil {
			p.logger.Warn("Failed to enable versioning", zap.Error(err))
		}
	}

	p.logger.Info("Created S3 bucket", zap.String("bucket", params.Name))
	return &StorageBucket{
		Name:       params.Name,
		Region:     p.region,
		Versioning: params.Versioning,
	}, nil
}

// DeleteBucket deletes an S3 bucket
func (p *AWSProvider) DeleteBucket(ctx context.Context, bucketName string) error {
	_, err := p.s3Client.DeleteBucket(ctx, &s3.DeleteBucketInput{
		Bucket: aws.String(bucketName),
	})
	if err != nil {
		return fmt.Errorf("failed to delete bucket: %w", err)
	}

	p.logger.Info("Deleted S3 bucket", zap.String("bucket", bucketName))
	return nil
}

// ListObjects lists objects in an S3 bucket
func (p *AWSProvider) ListObjects(ctx context.Context, bucketName, prefix string, maxKeys int) ([]*StorageObject, error) {
	input := &s3.ListObjectsV2Input{
		Bucket:  aws.String(bucketName),
		MaxKeys: aws.Int32(int32(maxKeys)),
	}

	if prefix != "" {
		input.Prefix = aws.String(prefix)
	}

	result, err := p.s3Client.ListObjectsV2(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to list objects: %w", err)
	}

	var objects []*StorageObject
	for _, obj := range result.Contents {
		objects = append(objects, &StorageObject{
			Key:          aws.ToString(obj.Key),
			Size:         aws.ToInt64(obj.Size),
			LastModified: obj.LastModified.Format(time.RFC3339),
			ETag:         aws.ToString(obj.ETag),
			StorageClass: string(obj.StorageClass),
		})
	}

	return objects, nil
}

// ====== RDS Database Operations ======

// ListDatabases lists RDS instances
func (p *AWSProvider) ListDatabases(ctx context.Context, region string) ([]*DatabaseInstance, error) {
	result, err := p.rdsClient.DescribeDBInstances(ctx, &rds.DescribeDBInstancesInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to describe DB instances: %w", err)
	}

	var databases []*DatabaseInstance
	for _, db := range result.DBInstances {
		databases = append(databases, p.mapRDSInstance(&db))
	}

	return databases, nil
}

// GetDatabase retrieves a specific RDS instance
func (p *AWSProvider) GetDatabase(ctx context.Context, instanceID string) (*DatabaseInstance, error) {
	result, err := p.rdsClient.DescribeDBInstances(ctx, &rds.DescribeDBInstancesInput{
		DBInstanceIdentifier: aws.String(instanceID),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to describe DB instance: %w", err)
	}

	if len(result.DBInstances) == 0 {
		return nil, fmt.Errorf("database not found: %s", instanceID)
	}

	return p.mapRDSInstance(&result.DBInstances[0]), nil
}

// StartDatabase starts an RDS instance
func (p *AWSProvider) StartDatabase(ctx context.Context, instanceID string) error {
	_, err := p.rdsClient.StartDBInstance(ctx, &rds.StartDBInstanceInput{
		DBInstanceIdentifier: aws.String(instanceID),
	})
	if err != nil {
		return fmt.Errorf("failed to start DB instance: %w", err)
	}

	p.logger.Info("Started RDS instance", zap.String("instance_id", instanceID))
	return nil
}

// StopDatabase stops an RDS instance
func (p *AWSProvider) StopDatabase(ctx context.Context, instanceID string) error {
	_, err := p.rdsClient.StopDBInstance(ctx, &rds.StopDBInstanceInput{
		DBInstanceIdentifier: aws.String(instanceID),
	})
	if err != nil {
		return fmt.Errorf("failed to stop DB instance: %w", err)
	}

	p.logger.Info("Stopped RDS instance", zap.String("instance_id", instanceID))
	return nil
}

// ====== EKS Kubernetes Operations ======

// ListClusters lists EKS clusters
func (p *AWSProvider) ListClusters(ctx context.Context, region string) ([]*KubernetesCluster, error) {
	result, err := p.eksClient.ListClusters(ctx, &eks.ListClustersInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to list EKS clusters: %w", err)
	}

	var clusters []*KubernetesCluster
	for _, clusterName := range result.Clusters {
		cluster, err := p.GetCluster(ctx, clusterName)
		if err != nil {
			p.logger.Warn("Failed to get cluster details", zap.String("cluster", clusterName), zap.Error(err))
			continue
		}
		clusters = append(clusters, cluster)
	}

	return clusters, nil
}

// GetCluster retrieves a specific EKS cluster
func (p *AWSProvider) GetCluster(ctx context.Context, clusterName string) (*KubernetesCluster, error) {
	result, err := p.eksClient.DescribeCluster(ctx, &eks.DescribeClusterInput{
		Name: aws.String(clusterName),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to describe EKS cluster: %w", err)
	}

	cluster := result.Cluster
	return &KubernetesCluster{
		ID:        aws.ToString(cluster.Arn),
		Name:      aws.ToString(cluster.Name),
		Status:    string(cluster.Status),
		Version:   aws.ToString(cluster.Version),
		Endpoint:  aws.ToString(cluster.Endpoint),
		Region:    p.region,
		CreatedAt: cluster.CreatedAt.Format(time.RFC3339),
	}, nil
}

// ====== Lambda Serverless Operations ======

// ListFunctions lists Lambda functions
func (p *AWSProvider) ListFunctions(ctx context.Context, region string) ([]*ServerlessFunction, error) {
	result, err := p.lambdaClient.ListFunctions(ctx, &lambda.ListFunctionsInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to list Lambda functions: %w", err)
	}

	var functions []*ServerlessFunction
	for _, fn := range result.Functions {
		functions = append(functions, &ServerlessFunction{
			Name:         aws.ToString(fn.FunctionName),
			Runtime:      string(fn.Runtime),
			Handler:      aws.ToString(fn.Handler),
			MemorySize:   int(aws.ToInt32(fn.MemorySize)),
			Timeout:      int(aws.ToInt32(fn.Timeout)),
			CodeSize:     fn.CodeSize,
			LastModified: aws.ToString(fn.LastModified),
			Description:  aws.ToString(fn.Description),
		})
	}

	return functions, nil
}

// InvokeFunction invokes a Lambda function
func (p *AWSProvider) InvokeFunction(ctx context.Context, functionName string, payload []byte) ([]byte, error) {
	result, err := p.lambdaClient.Invoke(ctx, &lambda.InvokeInput{
		FunctionName: aws.String(functionName),
		Payload:      payload,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to invoke Lambda function: %w", err)
	}

	return result.Payload, nil
}

// ====== VPC Network Operations ======

// ListVPCs lists VPCs
func (p *AWSProvider) ListVPCs(ctx context.Context, region string) ([]*VirtualNetwork, error) {
	result, err := p.ec2Client.DescribeVpcs(ctx, &ec2.DescribeVpcsInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to describe VPCs: %w", err)
	}

	var vpcs []*VirtualNetwork
	for _, vpc := range result.Vpcs {
		name := ""
		for _, tag := range vpc.Tags {
			if aws.ToString(tag.Key) == "Name" {
				name = aws.ToString(tag.Value)
				break
			}
		}

		vpcs = append(vpcs, &VirtualNetwork{
			ID:        aws.ToString(vpc.VpcId),
			Name:      name,
			CIDRBlock: aws.ToString(vpc.CidrBlock),
			State:     string(vpc.State),
			IsDefault: aws.ToBool(vpc.IsDefault),
		})
	}

	return vpcs, nil
}

// ListLoadBalancers lists Elastic Load Balancers
func (p *AWSProvider) ListLoadBalancers(ctx context.Context, region string) ([]*LoadBalancer, error) {
	// This would use ELBv2 client - simplified for brevity
	return []*LoadBalancer{}, nil
}

// ====== CloudWatch Monitoring Operations ======

// GetMetrics retrieves CloudWatch metrics
func (p *AWSProvider) GetMetrics(ctx context.Context, params *MetricsParams) ([]*MetricData, error) {
	startTime, _ := time.Parse(time.RFC3339, params.StartTime)
	endTime, _ := time.Parse(time.RFC3339, params.EndTime)

	input := &cloudwatch.GetMetricDataInput{
		StartTime: aws.Time(startTime),
		EndTime:   aws.Time(endTime),
		MetricDataQueries: []cloudwatchtypes.MetricDataQuery{
			{
				Id: aws.String("m1"),
				MetricStat: &cloudwatchtypes.MetricStat{
					Metric: &cloudwatchtypes.Metric{
						Namespace:  aws.String("AWS/EC2"),
						MetricName: aws.String(params.MetricName),
						Dimensions: []cloudwatchtypes.Dimension{
							{
								Name:  aws.String("InstanceId"),
								Value: aws.String(params.ResourceID),
							},
						},
					},
					Period: aws.Int32(int32(params.Period)),
					Stat:   aws.String(params.Statistics),
				},
			},
		},
	}

	result, err := p.cloudwatchClient.GetMetricData(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to get metrics: %w", err)
	}

	var metrics []*MetricData
	for _, metricResult := range result.MetricDataResults {
		for i, timestamp := range metricResult.Timestamps {
			metrics = append(metrics, &MetricData{
				Timestamp: timestamp.Format(time.RFC3339),
				Value:     metricResult.Values[i],
			})
		}
	}

	return metrics, nil
}

// GetLogs retrieves CloudWatch logs (placeholder)
func (p *AWSProvider) GetLogs(ctx context.Context, params *LogsParams) ([]*LogEntry, error) {
	return []*LogEntry{}, nil
}

// GetCostAndUsage retrieves cost and usage data (placeholder)
func (p *AWSProvider) GetCostAndUsage(ctx context.Context, params *CostParams) (*CostReport, error) {
	return &CostReport{
		Currency: "USD",
	}, nil
}

// ====== IAM Operations ======

// ListUsers lists IAM users
func (p *AWSProvider) ListUsers(ctx context.Context) ([]*IAMUser, error) {
	result, err := p.iamClient.ListUsers(ctx, &iam.ListUsersInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to list IAM users: %w", err)
	}

	var users []*IAMUser
	for _, user := range result.Users {
		users = append(users, &IAMUser{
			ID:         aws.ToString(user.UserId),
			Name:       aws.ToString(user.UserName),
			ARN:        aws.ToString(user.Arn),
			CreateDate: user.CreateDate.Format(time.RFC3339),
		})
	}

	return users, nil
}

// ListRoles lists IAM roles
func (p *AWSProvider) ListRoles(ctx context.Context) ([]*IAMRole, error) {
	result, err := p.iamClient.ListRoles(ctx, &iam.ListRolesInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to list IAM roles: %w", err)
	}

	var roles []*IAMRole
	for _, role := range result.Roles {
		roles = append(roles, &IAMRole{
			ID:         aws.ToString(role.RoleId),
			Name:       aws.ToString(role.RoleName),
			ARN:        aws.ToString(role.Arn),
			CreateDate: role.CreateDate.Format(time.RFC3339),
		})
	}

	return roles, nil
}

// ====== Region Operations ======

// ListRegions lists AWS regions
func (p *AWSProvider) ListRegions(ctx context.Context) ([]*Region, error) {
	result, err := p.ec2Client.DescribeRegions(ctx, &ec2.DescribeRegionsInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to describe regions: %w", err)
	}

	var regions []*Region
	for _, region := range result.Regions {
		regions = append(regions, &Region{
			ID:       aws.ToString(region.RegionName),
			Name:     aws.ToString(region.RegionName),
			Endpoint: aws.ToString(region.Endpoint),
		})
	}

	return regions, nil
}

// ListAvailabilityZones lists availability zones
func (p *AWSProvider) ListAvailabilityZones(ctx context.Context, region string) ([]*AvailabilityZone, error) {
	result, err := p.ec2Client.DescribeAvailabilityZones(ctx, &ec2.DescribeAvailabilityZonesInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to describe availability zones: %w", err)
	}

	var zones []*AvailabilityZone
	for _, zone := range result.AvailabilityZones {
		zones = append(zones, &AvailabilityZone{
			ID:     aws.ToString(zone.ZoneId),
			Name:   aws.ToString(zone.ZoneName),
			State:  string(zone.State),
			Region: aws.ToString(zone.RegionName),
		})
	}

	return zones, nil
}

// ====== Tagging Operations ======

// TagResource tags a resource
func (p *AWSProvider) TagResource(ctx context.Context, resourceID string, tags map[string]string) error {
	var ec2Tags []ec2types.Tag
	for k, v := range tags {
		ec2Tags = append(ec2Tags, ec2types.Tag{
			Key:   aws.String(k),
			Value: aws.String(v),
		})
	}

	_, err := p.ec2Client.CreateTags(ctx, &ec2.CreateTagsInput{
		Resources: []string{resourceID},
		Tags:      ec2Tags,
	})
	if err != nil {
		return fmt.Errorf("failed to tag resource: %w", err)
	}

	return nil
}

// UntagResource removes tags from a resource
func (p *AWSProvider) UntagResource(ctx context.Context, resourceID string, tagKeys []string) error {
	var ec2Tags []ec2types.Tag
	for _, key := range tagKeys {
		ec2Tags = append(ec2Tags, ec2types.Tag{
			Key: aws.String(key),
		})
	}

	_, err := p.ec2Client.DeleteTags(ctx, &ec2.DeleteTagsInput{
		Resources: []string{resourceID},
		Tags:      ec2Tags,
	})
	if err != nil {
		return fmt.Errorf("failed to untag resource: %w", err)
	}

	return nil
}

// ====== Helper Methods ======

func (p *AWSProvider) mapEC2Instance(instance *ec2types.Instance) *ComputeInstance {
	name := ""
	tags := make(map[string]string)
	for _, tag := range instance.Tags {
		tags[aws.ToString(tag.Key)] = aws.ToString(tag.Value)
		if aws.ToString(tag.Key) == "Name" {
			name = aws.ToString(tag.Value)
		}
	}

	publicIP := ""
	if instance.PublicIpAddress != nil {
		publicIP = aws.ToString(instance.PublicIpAddress)
	}

	privateIP := ""
	if instance.PrivateIpAddress != nil {
		privateIP = aws.ToString(instance.PrivateIpAddress)
	}

	launchTime := ""
	if instance.LaunchTime != nil {
		launchTime = instance.LaunchTime.Format(time.RFC3339)
	}

	return &ComputeInstance{
		ID:           aws.ToString(instance.InstanceId),
		Name:         name,
		State:        string(instance.State.Name),
		InstanceType: string(instance.InstanceType),
		Region:       p.region,
		Zone:         aws.ToString(instance.Placement.AvailabilityZone),
		PublicIP:     publicIP,
		PrivateIP:    privateIP,
		Platform:     string(instance.Platform),
		LaunchTime:   launchTime,
		Tags:         tags,
	}
}

func (p *AWSProvider) mapRDSInstance(db *rdstypes.DBInstance) *DatabaseInstance {
	endpoint := ""
	port := 0
	if db.Endpoint != nil {
		endpoint = aws.ToString(db.Endpoint.Address)
		port = int(db.Endpoint.Port)
	}

	return &DatabaseInstance{
		ID:              aws.ToString(db.DBInstanceIdentifier),
		Name:            aws.ToString(db.DBInstanceIdentifier),
		Engine:          aws.ToString(db.Engine),
		EngineVersion:   aws.ToString(db.EngineVersion),
		InstanceClass:   aws.ToString(db.DBInstanceClass),
		Status:          aws.ToString(db.DBInstanceStatus),
		Endpoint:        endpoint,
		Port:            port,
		Region:          p.region,
		Zone:            aws.ToString(db.AvailabilityZone),
		StorageSize:     int64(aws.ToInt32(db.AllocatedStorage)),
		StorageType:     aws.ToString(db.StorageType),
		MultiAZ:         db.MultiAZ,
		BackupRetention: int(aws.ToInt32(db.BackupRetentionPeriod)),
	}
}

// Missing import for S3 types
import (
	s3types "github.com/aws/aws-sdk-go-v2/service/s3/types"
	rdstypes "github.com/aws/aws-sdk-go-v2/service/rds/types"
)

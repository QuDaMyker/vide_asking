module github.com/vide/cloud-manager-backend

go 1.22

require (
	// Web Framework
	github.com/gin-gonic/gin v1.9.1
	github.com/gin-contrib/cors v1.5.0
	
	// AWS SDK
	github.com/aws/aws-sdk-go-v2 v1.24.1
	github.com/aws/aws-sdk-go-v2/config v1.26.6
	github.com/aws/aws-sdk-go-v2/credentials v1.16.16
	github.com/aws/aws-sdk-go-v2/service/ec2 v1.144.0
	github.com/aws/aws-sdk-go-v2/service/s3 v1.48.1
	github.com/aws/aws-sdk-go-v2/service/rds v1.69.0
	github.com/aws/aws-sdk-go-v2/service/lambda v1.51.0
	github.com/aws/aws-sdk-go-v2/service/cloudwatch v1.35.0
	github.com/aws/aws-sdk-go-v2/service/iam v1.28.12
	github.com/aws/aws-sdk-go-v2/service/ecs v1.38.0
	github.com/aws/aws-sdk-go-v2/service/eks v1.38.0
	
	// Google Cloud SDK
	cloud.google.com/go/compute v1.23.3
	cloud.google.com/go/storage v1.36.0
	cloud.google.com/go/container v1.29.0
	cloud.google.com/go/monitoring v1.17.0
	cloud.google.com/go/logging v1.9.0
	cloud.google.com/go/iam v1.1.5
	google.golang.org/api v0.157.0
	
	// Azure SDK
	github.com/Azure/azure-sdk-for-go/sdk/azidentity v1.5.1
	github.com/Azure/azure-sdk-for-go/sdk/azcore v1.9.1
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/compute/armcompute v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/storage/armstorage v1.5.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/network/armnetwork v1.1.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice v1.0.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/monitor/armmonitor v0.11.0
	
	// Database
	github.com/jackc/pgx/v5 v5.5.2
	github.com/golang-migrate/migrate/v4 v4.17.0
	
	// Dependency Injection
	go.uber.org/fx v1.20.1
	go.uber.org/dig v1.17.1
	
	// Logging
	go.uber.org/zap v1.26.0
	
	// Configuration
	github.com/spf13/viper v1.18.2
	
	// Notifications
	github.com/go-telegram-bot-api/telegram-bot-api/v5 v5.5.1
	github.com/slack-go/slack v0.12.3
	github.com/wneessen/go-mail v0.4.1
	
	// Utilities
	github.com/google/uuid v1.5.0
	github.com/golang-jwt/jwt/v5 v5.2.0
	golang.org/x/crypto v0.18.0
	
	// Validation
	github.com/go-playground/validator/v10 v10.17.0
	
	// Swagger
	github.com/swaggo/swag v1.16.2
	github.com/swaggo/gin-swagger v1.6.0
	github.com/swaggo/files v1.0.1
	
	// Testing
	github.com/stretchr/testify v1.8.4
	github.com/golang/mock v1.6.0
)

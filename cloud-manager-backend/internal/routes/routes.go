package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/vide/cloud-manager-backend/internal/handlers"
	"github.com/vide/cloud-manager-backend/internal/middleware"
	"go.uber.org/zap"
)

// Router sets up all API routes
type Router struct {
	engine             *gin.Engine
	authMiddleware     *middleware.AuthMiddleware
	loggingMiddleware  *middleware.LoggingMiddleware
	rateLimiter        *middleware.RateLimiter
	authHandler        *handlers.AuthHandler
	providerHandler    *handlers.CloudProviderHandler
	computeHandler     *handlers.ComputeHandler
	storageHandler     *handlers.StorageHandler
	databaseHandler    *handlers.DatabaseHandler
	kubernetesHandler  *handlers.KubernetesHandler
	alertHandler       *handlers.AlertHandler
	monitoringHandler  *handlers.MonitoringHandler
	logger             *zap.Logger
}

// NewRouter creates a new Router
func NewRouter(
	authMiddleware *middleware.AuthMiddleware,
	loggingMiddleware *middleware.LoggingMiddleware,
	rateLimiter *middleware.RateLimiter,
	authHandler *handlers.AuthHandler,
	providerHandler *handlers.CloudProviderHandler,
	computeHandler *handlers.ComputeHandler,
	storageHandler *handlers.StorageHandler,
	databaseHandler *handlers.DatabaseHandler,
	kubernetesHandler *handlers.KubernetesHandler,
	alertHandler *handlers.AlertHandler,
	monitoringHandler *handlers.MonitoringHandler,
	logger *zap.Logger,
) *Router {
	return &Router{
		authMiddleware:     authMiddleware,
		loggingMiddleware:  loggingMiddleware,
		rateLimiter:        rateLimiter,
		authHandler:        authHandler,
		providerHandler:    providerHandler,
		computeHandler:     computeHandler,
		storageHandler:     storageHandler,
		databaseHandler:    databaseHandler,
		kubernetesHandler:  kubernetesHandler,
		alertHandler:       alertHandler,
		monitoringHandler:  monitoringHandler,
		logger:             logger,
	}
}

// Setup sets up the gin engine with all routes
func (r *Router) Setup() *gin.Engine {
	r.engine = gin.New()

	// Global middleware
	r.engine.Use(middleware.RecoveryMiddleware(r.logger))
	r.engine.Use(r.loggingMiddleware.Logger())
	r.engine.Use(r.rateLimiter.Limit())
	r.engine.Use(middleware.CORSMiddleware(&middleware.CORSConfig{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Request-ID"},
		ExposeHeaders:    []string{"Content-Length", "X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           86400,
	}))

	// Health check
	r.engine.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API v1
	v1 := r.engine.Group("/api/v1")
	{
		// Auth routes (public)
		auth := v1.Group("/auth")
		{
			auth.POST("/register", r.authHandler.Register)
			auth.POST("/login", r.authHandler.Login)
			auth.POST("/refresh", r.authHandler.RefreshToken)
		}

		// Protected routes
		protected := v1.Group("")
		protected.Use(r.authMiddleware.RequireAuth())
		{
			// Auth (protected)
			protected.POST("/auth/logout", r.authHandler.Logout)
			protected.GET("/auth/profile", r.authHandler.GetProfile)
			protected.PUT("/auth/password", r.authHandler.ChangePassword)

			// Cloud Providers
			providers := protected.Group("/providers")
			{
				providers.GET("", r.providerHandler.ListProviders)
				providers.POST("", r.providerHandler.CreateProvider)
				providers.GET("/:id", r.providerHandler.GetProvider)
				providers.PUT("/:id", r.providerHandler.UpdateProvider)
				providers.DELETE("/:id", r.providerHandler.DeleteProvider)
				providers.POST("/:id/test", r.providerHandler.TestConnection)
				providers.POST("/:id/sync", r.providerHandler.SyncResources)
				providers.GET("/:id/stats", r.providerHandler.GetProviderStats)
				providers.GET("/regions/:type", r.providerHandler.ListRegions)
			}

			// Compute Instances
			compute := protected.Group("/compute")
			{
				compute.GET("/instances", r.computeHandler.ListInstances)
				compute.POST("/instances", r.computeHandler.CreateInstance)
				compute.GET("/instances/:id", r.computeHandler.GetInstance)
				compute.POST("/instances/:id/start", r.computeHandler.StartInstance)
				compute.POST("/instances/:id/stop", r.computeHandler.StopInstance)
				compute.POST("/instances/:id/reboot", r.computeHandler.RebootInstance)
				compute.DELETE("/instances/:id", r.computeHandler.TerminateInstance)
				compute.GET("/instances/:id/metrics", r.computeHandler.GetInstanceMetrics)
			}

			// Storage
			storage := protected.Group("/storage")
			{
				storage.GET("/buckets", r.storageHandler.ListBuckets)
				storage.POST("/buckets", r.storageHandler.CreateBucket)
				storage.GET("/buckets/:name", r.storageHandler.GetBucket)
				storage.DELETE("/buckets/:name", r.storageHandler.DeleteBucket)
				storage.GET("/buckets/:name/objects", r.storageHandler.ListObjects)
				storage.POST("/buckets/:name/objects", r.storageHandler.UploadObject)
				storage.GET("/buckets/:name/objects/*key", r.storageHandler.DownloadObject)
				storage.DELETE("/buckets/:name/objects/*key", r.storageHandler.DeleteObject)
				storage.GET("/buckets/:name/presigned", r.storageHandler.GetPresignedURL)
			}

			// Databases
			databases := protected.Group("/databases")
			{
				databases.GET("", r.databaseHandler.ListDatabases)
				databases.POST("", r.databaseHandler.CreateDatabase)
				databases.GET("/:id", r.databaseHandler.GetDatabase)
				databases.DELETE("/:id", r.databaseHandler.DeleteDatabase)
				databases.POST("/:id/start", r.databaseHandler.StartDatabase)
				databases.POST("/:id/stop", r.databaseHandler.StopDatabase)
				databases.POST("/:id/snapshot", r.databaseHandler.CreateSnapshot)
				databases.POST("/:id/restore", r.databaseHandler.RestoreSnapshot)
			}

			// Kubernetes
			kubernetes := protected.Group("/kubernetes")
			{
				kubernetes.GET("/clusters", r.kubernetesHandler.ListClusters)
				kubernetes.POST("/clusters", r.kubernetesHandler.CreateCluster)
				kubernetes.GET("/clusters/:id", r.kubernetesHandler.GetCluster)
				kubernetes.DELETE("/clusters/:id", r.kubernetesHandler.DeleteCluster)
				kubernetes.GET("/clusters/:id/nodes", r.kubernetesHandler.GetClusterNodes)
				kubernetes.POST("/clusters/:id/scale", r.kubernetesHandler.ScaleCluster)
				kubernetes.POST("/clusters/:id/upgrade", r.kubernetesHandler.UpgradeCluster)
				kubernetes.GET("/clusters/:id/kubeconfig", r.kubernetesHandler.GetKubeconfig)
				kubernetes.GET("/clusters/:id/node-pools", r.kubernetesHandler.ListNodePools)
				kubernetes.POST("/clusters/:id/node-pools", r.kubernetesHandler.CreateNodePool)
				kubernetes.DELETE("/clusters/:id/node-pools/:poolId", r.kubernetesHandler.DeleteNodePool)
			}

			// Alerts
			alerts := protected.Group("/alerts")
			{
				alerts.GET("", r.alertHandler.ListAlerts)
				alerts.POST("", r.alertHandler.CreateAlert)
				alerts.GET("/:id", r.alertHandler.GetAlert)
				alerts.PUT("/:id", r.alertHandler.UpdateAlert)
				alerts.DELETE("/:id", r.alertHandler.DeleteAlert)
				alerts.POST("/:id/enable", r.alertHandler.EnableAlert)
				alerts.POST("/:id/disable", r.alertHandler.DisableAlert)
				alerts.GET("/:id/history", r.alertHandler.GetAlertHistory)
				alerts.POST("/:id/test", r.alertHandler.TestAlert)
			}

			// Monitoring
			monitoring := protected.Group("/monitoring")
			{
				monitoring.GET("/metrics", r.monitoringHandler.GetMetrics)
				monitoring.GET("/dashboard", r.monitoringHandler.GetDashboardStats)
				monitoring.GET("/costs", r.monitoringHandler.GetCostAnalysis)
				monitoring.GET("/health", r.monitoringHandler.GetResourceHealth)
				monitoring.GET("/audit-logs", r.monitoringHandler.GetAuditLogs)
				monitoring.GET("/alerts-summary", r.monitoringHandler.GetAlertsSummary)
				monitoring.GET("/export", r.monitoringHandler.ExportMetrics)
			}
		}

		// Admin routes
		admin := v1.Group("/admin")
		admin.Use(r.authMiddleware.RequireAuth())
		admin.Use(r.authMiddleware.RequireRole("admin"))
		{
			// Admin-specific endpoints can be added here
		}
	}

	return r.engine
}

// GetEngine returns the gin engine
func (r *Router) GetEngine() *gin.Engine {
	return r.engine
}

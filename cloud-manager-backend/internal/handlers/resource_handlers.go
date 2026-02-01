package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/service"
	"go.uber.org/zap"
)

// StorageHandler handles storage bucket endpoints
type StorageHandler struct {
	storageService *service.StorageService
	logger         *zap.Logger
}

// NewStorageHandler creates a new StorageHandler
func NewStorageHandler(storageService *service.StorageService, logger *zap.Logger) *StorageHandler {
	return &StorageHandler{
		storageService: storageService,
		logger:         logger,
	}
}

// CreateBucketRequest represents request to create a bucket
type CreateBucketRequest struct {
	Name       string `json:"name" binding:"required"`
	Region     string `json:"region" binding:"required"`
	Versioning bool   `json:"versioning"`
	Encryption string `json:"encryption"`
}

// ListBuckets lists storage buckets
// @Summary List storage buckets
// @Description Get all storage buckets for a provider
// @Tags storage
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Success 200 {array} cloud.StorageBucket
// @Failure 400 {object} ErrorResponse
// @Router /storage/buckets [get]
func (h *StorageHandler) ListBuckets(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	buckets, err := h.storageService.ListBuckets(c.Request.Context(), providerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, buckets)
}

// CreateBucket creates a storage bucket
// @Summary Create storage bucket
// @Description Create a new storage bucket
// @Tags storage
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param request body CreateBucketRequest true "Bucket configuration"
// @Success 201 {object} cloud.StorageBucket
// @Failure 400 {object} ErrorResponse
// @Router /storage/buckets [post]
func (h *StorageHandler) CreateBucket(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	var req CreateBucketRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	bucket, err := h.storageService.CreateBucket(c.Request.Context(), providerID, req.Name, req.Region, req.Versioning)
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusCreated, bucket)
}

// DeleteBucket deletes a storage bucket
// @Summary Delete storage bucket
// @Description Delete a storage bucket
// @Tags storage
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param bucket_name path string true "Bucket name"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /storage/buckets/{bucket_name} [delete]
func (h *StorageHandler) DeleteBucket(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	bucketName := c.Param("bucket_name")

	if err := h.storageService.DeleteBucket(c.Request.Context(), providerID, bucketName); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Bucket deleted successfully"})
}

// ListObjects lists objects in a bucket
// @Summary List bucket objects
// @Description Get objects in a storage bucket
// @Tags storage
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param bucket_name path string true "Bucket name"
// @Param prefix query string false "Object prefix"
// @Param max_keys query int false "Maximum number of objects"
// @Success 200 {array} cloud.StorageObject
// @Failure 400 {object} ErrorResponse
// @Router /storage/buckets/{bucket_name}/objects [get]
func (h *StorageHandler) ListObjects(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	bucketName := c.Param("bucket_name")
	prefix := c.Query("prefix")
	maxKeys := 1000 // Default

	objects, err := h.storageService.ListObjects(c.Request.Context(), providerID, bucketName, prefix, maxKeys)
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, objects)
}

// DatabaseHandler handles database endpoints
type DatabaseHandler struct {
	databaseService *service.DatabaseService
	logger          *zap.Logger
}

// NewDatabaseHandler creates a new DatabaseHandler
func NewDatabaseHandler(databaseService *service.DatabaseService, logger *zap.Logger) *DatabaseHandler {
	return &DatabaseHandler{
		databaseService: databaseService,
		logger:          logger,
	}
}

// ListDatabases lists database instances
// @Summary List databases
// @Description Get all database instances for a provider
// @Tags databases
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param region query string false "Region filter"
// @Success 200 {array} cloud.DatabaseInstance
// @Failure 400 {object} ErrorResponse
// @Router /databases [get]
func (h *DatabaseHandler) ListDatabases(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	region := c.Query("region")

	databases, err := h.databaseService.ListDatabases(c.Request.Context(), providerID, region)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, databases)
}

// GetDatabase gets a specific database
// @Summary Get database
// @Description Get details of a specific database instance
// @Tags databases
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} cloud.DatabaseInstance
// @Failure 404 {object} ErrorResponse
// @Router /databases/{instance_id} [get]
func (h *DatabaseHandler) GetDatabase(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	database, err := h.databaseService.GetDatabase(c.Request.Context(), providerID, instanceID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, database)
}

// StartDatabase starts a database instance
// @Summary Start database
// @Description Start a stopped database instance
// @Tags databases
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /databases/{instance_id}/start [post]
func (h *DatabaseHandler) StartDatabase(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	if err := h.databaseService.StartDatabase(c.Request.Context(), providerID, instanceID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Database starting"})
}

// StopDatabase stops a database instance
// @Summary Stop database
// @Description Stop a running database instance
// @Tags databases
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /databases/{instance_id}/stop [post]
func (h *DatabaseHandler) StopDatabase(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	if err := h.databaseService.StopDatabase(c.Request.Context(), providerID, instanceID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Database stopping"})
}

// KubernetesHandler handles Kubernetes cluster endpoints
type KubernetesHandler struct {
	kubernetesService *service.KubernetesService
	logger            *zap.Logger
}

// NewKubernetesHandler creates a new KubernetesHandler
func NewKubernetesHandler(kubernetesService *service.KubernetesService, logger *zap.Logger) *KubernetesHandler {
	return &KubernetesHandler{
		kubernetesService: kubernetesService,
		logger:            logger,
	}
}

// ListClusters lists Kubernetes clusters
// @Summary List Kubernetes clusters
// @Description Get all Kubernetes clusters for a provider
// @Tags kubernetes
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param region query string false "Region filter"
// @Success 200 {array} cloud.KubernetesCluster
// @Failure 400 {object} ErrorResponse
// @Router /kubernetes/clusters [get]
func (h *KubernetesHandler) ListClusters(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	region := c.Query("region")

	clusters, err := h.kubernetesService.ListClusters(c.Request.Context(), providerID, region)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, clusters)
}

// GetCluster gets a specific Kubernetes cluster
// @Summary Get Kubernetes cluster
// @Description Get details of a specific Kubernetes cluster
// @Tags kubernetes
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param cluster_name path string true "Cluster name"
// @Success 200 {object} cloud.KubernetesCluster
// @Failure 404 {object} ErrorResponse
// @Router /kubernetes/clusters/{cluster_name} [get]
func (h *KubernetesHandler) GetCluster(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	clusterName := c.Param("cluster_name")

	cluster, err := h.kubernetesService.GetCluster(c.Request.Context(), providerID, clusterName)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, cluster)
}

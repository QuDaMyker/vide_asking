package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/cloud"
	"github.com/vide/cloud-manager-backend/internal/models"
	"github.com/vide/cloud-manager-backend/internal/service"
	"go.uber.org/zap"
)

// CloudProviderHandler handles cloud provider endpoints
type CloudProviderHandler struct {
	providerService *service.CloudProviderService
	logger          *zap.Logger
}

// NewCloudProviderHandler creates a new CloudProviderHandler
func NewCloudProviderHandler(providerService *service.CloudProviderService, logger *zap.Logger) *CloudProviderHandler {
	return &CloudProviderHandler{
		providerService: providerService,
		logger:          logger,
	}
}

// CreateProviderRequest represents request to create a cloud provider
type CreateProviderRequest struct {
	Name         string                 `json:"name" binding:"required"`
	ProviderType models.ProviderType    `json:"provider_type" binding:"required,oneof=aws gcp azure"`
	Credentials  map[string]interface{} `json:"credentials" binding:"required"`
	Region       string                 `json:"region" binding:"required"`
	IsDefault    bool                   `json:"is_default"`
}

// ListProviders lists all cloud providers for the user
// @Summary List cloud providers
// @Description Get all cloud providers configured by the user
// @Tags providers
// @Produce json
// @Security BearerAuth
// @Success 200 {array} models.CloudProvider
// @Failure 401 {object} ErrorResponse
// @Router /providers [get]
func (h *CloudProviderHandler) ListProviders(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	providers, err := h.providerService.ListProviders(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, providers)
}

// CreateProvider creates a new cloud provider
// @Summary Create cloud provider
// @Description Add a new cloud provider configuration
// @Tags providers
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body CreateProviderRequest true "Provider configuration"
// @Success 201 {object} models.CloudProvider
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Router /providers [post]
func (h *CloudProviderHandler) CreateProvider(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req CreateProviderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	provider := &models.CloudProvider{
		UserID:       userID,
		Name:         req.Name,
		ProviderType: req.ProviderType,
		Credentials:  req.Credentials,
		Region:       req.Region,
		IsDefault:    req.IsDefault,
		Status:       "active",
	}

	if err := h.providerService.CreateProvider(c.Request.Context(), provider); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusCreated, provider)
}

// GetProvider gets a specific cloud provider
// @Summary Get cloud provider
// @Description Get a specific cloud provider by ID
// @Tags providers
// @Produce json
// @Security BearerAuth
// @Param id path string true "Provider ID"
// @Success 200 {object} models.CloudProvider
// @Failure 404 {object} ErrorResponse
// @Router /providers/{id} [get]
func (h *CloudProviderHandler) GetProvider(c *gin.Context) {
	providerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	provider, err := h.providerService.GetProvider(c.Request.Context(), providerID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "Provider not found"})
		return
	}

	c.JSON(http.StatusOK, provider)
}

// UpdateProvider updates a cloud provider
// @Summary Update cloud provider
// @Description Update cloud provider configuration
// @Tags providers
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Provider ID"
// @Param request body CreateProviderRequest true "Provider configuration"
// @Success 200 {object} models.CloudProvider
// @Failure 400 {object} ErrorResponse
// @Router /providers/{id} [put]
func (h *CloudProviderHandler) UpdateProvider(c *gin.Context) {
	providerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	var req CreateProviderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	provider := &models.CloudProvider{
		ID:          providerID,
		Name:        req.Name,
		Credentials: req.Credentials,
		Region:      req.Region,
		IsDefault:   req.IsDefault,
	}

	if err := h.providerService.UpdateProvider(c.Request.Context(), provider); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, provider)
}

// DeleteProvider deletes a cloud provider
// @Summary Delete cloud provider
// @Description Remove a cloud provider configuration
// @Tags providers
// @Security BearerAuth
// @Param id path string true "Provider ID"
// @Success 200 {object} SuccessResponse
// @Failure 404 {object} ErrorResponse
// @Router /providers/{id} [delete]
func (h *CloudProviderHandler) DeleteProvider(c *gin.Context) {
	providerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	if err := h.providerService.DeleteProvider(c.Request.Context(), providerID); err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "Provider not found"})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Provider deleted successfully"})
}

// TestConnection tests the connection to a cloud provider
// @Summary Test provider connection
// @Description Test the connection to a cloud provider
// @Tags providers
// @Produce json
// @Security BearerAuth
// @Param id path string true "Provider ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /providers/{id}/test [post]
func (h *CloudProviderHandler) TestConnection(c *gin.Context) {
	providerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	if err := h.providerService.TestConnection(c.Request.Context(), providerID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Connection test failed: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Connection test successful"})
}

// SyncResources syncs resources from a cloud provider
// @Summary Sync provider resources
// @Description Synchronize resources from a cloud provider
// @Tags providers
// @Produce json
// @Security BearerAuth
// @Param id path string true "Provider ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /providers/{id}/sync [post]
func (h *CloudProviderHandler) SyncResources(c *gin.Context) {
	providerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	count, err := h.providerService.SyncResources(c.Request.Context(), providerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Sync failed: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Resources synced successfully",
		"count":   count,
	})
}

// GetProviderStats gets statistics for a provider
// @Summary Get provider statistics
// @Description Get resource statistics for a cloud provider
// @Tags providers
// @Produce json
// @Security BearerAuth
// @Param id path string true "Provider ID"
// @Success 200 {object} map[string]interface{}
// @Failure 404 {object} ErrorResponse
// @Router /providers/{id}/stats [get]
func (h *CloudProviderHandler) GetProviderStats(c *gin.Context) {
	providerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	stats, err := h.providerService.GetProviderStats(c.Request.Context(), providerID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// ListRegions lists available regions for a provider
// @Summary List provider regions
// @Description Get available regions for a cloud provider type
// @Tags providers
// @Produce json
// @Security BearerAuth
// @Param type query string true "Provider type (aws, gcp, azure)"
// @Success 200 {array} cloud.Region
// @Failure 400 {object} ErrorResponse
// @Router /providers/regions [get]
func (h *CloudProviderHandler) ListRegions(c *gin.Context) {
	providerType := models.ProviderType(c.Query("type"))
	if providerType == "" {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Provider type is required"})
		return
	}

	regions, err := h.providerService.ListRegions(c.Request.Context(), providerType)
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, regions)
}

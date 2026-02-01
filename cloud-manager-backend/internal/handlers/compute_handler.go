package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/service"
	"go.uber.org/zap"
)

// ComputeHandler handles compute instance endpoints
type ComputeHandler struct {
	computeService *service.ComputeService
	logger         *zap.Logger
}

// NewComputeHandler creates a new ComputeHandler
func NewComputeHandler(computeService *service.ComputeService, logger *zap.Logger) *ComputeHandler {
	return &ComputeHandler{
		computeService: computeService,
		logger:         logger,
	}
}

// ListInstances lists compute instances
// @Summary List compute instances
// @Description Get all compute instances for a provider
// @Tags compute
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param region query string false "Region filter"
// @Success 200 {array} cloud.ComputeInstance
// @Failure 400 {object} ErrorResponse
// @Router /compute/instances [get]
func (h *ComputeHandler) ListInstances(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	region := c.Query("region")

	instances, err := h.computeService.ListInstances(c.Request.Context(), providerID, region)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, instances)
}

// GetInstance gets a specific compute instance
// @Summary Get compute instance
// @Description Get details of a specific compute instance
// @Tags compute
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} cloud.ComputeInstance
// @Failure 404 {object} ErrorResponse
// @Router /compute/instances/{instance_id} [get]
func (h *ComputeHandler) GetInstance(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	instance, err := h.computeService.GetInstance(c.Request.Context(), providerID, instanceID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, instance)
}

// StartInstance starts a compute instance
// @Summary Start compute instance
// @Description Start a stopped compute instance
// @Tags compute
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /compute/instances/{instance_id}/start [post]
func (h *ComputeHandler) StartInstance(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	if err := h.computeService.StartInstance(c.Request.Context(), providerID, instanceID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Instance starting"})
}

// StopInstance stops a compute instance
// @Summary Stop compute instance
// @Description Stop a running compute instance
// @Tags compute
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /compute/instances/{instance_id}/stop [post]
func (h *ComputeHandler) StopInstance(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	if err := h.computeService.StopInstance(c.Request.Context(), providerID, instanceID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Instance stopping"})
}

// RebootInstance reboots a compute instance
// @Summary Reboot compute instance
// @Description Reboot a compute instance
// @Tags compute
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /compute/instances/{instance_id}/reboot [post]
func (h *ComputeHandler) RebootInstance(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	if err := h.computeService.RebootInstance(c.Request.Context(), providerID, instanceID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Instance rebooting"})
}

// TerminateInstance terminates a compute instance
// @Summary Terminate compute instance
// @Description Permanently terminate a compute instance
// @Tags compute
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /compute/instances/{instance_id}/terminate [post]
func (h *ComputeHandler) TerminateInstance(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")

	if err := h.computeService.TerminateInstance(c.Request.Context(), providerID, instanceID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Instance terminating"})
}

// GetInstanceMetrics gets metrics for an instance
// @Summary Get instance metrics
// @Description Get CPU, memory, and network metrics for an instance
// @Tags compute
// @Produce json
// @Security BearerAuth
// @Param provider_id query string true "Provider ID"
// @Param instance_id path string true "Instance ID"
// @Param metric query string false "Metric name (cpu, memory, network)"
// @Param period query int false "Period in seconds"
// @Success 200 {array} cloud.MetricData
// @Failure 400 {object} ErrorResponse
// @Router /compute/instances/{instance_id}/metrics [get]
func (h *ComputeHandler) GetInstanceMetrics(c *gin.Context) {
	providerID, err := uuid.Parse(c.Query("provider_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid provider ID"})
		return
	}

	instanceID := c.Param("instance_id")
	metric := c.DefaultQuery("metric", "cpu")

	metrics, err := h.computeService.GetInstanceMetrics(c.Request.Context(), providerID, instanceID, metric)
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, metrics)
}

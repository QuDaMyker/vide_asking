package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/service"
	"go.uber.org/zap"
)

// MonitoringHandler handles monitoring endpoints
type MonitoringHandler struct {
	monitoringService *service.MonitoringService
	logger            *zap.Logger
}

// NewMonitoringHandler creates a new MonitoringHandler
func NewMonitoringHandler(monitoringService *service.MonitoringService, logger *zap.Logger) *MonitoringHandler {
	return &MonitoringHandler{
		monitoringService: monitoringService,
		logger:            logger,
	}
}

// GetMetricsRequest represents request for getting metrics
type GetMetricsRequest struct {
	ResourceID  string   `form:"resource_id" binding:"required"`
	MetricNames []string `form:"metric_names"`
	StartTime   string   `form:"start_time"`
	EndTime     string   `form:"end_time"`
	Period      int64    `form:"period"`
}

// DashboardStatsResponse represents dashboard statistics
type DashboardStatsResponse struct {
	TotalResources    int                    `json:"total_resources"`
	ActiveAlerts      int                    `json:"active_alerts"`
	CostThisMonth     float64                `json:"cost_this_month"`
	ProviderBreakdown map[string]int         `json:"provider_breakdown"`
	ResourceTypes     map[string]int         `json:"resource_types"`
	RecentActivity    []ActivityItem         `json:"recent_activity"`
	ResourceHealth    map[string]int         `json:"resource_health"`
}

// ActivityItem represents a recent activity
type ActivityItem struct {
	ID          uuid.UUID `json:"id"`
	Type        string    `json:"type"`
	Description string    `json:"description"`
	ResourceID  *uuid.UUID `json:"resource_id,omitempty"`
	Timestamp   time.Time `json:"timestamp"`
}

// GetMetrics gets metrics for a resource
// @Summary Get resource metrics
// @Description Get monitoring metrics for a specific resource
// @Tags monitoring
// @Produce json
// @Security BearerAuth
// @Param resource_id query string true "Resource ID"
// @Param metric_names query []string false "Metric names to retrieve"
// @Param start_time query string false "Start time (RFC3339)"
// @Param end_time query string false "End time (RFC3339)"
// @Param period query int false "Period in seconds"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} ErrorResponse
// @Router /monitoring/metrics [get]
func (h *MonitoringHandler) GetMetrics(c *gin.Context) {
	var req GetMetricsRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	resourceID, err := uuid.Parse(req.ResourceID)
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid resource ID"})
		return
	}

	startTime := time.Now().Add(-1 * time.Hour)
	endTime := time.Now()

	if req.StartTime != "" {
		startTime, _ = time.Parse(time.RFC3339, req.StartTime)
	}
	if req.EndTime != "" {
		endTime, _ = time.Parse(time.RFC3339, req.EndTime)
	}
	if req.Period == 0 {
		req.Period = 300 // 5 minutes default
	}

	metrics, err := h.monitoringService.GetMetrics(c.Request.Context(), resourceID, req.MetricNames, startTime, endTime, req.Period)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, metrics)
}

// GetDashboardStats gets dashboard statistics
// @Summary Get dashboard statistics
// @Description Get aggregated statistics for the dashboard
// @Tags monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} DashboardStatsResponse
// @Failure 500 {object} ErrorResponse
// @Router /monitoring/dashboard [get]
func (h *MonitoringHandler) GetDashboardStats(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	stats, err := h.monitoringService.GetDashboardStats(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetCostAnalysis gets cost analysis
// @Summary Get cost analysis
// @Description Get cost analysis for cloud resources
// @Tags monitoring
// @Produce json
// @Security BearerAuth
// @Param provider_id query string false "Filter by provider ID"
// @Param start_date query string false "Start date (YYYY-MM-DD)"
// @Param end_date query string false "End date (YYYY-MM-DD)"
// @Param group_by query string false "Group by (service, resource, tag)"
// @Success 200 {object} map[string]interface{}
// @Failure 500 {object} ErrorResponse
// @Router /monitoring/costs [get]
func (h *MonitoringHandler) GetCostAnalysis(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	providerIDStr := c.Query("provider_id")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	groupBy := c.DefaultQuery("group_by", "service")

	var providerID *uuid.UUID
	if providerIDStr != "" {
		id, err := uuid.Parse(providerIDStr)
		if err == nil {
			providerID = &id
		}
	}

	costs, err := h.monitoringService.GetCostAnalysis(c.Request.Context(), userID, providerID, startDate, endDate, groupBy)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, costs)
}

// GetResourceHealth gets resource health status
// @Summary Get resource health
// @Description Get health status of all resources
// @Tags monitoring
// @Produce json
// @Security BearerAuth
// @Param provider_id query string false "Filter by provider ID"
// @Success 200 {object} map[string]interface{}
// @Failure 500 {object} ErrorResponse
// @Router /monitoring/health [get]
func (h *MonitoringHandler) GetResourceHealth(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	providerIDStr := c.Query("provider_id")
	var providerID *uuid.UUID
	if providerIDStr != "" {
		id, err := uuid.Parse(providerIDStr)
		if err == nil {
			providerID = &id
		}
	}

	health, err := h.monitoringService.GetResourceHealth(c.Request.Context(), userID, providerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, health)
}

// GetAuditLogs gets audit logs
// @Summary Get audit logs
// @Description Get audit logs for user actions
// @Tags monitoring
// @Produce json
// @Security BearerAuth
// @Param resource_id query string false "Filter by resource ID"
// @Param action query string false "Filter by action type"
// @Param start_time query string false "Start time (RFC3339)"
// @Param end_time query string false "End time (RFC3339)"
// @Param page query int false "Page number"
// @Param page_size query int false "Page size"
// @Success 200 {object} PaginatedResponse
// @Failure 500 {object} ErrorResponse
// @Router /monitoring/audit-logs [get]
func (h *MonitoringHandler) GetAuditLogs(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	resourceIDStr := c.Query("resource_id")
	action := c.Query("action")
	startTimeStr := c.Query("start_time")
	endTimeStr := c.Query("end_time")
	page, pageSize := GetPagination(c)
	offset := CalculateOffset(page, pageSize)

	var resourceID *uuid.UUID
	if resourceIDStr != "" {
		id, err := uuid.Parse(resourceIDStr)
		if err == nil {
			resourceID = &id
		}
	}

	var startTime, endTime *time.Time
	if startTimeStr != "" {
		t, _ := time.Parse(time.RFC3339, startTimeStr)
		startTime = &t
	}
	if endTimeStr != "" {
		t, _ := time.Parse(time.RFC3339, endTimeStr)
		endTime = &t
	}

	logs, total, err := h.monitoringService.GetAuditLogs(c.Request.Context(), userID, resourceID, action, startTime, endTime, offset, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, PaginatedResponse{
		Data:       logs,
		Page:       page,
		PageSize:   pageSize,
		TotalItems: total,
		TotalPages: CalculateTotalPages(total, pageSize),
	})
}

// GetAlertsSummary gets a summary of all alerts
// @Summary Get alerts summary
// @Description Get summary of active alerts by severity
// @Tags monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]interface{}
// @Failure 500 {object} ErrorResponse
// @Router /monitoring/alerts-summary [get]
func (h *MonitoringHandler) GetAlertsSummary(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	summary, err := h.monitoringService.GetAlertsSummary(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, summary)
}

// ExportMetrics exports metrics in various formats
// @Summary Export metrics
// @Description Export metrics data to CSV or JSON
// @Tags monitoring
// @Produce json
// @Security BearerAuth
// @Param resource_id query string true "Resource ID"
// @Param format query string false "Export format (csv, json)"
// @Param start_time query string false "Start time (RFC3339)"
// @Param end_time query string false "End time (RFC3339)"
// @Success 200 {file} file
// @Failure 400 {object} ErrorResponse
// @Router /monitoring/export [get]
func (h *MonitoringHandler) ExportMetrics(c *gin.Context) {
	resourceIDStr := c.Query("resource_id")
	format := c.DefaultQuery("format", "json")
	startTimeStr := c.Query("start_time")
	endTimeStr := c.Query("end_time")

	resourceID, err := uuid.Parse(resourceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid resource ID"})
		return
	}

	startTime := time.Now().Add(-24 * time.Hour)
	endTime := time.Now()
	if startTimeStr != "" {
		startTime, _ = time.Parse(time.RFC3339, startTimeStr)
	}
	if endTimeStr != "" {
		endTime, _ = time.Parse(time.RFC3339, endTimeStr)
	}

	data, contentType, err := h.monitoringService.ExportMetrics(c.Request.Context(), resourceID, format, startTime, endTime)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.Header("Content-Disposition", "attachment; filename=metrics."+format)
	c.Data(http.StatusOK, contentType, data)
}

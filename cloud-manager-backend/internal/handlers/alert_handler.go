package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/models"
	"github.com/vide/cloud-manager-backend/internal/service"
	"go.uber.org/zap"
)

// AlertHandler handles alert endpoints
type AlertHandler struct {
	alertService *service.AlertService
	logger       *zap.Logger
}

// NewAlertHandler creates a new AlertHandler
func NewAlertHandler(alertService *service.AlertService, logger *zap.Logger) *AlertHandler {
	return &AlertHandler{
		alertService: alertService,
		logger:       logger,
	}
}

// CreateAlertRequest represents request to create an alert
type CreateAlertRequest struct {
	Name                 string                 `json:"name" binding:"required"`
	Description          string                 `json:"description"`
	ResourceID           *uuid.UUID             `json:"resource_id"`
	AlertType            models.AlertType       `json:"alert_type" binding:"required"`
	Condition            map[string]interface{} `json:"condition" binding:"required"`
	Severity             models.Severity        `json:"severity" binding:"required"`
	NotificationChannels []string               `json:"notification_channels"`
}

// ListAlerts lists all alerts for the user
// @Summary List alerts
// @Description Get all alerts configured by the user
// @Tags alerts
// @Produce json
// @Security BearerAuth
// @Param status query string false "Filter by status"
// @Param page query int false "Page number"
// @Param page_size query int false "Page size"
// @Success 200 {object} PaginatedResponse
// @Failure 401 {object} ErrorResponse
// @Router /alerts [get]
func (h *AlertHandler) ListAlerts(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	status := c.Query("status")
	page, pageSize := GetPagination(c)
	offset := CalculateOffset(page, pageSize)

	alerts, total, err := h.alertService.ListAlerts(c.Request.Context(), userID, status, offset, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, PaginatedResponse{
		Data:       alerts,
		Page:       page,
		PageSize:   pageSize,
		TotalItems: total,
		TotalPages: CalculateTotalPages(total, pageSize),
	})
}

// CreateAlert creates a new alert
// @Summary Create alert
// @Description Create a new alert configuration
// @Tags alerts
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body CreateAlertRequest true "Alert configuration"
// @Success 201 {object} models.Alert
// @Failure 400 {object} ErrorResponse
// @Router /alerts [post]
func (h *AlertHandler) CreateAlert(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req CreateAlertRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	alert := &models.Alert{
		UserID:               userID,
		ResourceID:           req.ResourceID,
		Name:                 req.Name,
		Description:          req.Description,
		AlertType:            req.AlertType,
		Condition:            req.Condition,
		Severity:             req.Severity,
		Status:               "active",
		NotificationChannels: req.NotificationChannels,
	}

	if err := h.alertService.CreateAlert(c.Request.Context(), alert); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusCreated, alert)
}

// GetAlert gets a specific alert
// @Summary Get alert
// @Description Get a specific alert by ID
// @Tags alerts
// @Produce json
// @Security BearerAuth
// @Param id path string true "Alert ID"
// @Success 200 {object} models.Alert
// @Failure 404 {object} ErrorResponse
// @Router /alerts/{id} [get]
func (h *AlertHandler) GetAlert(c *gin.Context) {
	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid alert ID"})
		return
	}

	alert, err := h.alertService.GetAlert(c.Request.Context(), alertID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "Alert not found"})
		return
	}

	c.JSON(http.StatusOK, alert)
}

// UpdateAlert updates an alert
// @Summary Update alert
// @Description Update alert configuration
// @Tags alerts
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Alert ID"
// @Param request body CreateAlertRequest true "Alert configuration"
// @Success 200 {object} models.Alert
// @Failure 400 {object} ErrorResponse
// @Router /alerts/{id} [put]
func (h *AlertHandler) UpdateAlert(c *gin.Context) {
	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid alert ID"})
		return
	}

	var req CreateAlertRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	alert := &models.Alert{
		ID:                   alertID,
		Name:                 req.Name,
		Description:          req.Description,
		Condition:            req.Condition,
		Severity:             req.Severity,
		NotificationChannels: req.NotificationChannels,
	}

	if err := h.alertService.UpdateAlert(c.Request.Context(), alert); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, alert)
}

// DeleteAlert deletes an alert
// @Summary Delete alert
// @Description Remove an alert configuration
// @Tags alerts
// @Security BearerAuth
// @Param id path string true "Alert ID"
// @Success 200 {object} SuccessResponse
// @Failure 404 {object} ErrorResponse
// @Router /alerts/{id} [delete]
func (h *AlertHandler) DeleteAlert(c *gin.Context) {
	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid alert ID"})
		return
	}

	if err := h.alertService.DeleteAlert(c.Request.Context(), alertID); err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "Alert not found"})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Alert deleted successfully"})
}

// EnableAlert enables an alert
// @Summary Enable alert
// @Description Enable a disabled alert
// @Tags alerts
// @Produce json
// @Security BearerAuth
// @Param id path string true "Alert ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /alerts/{id}/enable [post]
func (h *AlertHandler) EnableAlert(c *gin.Context) {
	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid alert ID"})
		return
	}

	if err := h.alertService.EnableAlert(c.Request.Context(), alertID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Alert enabled"})
}

// DisableAlert disables an alert
// @Summary Disable alert
// @Description Disable an active alert
// @Tags alerts
// @Produce json
// @Security BearerAuth
// @Param id path string true "Alert ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /alerts/{id}/disable [post]
func (h *AlertHandler) DisableAlert(c *gin.Context) {
	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid alert ID"})
		return
	}

	if err := h.alertService.DisableAlert(c.Request.Context(), alertID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Alert disabled"})
}

// GetAlertHistory gets alert history
// @Summary Get alert history
// @Description Get trigger history for an alert
// @Tags alerts
// @Produce json
// @Security BearerAuth
// @Param id path string true "Alert ID"
// @Param page query int false "Page number"
// @Param page_size query int false "Page size"
// @Success 200 {object} PaginatedResponse
// @Failure 400 {object} ErrorResponse
// @Router /alerts/{id}/history [get]
func (h *AlertHandler) GetAlertHistory(c *gin.Context) {
	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid alert ID"})
		return
	}

	page, pageSize := GetPagination(c)
	offset := CalculateOffset(page, pageSize)

	history, total, err := h.alertService.GetAlertHistory(c.Request.Context(), alertID, offset, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, PaginatedResponse{
		Data:       history,
		Page:       page,
		PageSize:   pageSize,
		TotalItems: total,
		TotalPages: CalculateTotalPages(total, pageSize),
	})
}

// TestAlert tests an alert by sending a test notification
// @Summary Test alert
// @Description Send a test notification for an alert
// @Tags alerts
// @Produce json
// @Security BearerAuth
// @Param id path string true "Alert ID"
// @Success 200 {object} SuccessResponse
// @Failure 400 {object} ErrorResponse
// @Router /alerts/{id}/test [post]
func (h *AlertHandler) TestAlert(c *gin.Context) {
	alertID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "Invalid alert ID"})
		return
	}

	if err := h.alertService.TestAlert(c.Request.Context(), alertID); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{Message: "Test notification sent"})
}

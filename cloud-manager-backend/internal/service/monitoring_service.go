package service

import (
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/vide/cloud-manager-backend/internal/cloud"
	"github.com/vide/cloud-manager-backend/internal/models"
	"github.com/vide/cloud-manager-backend/internal/repository"
	"go.uber.org/zap"
)

// MonitoringService handles monitoring business logic
type MonitoringService struct {
	providerRepo    *repository.CloudProviderRepository
	resourceRepo    *repository.CloudResourceRepository
	alertRepo       *repository.AlertRepository
	auditLogRepo    *repository.AuditLogRepository
	providerFactory *cloud.ProviderFactory
	logger          *zap.Logger
}

// NewMonitoringService creates a new MonitoringService
func NewMonitoringService(
	providerRepo *repository.CloudProviderRepository,
	resourceRepo *repository.CloudResourceRepository,
	alertRepo *repository.AlertRepository,
	auditLogRepo *repository.AuditLogRepository,
	providerFactory *cloud.ProviderFactory,
	logger *zap.Logger,
) *MonitoringService {
	return &MonitoringService{
		providerRepo:    providerRepo,
		resourceRepo:    resourceRepo,
		alertRepo:       alertRepo,
		auditLogRepo:    auditLogRepo,
		providerFactory: providerFactory,
		logger:          logger,
	}
}

// DashboardStats represents dashboard statistics
type DashboardStats struct {
	TotalResources    int            `json:"total_resources"`
	ActiveAlerts      int            `json:"active_alerts"`
	CostThisMonth     float64        `json:"cost_this_month"`
	ProviderBreakdown map[string]int `json:"provider_breakdown"`
	ResourceTypes     map[string]int `json:"resource_types"`
	RecentActivity    []ActivityItem `json:"recent_activity"`
	ResourceHealth    map[string]int `json:"resource_health"`
}

// ActivityItem represents recent activity
type ActivityItem struct {
	ID          uuid.UUID  `json:"id"`
	Type        string     `json:"type"`
	Description string     `json:"description"`
	ResourceID  *uuid.UUID `json:"resource_id,omitempty"`
	Timestamp   time.Time  `json:"timestamp"`
}

// CostAnalysis represents cost analysis data
type CostAnalysis struct {
	TotalCost   float64            `json:"total_cost"`
	ByService   map[string]float64 `json:"by_service"`
	ByResource  map[string]float64 `json:"by_resource"`
	ByTag       map[string]float64 `json:"by_tag"`
	DateRange   DateRange          `json:"date_range"`
	Forecast    float64            `json:"forecast"`
}

// DateRange represents a date range
type DateRange struct {
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
}

// ResourceHealth represents resource health status
type ResourceHealth struct {
	Healthy   int                `json:"healthy"`
	Warning   int                `json:"warning"`
	Critical  int                `json:"critical"`
	Unknown   int                `json:"unknown"`
	ByType    map[string]int     `json:"by_type"`
	Resources []ResourceStatus   `json:"resources"`
}

// ResourceStatus represents individual resource status
type ResourceStatus struct {
	ID       uuid.UUID `json:"id"`
	Name     string    `json:"name"`
	Type     string    `json:"type"`
	Status   string    `json:"status"`
	Provider string    `json:"provider"`
}

// AlertsSummary represents alerts summary
type AlertsSummary struct {
	Total    int            `json:"total"`
	Active   int            `json:"active"`
	Disabled int            `json:"disabled"`
	BySeverity map[string]int `json:"by_severity"`
	Recent   []*models.Alert `json:"recent"`
}

// GetMetrics gets metrics for a resource
func (s *MonitoringService) GetMetrics(ctx context.Context, resourceID uuid.UUID, metricNames []string, startTime, endTime time.Time, period int64) ([]*cloud.MetricData, error) {
	resource, err := s.resourceRepo.GetByID(ctx, resourceID)
	if err != nil {
		return nil, errors.New("resource not found")
	}

	provider, err := s.providerRepo.GetByID(ctx, resource.ProviderID)
	if err != nil {
		return nil, errors.New("provider not found")
	}

	cloudProvider, err := s.providerFactory.GetProvider(provider)
	if err != nil {
		return nil, err
	}

	if len(metricNames) == 0 {
		metricNames = []string{"CPUUtilization", "MemoryUtilization", "NetworkIn", "NetworkOut"}
	}

	query := &cloud.MetricQuery{
		ResourceID:  resource.ResourceID,
		MetricNames: metricNames,
		StartTime:   startTime,
		EndTime:     endTime,
		Period:      period,
		Region:      resource.Region,
	}

	return cloudProvider.GetMetrics(ctx, query)
}

// GetDashboardStats gets dashboard statistics
func (s *MonitoringService) GetDashboardStats(ctx context.Context, userID uuid.UUID) (*DashboardStats, error) {
	stats := &DashboardStats{
		ProviderBreakdown: make(map[string]int),
		ResourceTypes:     make(map[string]int),
		ResourceHealth:    make(map[string]int),
		RecentActivity:    make([]ActivityItem, 0),
	}

	// Get providers
	providers, err := s.providerRepo.ListByUserID(ctx, userID, 0, 100)
	if err != nil {
		return nil, err
	}

	// Count resources by provider
	for _, provider := range providers {
		resources, _ := s.resourceRepo.ListByProviderID(ctx, provider.ID, 0, 1000)
		stats.ProviderBreakdown[string(provider.ProviderType)] = len(resources)
		stats.TotalResources += len(resources)

		for _, r := range resources {
			stats.ResourceTypes[string(r.ResourceType)]++
			
			// Determine health status
			switch r.Status {
			case "running", "available", "active":
				stats.ResourceHealth["healthy"]++
			case "stopped", "stopping", "pending":
				stats.ResourceHealth["warning"]++
			case "terminated", "error", "failed":
				stats.ResourceHealth["critical"]++
			default:
				stats.ResourceHealth["unknown"]++
			}
		}
	}

	// Get active alerts count
	alerts, _ := s.alertRepo.ListByUserID(ctx, userID, 0, 1000)
	for _, alert := range alerts {
		if alert.Status == "active" {
			stats.ActiveAlerts++
		}
	}

	// Get recent audit logs as activity
	auditLogs, _ := s.auditLogRepo.ListByUserID(ctx, userID, 0, 10)
	for _, log := range auditLogs {
		stats.RecentActivity = append(stats.RecentActivity, ActivityItem{
			ID:          log.ID,
			Type:        log.Action,
			Description: log.Action,
			ResourceID:  log.ResourceID,
			Timestamp:   log.CreatedAt,
		})
	}

	// Estimate cost (in real implementation, this would query cost APIs)
	stats.CostThisMonth = float64(stats.TotalResources) * 50.0 // Placeholder

	return stats, nil
}

// GetCostAnalysis gets cost analysis
func (s *MonitoringService) GetCostAnalysis(ctx context.Context, userID uuid.UUID, providerID *uuid.UUID, startDate, endDate, groupBy string) (*CostAnalysis, error) {
	analysis := &CostAnalysis{
		ByService:  make(map[string]float64),
		ByResource: make(map[string]float64),
		ByTag:      make(map[string]float64),
		DateRange: DateRange{
			StartDate: startDate,
			EndDate:   endDate,
		},
	}

	// Get providers to query
	var providers []*models.CloudProvider
	if providerID != nil {
		provider, err := s.providerRepo.GetByID(ctx, *providerID)
		if err != nil {
			return nil, err
		}
		providers = []*models.CloudProvider{provider}
	} else {
		var err error
		providers, err = s.providerRepo.ListByUserID(ctx, userID, 0, 100)
		if err != nil {
			return nil, err
		}
	}

	// Query cost from each provider
	for _, provider := range providers {
		cloudProvider, err := s.providerFactory.GetProvider(provider)
		if err != nil {
			continue
		}

		costData, err := cloudProvider.GetCostAndUsage(ctx, startDate, endDate, groupBy)
		if err != nil {
			s.logger.Warn("Failed to get cost data", zap.Error(err), zap.String("provider", string(provider.ProviderType)))
			continue
		}

		analysis.TotalCost += costData.Total
		
		for service, cost := range costData.ByService {
			analysis.ByService[service] += cost
		}
	}

	// Calculate forecast based on current spending
	if analysis.TotalCost > 0 {
		analysis.Forecast = analysis.TotalCost * 1.1 // Simple 10% increase forecast
	}

	return analysis, nil
}

// GetResourceHealth gets resource health status
func (s *MonitoringService) GetResourceHealth(ctx context.Context, userID uuid.UUID, providerID *uuid.UUID) (*ResourceHealth, error) {
	health := &ResourceHealth{
		ByType:    make(map[string]int),
		Resources: make([]ResourceStatus, 0),
	}

	// Get providers
	var providers []*models.CloudProvider
	if providerID != nil {
		provider, err := s.providerRepo.GetByID(ctx, *providerID)
		if err != nil {
			return nil, err
		}
		providers = []*models.CloudProvider{provider}
	} else {
		var err error
		providers, err = s.providerRepo.ListByUserID(ctx, userID, 0, 100)
		if err != nil {
			return nil, err
		}
	}

	for _, provider := range providers {
		resources, _ := s.resourceRepo.ListByProviderID(ctx, provider.ID, 0, 1000)
		
		for _, r := range resources {
			status := "healthy"
			switch r.Status {
			case "running", "available", "active":
				health.Healthy++
				status = "healthy"
			case "stopped", "stopping", "pending":
				health.Warning++
				status = "warning"
			case "terminated", "error", "failed":
				health.Critical++
				status = "critical"
			default:
				health.Unknown++
				status = "unknown"
			}

			health.ByType[string(r.ResourceType)]++
			health.Resources = append(health.Resources, ResourceStatus{
				ID:       r.ID,
				Name:     r.Name,
				Type:     string(r.ResourceType),
				Status:   status,
				Provider: string(provider.ProviderType),
			})
		}
	}

	return health, nil
}

// GetAuditLogs gets audit logs
func (s *MonitoringService) GetAuditLogs(ctx context.Context, userID uuid.UUID, resourceID *uuid.UUID, action string, startTime, endTime *time.Time, offset, limit int) ([]*models.AuditLog, int, error) {
	logs, err := s.auditLogRepo.ListByUserID(ctx, userID, offset, limit)
	if err != nil {
		return nil, 0, err
	}

	// Filter results
	filtered := make([]*models.AuditLog, 0)
	for _, log := range logs {
		// Filter by resource ID
		if resourceID != nil && (log.ResourceID == nil || *log.ResourceID != *resourceID) {
			continue
		}
		// Filter by action
		if action != "" && log.Action != action {
			continue
		}
		// Filter by time range
		if startTime != nil && log.CreatedAt.Before(*startTime) {
			continue
		}
		if endTime != nil && log.CreatedAt.After(*endTime) {
			continue
		}
		filtered = append(filtered, log)
	}

	total, _ := s.auditLogRepo.CountByUserID(ctx, userID)
	return filtered, total, nil
}

// GetAlertsSummary gets alerts summary
func (s *MonitoringService) GetAlertsSummary(ctx context.Context, userID uuid.UUID) (*AlertsSummary, error) {
	summary := &AlertsSummary{
		BySeverity: make(map[string]int),
		Recent:     make([]*models.Alert, 0),
	}

	alerts, err := s.alertRepo.ListByUserID(ctx, userID, 0, 100)
	if err != nil {
		return nil, err
	}

	summary.Total = len(alerts)

	for _, alert := range alerts {
		if alert.Status == "active" {
			summary.Active++
		} else {
			summary.Disabled++
		}
		summary.BySeverity[string(alert.Severity)]++
	}

	// Get recent alerts (last 5)
	if len(alerts) > 5 {
		summary.Recent = alerts[:5]
	} else {
		summary.Recent = alerts
	}

	return summary, nil
}

// ExportMetrics exports metrics to CSV or JSON
func (s *MonitoringService) ExportMetrics(ctx context.Context, resourceID uuid.UUID, format string, startTime, endTime time.Time) ([]byte, string, error) {
	metrics, err := s.GetMetrics(ctx, resourceID, nil, startTime, endTime, 300)
	if err != nil {
		return nil, "", err
	}

	switch format {
	case "csv":
		return s.exportToCSV(metrics)
	case "json":
		return s.exportToJSON(metrics)
	default:
		return s.exportToJSON(metrics)
	}
}

func (s *MonitoringService) exportToCSV(metrics []*cloud.MetricData) ([]byte, string, error) {
	var buf bytes.Buffer
	writer := csv.NewWriter(&buf)

	// Write header
	header := []string{"Metric", "Timestamp", "Value", "Unit"}
	writer.Write(header)

	// Write data
	for _, metric := range metrics {
		for i, ts := range metric.Timestamps {
			row := []string{
				metric.MetricName,
				ts.Format(time.RFC3339),
				formatFloat(metric.Values[i]),
				metric.Unit,
			}
			writer.Write(row)
		}
	}

	writer.Flush()
	return buf.Bytes(), "text/csv", nil
}

func (s *MonitoringService) exportToJSON(metrics []*cloud.MetricData) ([]byte, string, error) {
	data, err := json.Marshal(metrics)
	if err != nil {
		return nil, "", err
	}
	return data, "application/json", nil
}

func formatFloat(f float64) string {
	return json.Number(json.Number(string(rune(f)))).String()
}

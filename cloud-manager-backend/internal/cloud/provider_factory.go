package cloud

import (
	"errors"
	"sync"

	"github.com/vide/cloud-manager-backend/internal/config"
	"github.com/vide/cloud-manager-backend/internal/models"
	"go.uber.org/zap"
)

// ProviderFactory creates and caches cloud provider instances
type ProviderFactory struct {
	config    *config.Config
	logger    *zap.Logger
	providers map[string]CloudProvider
	mu        sync.RWMutex
}

// NewProviderFactory creates a new ProviderFactory
func NewProviderFactory(config *config.Config, logger *zap.Logger) *ProviderFactory {
	return &ProviderFactory{
		config:    config,
		logger:    logger,
		providers: make(map[string]CloudProvider),
	}
}

// GetProvider returns a cloud provider for the given configuration
func (f *ProviderFactory) GetProvider(provider *models.CloudProvider) (CloudProvider, error) {
	f.mu.RLock()
	if p, ok := f.providers[provider.ID.String()]; ok {
		f.mu.RUnlock()
		return p, nil
	}
	f.mu.RUnlock()

	f.mu.Lock()
	defer f.mu.Unlock()

	// Double check after acquiring write lock
	if p, ok := f.providers[provider.ID.String()]; ok {
		return p, nil
	}

	var cloudProvider CloudProvider
	var err error

	switch provider.ProviderType {
	case models.ProviderAWS:
		cloudProvider, err = NewAWSProvider(&AWSConfig{
			AccessKeyID:     provider.AccessKey,
			SecretAccessKey: provider.SecretKey,
			Region:          provider.Region,
		}, f.logger)
	case models.ProviderGCP:
		cloudProvider, err = NewGCPProvider(&GCPConfig{
			ProjectID:       provider.ProjectID,
			CredentialsJSON: provider.CredentialsJSON,
			Region:          provider.Region,
		}, f.logger)
	case models.ProviderAzure:
		cloudProvider, err = NewAzureProvider(&AzureConfig{
			SubscriptionID: provider.SubscriptionID,
			TenantID:       provider.TenantID,
			ClientID:       provider.ClientID,
			ClientSecret:   provider.ClientSecret,
			Region:         provider.Region,
		}, f.logger)
	default:
		return nil, errors.New("unsupported provider type: " + string(provider.ProviderType))
	}

	if err != nil {
		return nil, err
	}

	f.providers[provider.ID.String()] = cloudProvider
	return cloudProvider, nil
}

// ClearCache clears the provider cache
func (f *ProviderFactory) ClearCache() {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.providers = make(map[string]CloudProvider)
}

// RemoveProvider removes a provider from cache
func (f *ProviderFactory) RemoveProvider(providerID string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	delete(f.providers, providerID)
}

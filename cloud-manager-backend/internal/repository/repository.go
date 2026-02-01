package repository

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/fx"
)

// Module provides repository dependencies
var Module = fx.Options(
	fx.Provide(NewUserRepository),
	fx.Provide(NewCloudProviderRepository),
	fx.Provide(NewCloudResourceRepository),
	fx.Provide(NewAlertRepository),
	fx.Provide(NewAuditLogRepository),
	fx.Provide(NewRefreshTokenRepository),
)

// RefreshTokenRepository handles refresh token data operations
type RefreshTokenRepository struct {
	pool *pgxpool.Pool
}

// NewRefreshTokenRepository creates a new RefreshTokenRepository
func NewRefreshTokenRepository(pool *pgxpool.Pool) *RefreshTokenRepository {
	return &RefreshTokenRepository{pool: pool}
}

// Additional repository methods...

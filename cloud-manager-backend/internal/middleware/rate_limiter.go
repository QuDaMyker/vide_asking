package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// RateLimitConfig represents rate limit configuration
type RateLimitConfig struct {
	RequestsPerSecond int
	Burst             int
}

// RateLimiter provides rate limiting middleware
type RateLimiter struct {
	config   *RateLimitConfig
	logger   *zap.Logger
	visitors map[string]*visitor
	mu       sync.RWMutex
}

type visitor struct {
	tokens   int
	lastSeen time.Time
}

// NewRateLimiter creates a new RateLimiter
func NewRateLimiter(config *RateLimitConfig, logger *zap.Logger) *RateLimiter {
	rl := &RateLimiter{
		config:   config,
		logger:   logger,
		visitors: make(map[string]*visitor),
	}

	// Cleanup goroutine
	go rl.cleanupVisitors()

	return rl
}

// Limit returns rate limiting middleware
func (r *RateLimiter) Limit() gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()

		if !r.allow(ip) {
			r.logger.Warn("Rate limit exceeded",
				zap.String("ip", ip),
				zap.String("path", c.Request.URL.Path),
			)
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "Rate limit exceeded. Please try again later.",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

func (r *RateLimiter) allow(ip string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	v, exists := r.visitors[ip]
	if !exists {
		r.visitors[ip] = &visitor{
			tokens:   r.config.Burst - 1,
			lastSeen: time.Now(),
		}
		return true
	}

	// Calculate tokens to add based on elapsed time
	elapsed := time.Since(v.lastSeen)
	tokensToAdd := int(elapsed.Seconds()) * r.config.RequestsPerSecond
	v.tokens += tokensToAdd
	if v.tokens > r.config.Burst {
		v.tokens = r.config.Burst
	}
	v.lastSeen = time.Now()

	if v.tokens > 0 {
		v.tokens--
		return true
	}

	return false
}

func (r *RateLimiter) cleanupVisitors() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		r.mu.Lock()
		for ip, v := range r.visitors {
			if time.Since(v.lastSeen) > 3*time.Minute {
				delete(r.visitors, ip)
			}
		}
		r.mu.Unlock()
	}
}

// CORSConfig represents CORS configuration
type CORSConfig struct {
	AllowOrigins     []string
	AllowMethods     []string
	AllowHeaders     []string
	ExposeHeaders    []string
	AllowCredentials bool
	MaxAge           int
}

// CORSMiddleware provides CORS middleware
func CORSMiddleware(config *CORSConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		
		// Check if origin is allowed
		allowed := false
		for _, o := range config.AllowOrigins {
			if o == "*" || o == origin {
				allowed = true
				break
			}
		}

		if allowed {
			c.Header("Access-Control-Allow-Origin", origin)
		}

		c.Header("Access-Control-Allow-Methods", joinStrings(config.AllowMethods))
		c.Header("Access-Control-Allow-Headers", joinStrings(config.AllowHeaders))
		c.Header("Access-Control-Expose-Headers", joinStrings(config.ExposeHeaders))

		if config.AllowCredentials {
			c.Header("Access-Control-Allow-Credentials", "true")
		}

		if config.MaxAge > 0 {
			c.Header("Access-Control-Max-Age", string(rune(config.MaxAge)))
		}

		// Handle preflight request
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

func joinStrings(s []string) string {
	if len(s) == 0 {
		return ""
	}
	result := s[0]
	for i := 1; i < len(s); i++ {
		result += ", " + s[i]
	}
	return result
}

// RecoveryMiddleware recovers from panics
func RecoveryMiddleware(logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				logger.Error("Panic recovered",
					zap.Any("error", err),
					zap.String("path", c.Request.URL.Path),
					zap.String("method", c.Request.Method),
				)

				c.JSON(http.StatusInternalServerError, gin.H{
					"error": "Internal server error",
				})
				c.Abort()
			}
		}()

		c.Next()
	}
}

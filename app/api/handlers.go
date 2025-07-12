package api

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/redis/go-redis/v9"
)

const redisCounterKey = "counter"

// Server holds the dependencies for the API handlers.
type Server struct {
	RedisClient *redis.Client
}

// WriteHandler handles requests to increment the counter.
func (s *Server) WriteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONError(w, http.StatusMethodNotAllowed, "Only POST method is allowed")
		return
	}

	val, err := s.RedisClient.Incr(r.Context(), redisCounterKey).Result()
	if err != nil {
		slog.Error("Failed to increment redis counter", "err", err)
		writeJSONError(w, http.StatusInternalServerError, "Failed to update counter")
		return
	}

	writeJSON(w, http.StatusOK, map[string]int64{"value": val})
}

// ReadHandler handles requests to read the counter.
func (s *Server) ReadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "Only GET method is allowed")
		return
	}

	val, err := s.RedisClient.Get(r.Context(), redisCounterKey).Int64()
	if err == redis.Nil {
		// If the key doesn't exist, return 0.
		writeJSON(w, http.StatusOK, map[string]int64{"value": 0})
		return
	} else if err != nil {
		slog.Error("Failed to read redis counter", "err", err)
		writeJSONError(w, http.StatusInternalServerError, "Failed to read counter")
		return
	}

	writeJSON(w, http.StatusOK, map[string]int64{"value": val})
}

// writeJSON is a helper for sending JSON responses.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("Failed to write JSON response", "err", err)
	}
}

// writeJSONError is a helper for sending JSON error responses.
func writeJSONError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

// HealthHandler provides health check endpoint for Kubernetes probes 🚀
func (s *Server) HealthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "Only GET method is allowed")
		return
	}

	// Check Redis connectivity like a boss
	_, err := s.RedisClient.Ping(r.Context()).Result()
	if err != nil {
		slog.Error("Health check failed - Redis connectivity", "err", err)
		writeJSONError(w, http.StatusServiceUnavailable, "Redis unavailable")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "healthy",
		"service": "tikky-api",
		"redis": "connected",
		"vibe": "immaculate",
	})
}

// MetricsHandler provides spicy metrics in Prometheus format 🌶️
func (s *Server) MetricsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "Only GET method is allowed")
		return
	}

	// Get current counter value for metrics
	val, err := s.RedisClient.Get(r.Context(), redisCounterKey).Int64()
	if err == redis.Nil {
		val = 0
	} else if err != nil {
		slog.Error("Failed to read counter for metrics", "err", err)
		val = -1 // Indicate error state
	}

	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	
	// Basic Prometheus metrics format - production ready! 
	metrics := `# HELP tikky_counter_total Total counter value (goes brrr)
# TYPE tikky_counter_total counter
tikky_counter_total %d

# HELP tikky_redis_connected Redis connection status (1=connected, 0=disconnected)
# TYPE tikky_redis_connected gauge
tikky_redis_connected %d

# HELP tikky_build_info Build information
# TYPE tikky_build_info gauge
tikky_build_info{version="1.0.0",service="tikky-api"} 1
`
	
	// Check Redis connection for metrics
	redisConnected := 1
	if _, err := s.RedisClient.Ping(r.Context()).Result(); err != nil {
		redisConnected = 0
	}

	w.Write([]byte(fmt.Sprintf(metrics, val, redisConnected)))
}

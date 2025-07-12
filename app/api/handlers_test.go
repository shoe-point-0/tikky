package api

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/redis/go-redis/v9"
)

// Simple integration-style tests that are easier to maintain
func TestReadHandler_Integration(t *testing.T) {
	tests := []struct {
		name           string
		method         string
		expectedStatus int
		setupRedis     func(*testing.T) *Server
	}{
		{
			name:           "GET method returns 200",
			method:         "GET",
			expectedStatus: 200,
			setupRedis: func(t *testing.T) *Server {
				// Use a simple mock that satisfies the basic interface
				return &Server{RedisClient: &mockRedisClient{counter: 42}}
			},
		},
		{
			name:           "POST method returns 405",
			method:         "POST",
			expectedStatus: 405,
			setupRedis: func(t *testing.T) *Server {
				return &Server{RedisClient: &mockRedisClient{}}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := tt.setupRedis(t)
			req := httptest.NewRequest(tt.method, "/read", nil)
			w := httptest.NewRecorder()

			server.ReadHandler(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, w.Code)
			}
		})
	}
}

func TestWriteHandler_Integration(t *testing.T) {
	tests := []struct {
		name           string
		method         string
		expectedStatus int
		setupRedis     func(*testing.T) *Server
	}{
		{
			name:           "POST method returns 200",
			method:         "POST",
			expectedStatus: 200,
			setupRedis: func(t *testing.T) *Server {
				return &Server{RedisClient: &mockRedisClient{}}
			},
		},
		{
			name:           "GET method returns 405",
			method:         "GET",
			expectedStatus: 405,
			setupRedis: func(t *testing.T) *Server {
				return &Server{RedisClient: &mockRedisClient{}}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := tt.setupRedis(t)
			req := httptest.NewRequest(tt.method, "/write", strings.NewReader(""))
			w := httptest.NewRecorder()

			server.WriteHandler(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, w.Code)
			}
		})
	}
}

func TestHealthHandler_Integration(t *testing.T) {
	server := &Server{RedisClient: &mockRedisClient{}}
	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	server.HealthHandler(w, req)

	if w.Code != 200 {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	// Check that response contains expected fields
	var response map[string]string
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got '%s'", response["status"])
	}

	if response["vibe"] != "immaculate" {
		t.Errorf("Expected vibe 'immaculate', got '%s'", response["vibe"])
	}
}

func TestMetricsHandler_Integration(t *testing.T) {
	server := &Server{RedisClient: &mockRedisClient{counter: 100}}
	req := httptest.NewRequest("GET", "/metrics", nil)
	w := httptest.NewRecorder()

	server.MetricsHandler(w, req)

	if w.Code != 200 {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	body := w.Body.String()
	expectedMetrics := []string{
		"tikky_counter_total",
		"tikky_redis_connected",
		"tikky_build_info",
	}

	for _, metric := range expectedMetrics {
		if !strings.Contains(body, metric) {
			t.Errorf("Expected metrics to contain '%s'", metric)
		}
	}
}

// Simple mock Redis client for testing
type mockRedisClient struct {
	counter int64
	err     error
}

func (m *mockRedisClient) Get(ctx context.Context, key string) *redis.StringCmd {
	cmd := redis.NewStringCmd(ctx, "get", key)
	if m.err != nil {
		cmd.SetErr(m.err)
	} else if m.counter > 0 {
		cmd.SetVal(string(rune(m.counter)))
	} else {
		cmd.SetErr(redis.Nil)
	}
	return cmd
}

func (m *mockRedisClient) Incr(ctx context.Context, key string) *redis.IntCmd {
	cmd := redis.NewIntCmd(ctx, "incr", key)
	if m.err != nil {
		cmd.SetErr(m.err)
	} else {
		m.counter++
		cmd.SetVal(m.counter)
	}
	return cmd
}

func (m *mockRedisClient) Ping(ctx context.Context) *redis.StatusCmd {
	cmd := redis.NewStatusCmd(ctx, "ping")
	if m.err != nil {
		cmd.SetErr(m.err)
	} else {
		cmd.SetVal("PONG")
	}
	return cmd
}

func (m *mockRedisClient) Close() error {
	return nil
}

// Benchmark tests for performance validation
func BenchmarkReadHandler(b *testing.B) {
	server := &Server{RedisClient: &mockRedisClient{counter: 42}}
	req := httptest.NewRequest("GET", "/read", nil)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		w := httptest.NewRecorder()
		server.ReadHandler(w, req)
	}
}

func BenchmarkWriteHandler(b *testing.B) {
	server := &Server{RedisClient: &mockRedisClient{}}
	req := httptest.NewRequest("POST", "/write", strings.NewReader(""))

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		w := httptest.NewRecorder()
		server.WriteHandler(w, req)
	}
}
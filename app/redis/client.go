package redis

import (
	"context"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

// NewClient creates and configures a new Redis client with connection pooling.
// It reads configuration from environment variables.
func NewClient(ctx context.Context) (*redis.Client, error) {
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379" // Default for local development
	}

	password := os.Getenv("REDIS_PASSWORD") // Default is no password

	rdb := redis.NewClient(&redis.Options{
		Addr:         addr,
		Password:     password,
		DB:           0,  // use default DB
		PoolSize:     20, // Production-sensible default
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	})

	// Ping the server to ensure a connection is established.
	if _, err := rdb.Ping(ctx).Result(); err != nil {
		return nil, err
	}

	return rdb, nil
}

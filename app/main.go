package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"tikky/api"
	"tikky/redis"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	// Context for startup
	startupCtx, cancelStartup := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancelStartup()

	redisClient, err := redis.NewClient(startupCtx)
	if err != nil {
		slog.Error("Failed to connect to redis", "err", err)
		os.Exit(1)
	}
	defer redisClient.Close()
	slog.Info("Successfully connected to Redis")

	apiServer := &api.Server{
		RedisClient: redisClient,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/read", apiServer.ReadHandler)
	mux.HandleFunc("/write", apiServer.WriteHandler)
	mux.HandleFunc("/health", apiServer.HealthHandler)
	mux.HandleFunc("/metrics", apiServer.MetricsHandler)

	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	go func() {
		slog.Info("Server starting on port 8080")
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("Server failed to start", "err", err)
			os.Exit(1)
		}
	}()

	// Graceful Shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancelShutdown := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelShutdown()

	slog.Info("Shutting down server gracefully")
	if err := server.Shutdown(shutdownCtx); err != nil {
		slog.Error("Server shutdown failed", "err", err)
		os.Exit(1)
	}

	slog.Info("Server stopped")
}

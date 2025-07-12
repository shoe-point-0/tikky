# Makefile for tikky - Production-ready counter API
.PHONY: help build test lint clean deploy load-test docker-build docker-load

# Default target
help: ## Show this help message
	@echo "tikky - Production-ready counter API"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# Development
build: ## Build the application
	@echo "🔨 Building tikky..."
	cd app && go build -o ../bin/tikky .

test: ## Run tests with coverage
	@echo "🧪 Running tests..."
	cd app && go test -v -race -coverprofile=coverage.out ./...
	cd app && go tool cover -func=coverage.out

test-html: ## Run tests and generate HTML coverage report
	@echo "🧪 Running tests with HTML coverage..."
	cd app && go test -v -race -coverprofile=coverage.out ./...
	cd app && go tool cover -html=coverage.out -o coverage.html
	@echo "📊 Coverage report: app/coverage.html"

bench: ## Run benchmarks
	@echo "🏃 Running benchmarks..."
	cd app && go test -bench=. -benchmem ./...

lint: ## Run linting (requires golangci-lint)
	@echo "🔍 Running linter..."
	cd app && golangci-lint run

clean: ## Clean build artifacts
	@echo "🧹 Cleaning..."
	rm -rf bin/ app/coverage.out app/coverage.html

# Docker
docker-build: ## Build Docker image
	@echo "🐳 Building Docker image..."
	docker build -t tikky:latest .

docker-load: ## Build and load image into cluster
	@echo "🚀 Building and loading into cluster..."
	./scripts/build-and-load.sh

# Kubernetes
deploy: ## Deploy to Kubernetes
	@echo "☸️  Deploying to Kubernetes..."
	./scripts/deploy.sh

load-test: ## Run load test against deployed service
	@echo "📈 Running load test..."
	./scripts/load-test.sh

# Development workflow
dev: docker-load deploy ## Complete development deployment
	@echo "🎯 Development environment ready!"
	@echo "Test with: curl -X POST http://localhost:8080/write"

# CI/CD pipeline simulation
ci: test lint docker-build ## Run CI pipeline (test, lint, build)
	@echo "✅ CI pipeline completed successfully!"

# Show current status
status: ## Show cluster and deployment status
	@echo "☸️  Cluster Status:"
	kubectl get pods -n tikky-app
	@echo ""
	@echo "🌐 Service Status:"
	kubectl get svc -n tikky-app
	@echo ""
	@echo "📊 Ingress Status:"
	kubectl get ingress -n tikky-app
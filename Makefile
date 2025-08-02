# Nginx HTTP/3 Docker Image Makefile

.PHONY: help build test run stop clean logs shell build-multi

# Default target
help: ## Show this help message
	@echo "Nginx HTTP/3 Docker Image"
	@echo "======================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Docker image
	@echo "Building nginx-saru image..."
	@docker build -t nginx-saru:latest .

build-multi: ## Build multi-platform image (amd64, arm64)
	@echo "Building multi-platform image..."
	@docker buildx build --platform linux/amd64,linux/arm64 -t nginx-saru:latest .

build-no-cache: ## Build without cache
	@echo "Building without cache..."
	@docker build --no-cache -t nginx-saru:latest .

test: ## Run tests
	@echo "Running tests..."
	@docker run --rm nginx-saru:latest nginx -t
	@echo "✓ Configuration test passed"
	@docker run --rm nginx-saru:latest nginx -V 2>&1 | grep -E "(brotli|zstd|geoip|quic)"
	@echo "✓ Modules verified"

run: ## Run the container
	@echo "Starting container..."
	@docker-compose up -d

run-dev: ## Run in development mode
	@echo "Starting in development mode..."
	@docker-compose up

stop: ## Stop the container
	@echo "Stopping container..."
	@docker-compose down

clean: ## Clean up containers and images
	@echo "Cleaning up..."
	@docker-compose down --volumes --remove-orphans
	@docker image prune -f
	@docker volume prune -f

logs: ## Show container logs
	@docker-compose logs -f nginx-saru

shell: ## Access container shell
	@docker-compose exec nginx-saru sh

status: ## Show container status
	@docker-compose ps

setup: ## Initial setup
	@echo "Setting up development environment..."
	@mkdir -p certs html geoip logs
	@echo "Creating self-signed certificates..."
	@docker run --rm -v $(PWD)/certs:/certs alpine:latest sh -c " \
		apk add --no-cache openssl && \
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		  -keyout /certs/server.key -out /certs/server.crt \
		  -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost'"
	@echo "Setup complete!"

lint: ## Lint shell scripts
	@echo "Linting shell scripts..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed"; exit 1; }
	@shellcheck scripts/*.sh

format: ## Format code
	@echo "Formatting nginx configuration..."
	@command -v nginx-config-formatter >/dev/null 2>&1 || { echo "nginx-config-formatter not installed"; exit 1; }
	@nginx-config-formatter nginx/nginx.conf
	@nginx-config-formatter nginx/conf.d/*.conf

update: ## Update dependencies
	@echo "Updating dependencies..."
	@docker pull alpine:3.20
	@echo "Base image updated"

# Development targets
dev: setup run-dev ## Setup and run development environment

prod: build run ## Build and run production image

# CI/CD targets
ci-build: ## Build for CI
	@echo "Building for CI..."
	@./scripts/build.sh --test

ci-test: ## Run CI tests
	@echo "Running CI tests..."
	@docker run --rm nginx-saru:latest nginx -t
	@docker run --rm nginx-saru:latest nginx -V 2>&1 | grep -E "(brotli|zstd|geoip|quic)"
	@echo "All tests passed"

# Release targets
release: build-multi ## Build and tag release
	@echo "Building release..."
	@docker tag nginx-saru:latest nginx-saru:$(shell date +%Y%m%d)
	@echo "Release built: nginx-saru:$(shell date +%Y%m%d)"
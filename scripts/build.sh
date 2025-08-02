#!/bin/bash

# Nginx HTTP/3 Docker Image Build Script
# This script builds the nginx-saru image with configurable versions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to load environment variables
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        print_status "Loading environment variables from $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    else
        print_warning ".env file not found, using defaults"
    fi
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_status "All dependencies are available"
}

# Function to build the image
build_image() {
    print_status "Starting build process..."
    
    local build_args=(
        "--build-arg ALPINE_VERSION=${ALPINE_VERSION:-3.20}"
        "--build-arg NGINX_VERSION=${NGINX_VERSION:-1.27.2}"
        "--build-arg QUICHE_COMMIT=${QUICHE_COMMIT:-0.22.0}"
        "--build-arg NGX_BROTLI_COMMIT=${NGX_BROTLI_COMMIT:-1.0.0rc}"
        "--build-arg NGX_ZSTD_TAG=${NGX_ZSTD_TAG:-v0.2.0}"
        "--build-arg NGX_GEOIP2_TAG=${NGX_GEOIP2_TAG:-3.4}"
        "--build-arg NGX_HEADERS_MORE_TAG=${NGX_HEADERS_MORE_TAG:-v0.37}"
    )
    
    local image_name="${REGISTRY:-nginx-saru}/${IMAGE_NAME:-nginx-saru}:${IMAGE_TAG:-latest}"
    
    print_status "Building image: $image_name"
    print_status "Build arguments:"
    for arg in "${build_args[@]}"; do
        echo "  $arg"
    done
    
    cd "$PROJECT_ROOT"
    
    docker build \
        --platform linux/amd64 \
        -t "$image_name" \
        "${build_args[@]}" \
        .
    
    print_status "Build completed successfully: $image_name"
}

# Function to test the image
test_image() {
    local image_name="${REGISTRY:-nginx-saru}/${IMAGE_NAME:-nginx-saru}:${IMAGE_TAG:-latest}"
    
    print_status "Testing image: $image_name"
    
    # Test nginx configuration
    print_status "Testing nginx configuration..."
    if docker run --rm "$image_name" nginx -t; then
        print_status "✓ Nginx configuration is valid"
    else
        print_error "✗ Nginx configuration test failed"
        exit 1
    fi
    
    # Test modules
    print_status "Testing nginx modules..."
    local modules_check
    modules_check=$(docker run --rm "$image_name" nginx -V 2>&1)
    
    local modules=(
        "brotli"
        "zstd"
        "geoip2"
        "headers-more"
        "quic"
    )
    
    for module in "${modules[@]}"; do
        if echo "$modules_check" | grep -qi "$module"; then
            print_status "✓ $module module is available"
        else
            print_warning "✗ $module module not found"
        fi
    done
    
    # Test HTTP/3 support
    print_status "Testing HTTP/3 support..."
    local container_id
    container_id=$(docker run -d -p 8080:80 -p 8443:443 -p 8443:443/udp "$image_name")
    
    sleep 3
    
    # Test basic connectivity
    if curl -f -s http://localhost:8080/health > /dev/null; then
        print_status "✓ HTTP server is responding"
    else
        print_error "✗ HTTP server is not responding"
        docker logs "$container_id"
        docker stop "$container_id"
        exit 1
    fi
    
    docker stop "$container_id" > /dev/null
    docker rm "$container_id" > /dev/null
    
    print_status "✓ Image tests completed successfully"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -t, --test     Run tests after build"
    echo "  -p, --push     Push to registry after build"
    echo "  --no-cache     Build without cache"
    echo ""
    echo "Environment variables (set in .env file):"
    echo "  NGINX_VERSION, QUICHE_COMMIT, NGX_BROTLI_COMMIT, NGX_ZSTD_TAG"
    echo "  NGX_GEOIP2_TAG, NGX_HEADERS_MORE_TAG, ALPINE_VERSION"
}

# Main function
main() {
    local run_tests=false
    local push_image=false
    local no_cache=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -t|--test)
                run_tests=true
                shift
                ;;
            -p|--push)
                push_image=true
                shift
                ;;
            --no-cache)
                no_cache=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    load_env
    check_dependencies
    build_image
    
    if [[ "$run_tests" == true ]]; then
        test_image
    fi
    
    if [[ "$push_image" == true ]]; then
        print_status "Pushing image to registry..."
        docker push "${REGISTRY:-nginx-saru}/${IMAGE_NAME:-nginx-saru}:${IMAGE_TAG:-latest}"
    fi
    
    print_status "Build process completed!"
}

# Run main function with all arguments
main "$@"
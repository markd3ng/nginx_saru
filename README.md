# Nginx HTTP/3 Docker Image

[![Build and Push Multi-Platform Docker Image](https://github.com/your-username/nginx-saru/actions/workflows/build.yml/badge.svg)](https://github.com/your-username/nginx-saru/actions/workflows/build.yml)
[![Docker Image Size](https://img.shields.io/docker/image-size/your-username/nginx-saru/latest)](https://hub.docker.com/r/your-username/nginx-saru)
[![Docker Pulls](https://img.shields.io/docker/pulls/your-username/nginx-saru)](https://hub.docker.com/r/your-username/nginx-saru)

A lightweight, high-performance Nginx Docker image with HTTP/3 (QUIC) support, featuring Brotli, Zstd compression, GeoIP2, and advanced headers management.

## ✨ Features

- **HTTP/3 & QUIC Support**: Latest HTTP/3 protocol implementation using Cloudflare's quiche
- **Modern Compression**: Brotli, Zstd, and gzip compression for optimal performance
- **GeoIP2 Integration**: Geographic IP detection and blocking capabilities
- **Security Headers**: Advanced security headers via headers-more-nginx-module
- **Multi-Platform**: Supports both `linux/amd64` and `linux/arm64` architectures
- **TLS 1.3**: Latest TLS protocol support
- **Rate Limiting**: Built-in rate limiting capabilities
- **Health Checks**: Ready-to-use health check endpoints
- **Optimized**: Minimal Alpine Linux base with optimized build

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [SSL/HTTPS Setup](#sslhttps-setup)
- [Compression](#compression)
- [GeoIP2](#geoip2)
- [Environment Variables](#environment-variables)
- [Building](#building)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## 🚀 Quick Start

### Using Docker

```bash
# Pull the image
docker pull ghcr.io/your-username/nginx-saru:latest

# Run with default configuration
docker run -d \
  --name nginx-saru \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -v $(pwd)/certs:/etc/nginx/certs:ro \
  -v $(pwd)/html:/var/www/html:ro \
  ghcr.io/your-username/nginx-saru:latest
```

### Using Docker Compose

```bash
# Clone the repository
git clone https://github.com/your-username/nginx-saru.git
cd nginx-saru

# Create SSL certificates (self-signed for testing)
mkdir -p certs html
docker run --rm -v $(pwd)/certs:/certs -v $(pwd)/html:/html \
  alpine:latest sh -c "
    apk add --no-cache openssl &&
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /certs/server.key -out /certs/server.crt \
      -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost'"

# Start services
docker-compose up -d
```

## ⚙️ Configuration

### Environment Variables

Configure your build using environment variables in `.env` file:

```bash
# Base image
ALPINE_VERSION=3.20

# Nginx version (mainline)
NGINX_VERSION=1.27.2

# QUIC/HTTP3 support
QUICHE_COMMIT=0.22.0

# Compression modules
NGX_BROTLI_COMMIT=1.0.0rc
NGX_ZSTD_TAG=v0.2.0

# GeoIP2 module
NGX_GEOIP2_TAG=3.4

# Headers module
NGX_HEADERS_MORE_TAG=v0.37
```

### Volume Mounts

| Path | Description |
|------|-------------|
| `/etc/nginx/nginx.conf` | Main Nginx configuration |
| `/etc/nginx/conf.d/` | Server block configurations |
| `/etc/nginx/certs/` | SSL certificates |
| `/var/log/nginx/` | Nginx logs |
| `/var/www/html/` | Web content |
| `/etc/nginx/geoip/` | GeoIP2 databases |

## 🔒 SSL/HTTPS Setup

### Production SSL Certificates

1. **Let's Encrypt (recommended)**:
   ```bash
   # Using certbot
   docker run --rm -v $(pwd)/certs:/etc/letsencrypt \
     certbot/certbot certonly --standalone \
     -d yourdomain.com -d www.yourdomain.com
   ```

2. **Custom certificates**:
   Place your certificates in the `certs/` directory:
   - `server.crt` - Certificate file
   - `server.key` - Private key file

### Self-signed Certificates (Testing)

```bash
# Generate self-signed certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/server.key -out certs/server.crt \
  -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost'
```

## 🗜️ Compression

### Supported Algorithms

1. **Brotli** (br): Modern compression algorithm, better than gzip
2. **Zstd** (zstd): Fast compression with good ratio
3. **Gzip** (gzip): Legacy support

### Configuration Example

```nginx
# Enable all compression methods
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css application/javascript;

zstd on;
zstd_comp_level 6;
zstd_types text/plain text/css application/javascript;

gzip on;
gzip_comp_level 6;
gzip_types text/plain text/css application/javascript;
```

### Client Support

| Algorithm | Browser Support |
|-----------|-----------------|
| Brotli | Chrome 49+, Firefox 44+, Safari 11+ |
| Zstd | Chrome 123+, Firefox 126+ |
| Gzip | Universal |

## 🌍 GeoIP2

### Setup

1. **Get MaxMind account**:
   - Create account at [MaxMind](https://www.maxmind.com)
   - Generate license key

2. **Configure GeoIP updater**:
   ```bash
   # Set environment variables
   export GEOIPUPDATE_ACCOUNT_ID=your_account_id
   export GEOIPUPDATE_LICENSE_KEY=your_license_key
   
   # Run with geoip profile
   docker-compose --profile geoip up -d
   ```

### Usage Examples

```nginx
# Block specific countries
if ($geoip2_data_country_code = CN) {
    return 403;
}

# Redirect based on country
if ($geoip2_data_country_code = US) {
    return 301 https://us.example.com$request_uri;
}

# Add country header
add_header X-Country $geoip2_data_country_code always;
```

## 🧪 Testing

### Manual Testing

```bash
# Build and test locally
./scripts/build.sh --test

# Test HTTP/3 support
curl -I --http3 https://localhost:8443/

# Test compression
curl -H "Accept-Encoding: br" -I https://localhost:8443/
curl -H "Accept-Encoding: zstd" -I https://localhost:8443/

# Test rate limiting
for i in {1..20}; do curl -s http://localhost:8080/api/test; done
```

### Automated Testing

```bash
# Run full test suite
docker-compose up -d
docker exec nginx-saru nginx -t

# Check modules
docker exec nginx-saru nginx -V 2>&1 | grep -E "(brotli|zstd|geoip|quic)"
```

## 🔧 Building

### Local Build

```bash
# Simple build
./scripts/build.sh

# Build with custom versions
NGINX_VERSION=1.27.1 ./scripts/build.sh

# Build and test
./scripts/build.sh --test

# Build without cache
./scripts/build.sh --no-cache
```

### GitHub Actions

The repository includes automated GitHub Actions workflows:

- **Multi-platform builds** (amd64, arm64)
- **Automated testing**
- **Registry publishing** (GHCR)
- **Manual triggers** with custom parameters

### Manual Build with Docker

```bash
# Build single platform
docker build \
  --build-arg NGINX_VERSION=1.27.2 \
  --build-arg QUICHE_COMMIT=0.22.0 \
  -t nginx-saru:latest .

# Build multi-platform
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push -t ghcr.io/your-username/nginx-saru:latest .
```

## 📊 Monitoring

### Health Checks

The image includes built-in health checks:

```bash
# Check container health
docker-compose ps

# Manual health check
curl -f http://localhost:8080/health
```

### Logs

```bash
# View logs
docker-compose logs -f nginx-saru

# Structured logging
# Logs include: request_time, upstream_response_time, country_code, etc.
```

## 🛡️ Security

### Security Headers

The image includes pre-configured security headers:

- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- `Referrer-Policy: strict-origin-when-cross-origin`

### Rate Limiting

Built-in rate limiting zones:

- `api`: 10 requests/second
- `login`: 1 request/second

### Security Best Practices

1. **Keep images updated**: Regularly pull latest security updates
2. **Use specific tags**: Avoid `latest` in production
3. **Scan images**: Use `docker scan` or similar tools
4. **Limit privileges**: Run with non-root user (already configured)
5. **Monitor logs**: Watch for suspicious activity

## 🔄 CI/CD

### GitHub Actions Features

- **Matrix builds**: Multiple platforms and versions
- **Caching**: Layer caching for faster builds
- **Security scanning**: Automated vulnerability scanning
- **Registry publishing**: Automatic publishing to GHCR

### Custom Build Triggers

```yaml
# Manual trigger with parameters
workflow_dispatch:
  inputs:
    nginx_version:
      description: 'Nginx version'
      default: '1.27.2'
    quiche_commit:
      description: 'Quiche commit/tag'
      default: '0.22.0'
```

## 📝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open Pull Request**

### Development Setup

```bash
# Clone and setup
git clone https://github.com/your-username/nginx-saru.git
cd nginx-saru

# Create development environment
make dev

# Run tests
make test
```

### Code Style

- **Shell scripts**: Use `shellcheck` for linting
- **Dockerfiles**: Follow best practices
- **Nginx configs**: Use consistent indentation (4 spaces)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Nginx](https://nginx.org) - The amazing web server
- [Cloudflare Quiche](https://github.com/cloudflare/quiche) - HTTP/3 implementation
- [MaxMind](https://www.maxmind.com) - GeoIP2 databases
- [OpenResty](https://openresty.org) - Headers-more module
- [Alpine Linux](https://alpinelinux.org) - Lightweight base image

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-username/nginx-saru/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/nginx-saru/discussions)
- **Documentation**: [Wiki](https://github.com/your-username/nginx-saru/wiki)

---

**Made with ❤️ for the modern web**

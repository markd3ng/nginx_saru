# syntax=docker/dockerfile:1
ARG ALPINE_VERSION=3.20
FROM alpine:${ALPINE_VERSION} AS build-stage

ARG NGINX_VERSION=1.27.2
ARG QUICHE_VERSION=0.22.0
ARG NGX_BROTLI_VERSION=1.0.0rc
ARG NGX_ZSTD_VERSION=v0.2.0
ARG NGX_GEOIP2_VERSION=3.4
ARG NGX_HEADERS_MORE_VERSION=v0.37

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    cmake \
    curl \
    git \
    libmaxminddb-dev \
    linux-headers \
    pcre-dev \
    zlib-dev \
    zstd-dev \
    brotli-dev \
    perl-dev \
    mercurial \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && source ~/.cargo/env

WORKDIR /src

# Download and build quiche
RUN curl -fSL https://github.com/cloudflare/quiche/archive/refs/tags/${QUICHE_VERSION}.tar.gz -o quiche.tar.gz && \
    tar -zxC /src -f quiche.tar.gz && \
    mv "quiche-${QUICHE_VERSION}" quiche && \
    cd quiche && \
    export PATH="$HOME/.cargo/bin:$PATH" && \
    cargo build --release --no-default-features --features ffi,openssl --verbose

# Download nginx
RUN curl -fSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -o nginx.tar.gz && \
    tar -zxC /src -f nginx.tar.gz && \
    mv "nginx-${NGINX_VERSION}" nginx

# Download modules
RUN curl -fSL "https://github.com/google/ngx_brotli/archive/refs/tags/${NGX_BROTLI_VERSION}.tar.gz" -o ngx_brotli.tar.gz && \
    tar -zxC /src -f ngx_brotli.tar.gz && \
    mv "ngx_brotli-${NGX_BROTLI_VERSION}" ngx_brotli && \
    rm ngx_brotli.tar.gz && \
    cd ngx_brotli && \
    curl -fSL "https://github.com/google/brotli/archive/refs/heads/master.tar.gz" -o brotli.tar.gz && \
    tar -zxC deps -f brotli.tar.gz && \
    mv deps/brotli-* deps/brotli && \
    rm brotli.tar.gz

RUN curl -fSL "https://github.com/tokers/ngx_http_zstd_filter_module/archive/refs/tags/${NGX_ZSTD_VERSION}.tar.gz" -o ngx_zstd.tar.gz && \
    tar -zxC /src -f ngx_zstd.tar.gz && \
    mv "ngx_http_zstd_filter_module-${NGX_ZSTD_VERSION#v}" ngx_http_zstd_filter_module && \
    rm ngx_zstd.tar.gz

RUN curl -fSL "https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/${NGX_GEOIP2_VERSION}.tar.gz" -o ngx_geoip2.tar.gz && \
    tar -zxC /src -f ngx_geoip2.tar.gz && \
    mv "ngx_http_geoip2_module-${NGX_GEOIP2_VERSION}" ngx_http_geoip2_module && \
    rm ngx_geoip2.tar.gz

RUN curl -fSL "https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/${NGX_HEADERS_MORE_VERSION}.tar.gz" -o headers_more.tar.gz && \
    tar -zxC /src -f headers_more.tar.gz && \
    mv "headers-more-nginx-module-${NGX_HEADERS_MORE_VERSION#v}" headers-more-nginx-module && \
    rm headers_more.tar.gz

# Configure and build nginx
WORKDIR /src/nginx

RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-perl_modules_path=/usr/lib/perl5/vendor_perl \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_perl_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-threads \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-stream_ssl_preread_module \
    --add-module=../quiche/nginx \
    --add-module=../ngx_brotli \
    --add-module=../ngx_http_zstd_filter_module \
    --add-module=../ngx_http_geoip2_module \
    --add-module=../headers-more-nginx-module \
    --with-cc-opt="-I../quiche/include -I../quiche/deps/boringssl/include" \
    --with-ld-opt="-L../quiche/target/release -Wl,-rpath,/usr/local/lib" \
    --with-openssl=../quiche/deps/boringssl \
    --with-quiche=../quiche \
    --with-http_quic_module \
    --with-stream_quic_module \
    --with-debug \
    --with-pcre-jit \
    --with-zlib-opt="--with-zlib=../quiche/deps/zlib" \
    && make -j$(nproc) \
    && make install

# Production stage
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache \
    brotli-libs \
    ca-certificates \
    libmaxminddb \
    pcre \
    zlib \
    zstd-libs \
    tzdata \
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

COPY --from=build-stage /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build-stage /etc/nginx /etc/nginx
COPY --from=build-stage /usr/lib/nginx/modules /usr/lib/nginx/modules

RUN mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp \
    /var/log/nginx \
    /var/www/html \
    /etc/nginx/certs \
    && chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/www/html /etc/nginx/certs

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/

EXPOSE 80 443 443/udp

STOPSIGNAL SIGQUIT

USER nginx

CMD ["nginx", "-g", "daemon off;"]
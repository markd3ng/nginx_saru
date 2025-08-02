# 🛠️ 项目目标：构建精简高性能的 Nginx HTTP/3 镜像

## 🔧 项目背景

官方 Nginx 镜像体积大、功能有限，缺乏 Brotli/Zstd 压缩、TLS1.3/QUIC、GeoIP2 等现代化模块支持。

因此，本项目旨在自定义构建一套高度精简的 Nginx 镜像，内置多个实用第三方模块，适合部署在需要低延迟、强 TLS 支持的服务端环境中（如边缘代理、反代前置网关）。

## 🎯 构建要求

请使用 GitHub Action 编排以下构建流程，并输出多平台 Docker 镜像（支持 `linux/amd64` 和 `linux/arm64`）：

- 基于 Alpine 最小镜像构建
- 镜像命名规范支持带 `latest` 和特定 `版本号` 的标签
- CI 支持手动触发并通过 `build-args` 控制组件版本
- 最终镜像支持 HTTP/3（QUIC）、TLS1.3、gzip、brotli、zstd 压缩

## 🧩 集成模块

请从以下 GitHub 仓库拉取模块源码，使用 NGINX 源码编译方式合并：

| 功能         | 模块名称                                  | 地址 |
|--------------|--------------------------------------------|------|
| Brotli 压缩   | `ngx_brotli`                              | https://github.com/google/ngx_brotli |
| Zstd 压缩     | `ngx_http_zstd_filter_module`             | https://github.com/tokers/ngx_http_zstd_filter_module |
| TLS/QUIC 支持 | `quiche`（替代 OpenSSL）                  | https://github.com/cloudflare/quiche |
| GeoIP2 支持   | `ngx_http_geoip2_module`                  | https://github.com/leev/ngx_http_geoip2_module |
| Header 管理   | `headers-more-nginx-module`               | https://github.com/openresty/headers-more-nginx-module |

## 📦 组件版本策略

- **Nginx**：始终使用最新的 mainline 版本（如 `1.27.x`），获取方式来自官方 [nginx.org/download](https://nginx.org/en/download.html)
- **OpenSSL**：如非使用 quiche，自行构建并使用其 GitHub Release 中最新版本（如 `3.3.1`），以规避已知漏洞
- **其他模块**：请使用各自 GitHub Release 中的最新 **stable tag**，不要直接 clone `main` 分支
- **版本统一方式**：使用 `.env` 或 GitHub Actions `inputs` 提供如下构建参数：

```env
NGINX_VERSION=1.27.0
QUICHE_COMMIT=xxx123
ZSTD_MODULE_TAG=v0.2.0
```

## 🏗️ 项目目录结构

请构建以下目录与配置文件：

```
project-root/
├── Dockerfile
├── .github/
│   └── workflows/
│       └── build.yml          # CI 构建与推送逻辑
├── nginx/
│   ├── nginx.conf             # 主配置文件，包含 HTTP3 配置示例
│   └── conf.d/
│       └── default.conf       # 默认虚拟主机配置（listen 443 http3）
├── scripts/
│   └── build.sh               # 本地构建入口（可选）
├── README.md
└── .env.example
```

## 🔌 可选功能扩展建议

请在设计构建逻辑时预留可选拓展功能支持：

- 启用 `stub_status`（用于 metrics 拉取）监听 `/nginx_status`
- 支持访问日志、错误日志路径挂载
- 可扩展添加 `modsecurity`、`lua-nginx-module`（预留后续场景）

## 🔐 HTTPS 配置与证书管理

默认配置应使用 ACME（推荐使用 `acme.sh`）生成证书，证书通过挂载方式引入，建议路径为：

```yaml
volumes:
  - ./certs:/etc/nginx/certs
```

nginx.conf 示例中应包含自动检测 cert/key 是否存在的配置。

## 🧪 构建验证 Checklist

- [ ] `nginx -V` 输出中包含所有内建模块
- [ ] `curl -I --http3 https://domain.com` 测试成功返回
- [ ] 启用 Brotli、Zstd gzip 时，`Content-Encoding` 正确切换
- [ ] 镜像体积控制在 < 60MB（目标）

## 🚀 镜像推送与版本管理

镜像将被推送至 DockerHub 或 GHCR，地址由用户在使用 Trae 时指定，格式支持：

- `username/nginx-h3:latest`
- `username/nginx-h3:1.27.0`

## 📝 README.md 建议内容结构

最终生成的 README.md 建议包含：

1. 项目简介与特性
2. 使用方式（包含 `docker run` 与 `docker-compose` 示例）
3. 构建方式（GitHub Actions 与本地 build.sh）
4. 组件版本说明
5. 测试与验证指南
6. 许可证与参考链接

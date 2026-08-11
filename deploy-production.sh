#!/bin/bash
# ========================================
# Billd-Live 生产环境部署脚本
# 适用于阿里云 ECS (CentOS/Ubuntu)
# ========================================

set -e

echo "========================================="
echo "  Billd-Live 直播系统部署脚本"
echo "========================================="

# 配置变量
PROJECT_DIR="/opt/billd-live"
GIT_REPO="https://github.com/zhuangxushen-hash/billd-live.git"
SERVER_DOMAIN="8.130.113.130"  # 先用IP，后续可配置域名
ADMIN_DOMAIN="8.130.113.130"

# ========== Step 1: 检查系统环境 ==========
echo ""
echo "[Step 1] 检查系统环境..."
echo "操作系统: $(cat /etc/os-release 2>/dev/null || cat /etc/issue 2>/dev/null)"
echo "内核版本: $(uname -r)"
echo "CPU核心数: $(nproc)"
echo "内存大小: $(free -h | awk '/Mem:/ {print $2}')"
echo "磁盘空间: $(df -h / | awk 'NR==2 {print $4}') 可用"

# ========== Step 2: 安装 Docker ==========
echo ""
echo "[Step 2] 检查/安装 Docker..."

if command -v docker &> /dev/null; then
    echo "Docker 已安装: $(docker --version)"
else
    echo "安装 Docker..."
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update -qq
        apt-get install -y -qq ca-certificates curl gnupg lsb-release
        
        # 添加 Docker 官方 GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # 添加 Docker 仓库
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable docker
        systemctl start docker
    fi
    
    echo "Docker 安装完成: $(docker --version)"
fi

# 检查 Docker Compose (v2 以插件形式存在)
if docker compose version &> /dev/null; then
    echo "Docker Compose 已安装: $(docker compose version)"
else
    echo "警告: Docker Compose 插件未安装"
fi

# ========== Step 3: 克隆代码 ==========
echo ""
echo "[Step 3] 克隆项目代码..."

if [ -d "$PROJECT_DIR" ]; then
    echo "项目目录已存在，拉取最新代码..."
    cd "$PROJECT_DIR"
    git fetch origin main
    git reset --hard origin/main
else
    echo "克隆项目到 $PROJECT_DIR..."
    git clone "$GIT_REPO" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

echo "代码已准备: $(ls -la)"

# ========== Step 4: 创建必要目录 ==========
echo ""
echo "[Step 4] 创建数据目录..."

mkdir -p data/server
mkdir -p data/videos
mkdir -p data/uploads
mkdir -p data/popups
mkdir -p data/srs/log
mkdir -p data/srs/objs
mkdir -p logs
mkdir -p backups
mkdir -p deploy/nginx/cache
mkdir -p deploy/nginx/logs
mkdir -p deploy/ssl

echo "目录创建完成"

# ========== Step 5: 配置环境变量 ==========
echo ""
echo "[Step 5] 配置生产环境变量..."

# 生成 JWT Secret
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || cat /proc/sys/kernel/random/uuid)
SESSION_SECRET=$(openssl rand -hex 32 2>/dev/null || cat /proc/sys/kernel/random/uuid)

# 更新 .env.production
cat > live-server/.env.production << EOF
# 服务器配置
SERVER_DOMAIN=${SERVER_DOMAIN}
ADMIN_DOMAIN=${ADMIN_DOMAIN}
SERVER_IP=0.0.0.0

# 后端服务
BACKEND_PORT=3000
JWT_SECRET=${JWT_SECRET}
BCRYPT_SALT_ROUNDS=10
SESSION_SECRET=${SESSION_SECRET}

# SRS 流媒体
SRS_HOST=live-srs
SRS_RTMP_PORT=1935
SRS_HTTP_PORT=8080
SRS_HTTPS_PORT=19350

# 数据库 (使用 JSON 存储)
DB_TYPE=json

# 文件存储
MAX_FILE_SIZE=500
VIDEO_PATH=/app/videos
POPUP_PATH=/app/popups

# 日志
LOG_LEVEL=info
LOG_PATH=/app/logs

# 安全配置
ENABLE_HTTPS=false
ENABLE_RATE_LIMIT=true
RATE_LIMIT_MAX=100
ENABLE_STREAM_AUTH=true

# 备份配置
ENABLE_BACKUP=true
BACKUP_PATH=/app/backups
BACKUP_RETENTION_DAYS=30
EOF

echo "环境变量配置完成"

# ========== Step 6: 配置 Nginx ==========
echo ""
echo "[Step 6] 配置 Nginx..."

# 使用 docker-compose.prod.yml，但修改为使用 IP 而非域名
cat > deploy/nginx/nginx.prod.conf << 'NGINXEOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main buffer=32k flush=5s;

    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types
        text/plain text/css application/json application/javascript
        application/xml image/svg+xml font/truetype font/opentype;

    # 速率限制
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=1r/s;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    server_tokens off;

    # HTTP 服务器 (使用 IP 访问)
    server {
        listen 80;
        server_name _;

        # HTTP-FLV 直播流代理
        location /live/ {
            proxy_pass http://live-srs:8080/live/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;

            add_header Access-Control-Allow-Origin * always;
        }

        # HLS 流代理
        location /hls/ {
            proxy_pass http://live-srs:8080/live/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_buffering on;
            proxy_read_timeout 60s;

            add_header Access-Control-Allow-Origin * always;
            add_header Cache-Control "public, max-age=10" always;
        }

        # API 接口代理
        location /api/ {
            proxy_pass http://live-server:3000;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            
            # WebSocket 支持
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            proxy_read_timeout 300s;
            proxy_connect_timeout 75s;
            
            limit_req zone=api_limit burst=30 nodelay;
        }

        # WebSocket
        location /ws/ {
            proxy_pass http://live-server:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
        }

        # 客户端
        location / {
            proxy_pass http://live-client:80;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            
            try_files $uri $uri/ /index.html;
            limit_req zone=api_limit burst=20 nodelay;
        }

        # 管理后台
        location /admin/ {
            proxy_pass http://live-admin:80/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            
            try_files $uri $uri/ /index.html;
            limit_req zone=api_limit burst=10 nodelay;
        }

        # 健康检查
        location /health {
            access_log off;
            return 200 'OK';
            add_header Content-Type text/plain;
        }
    }
}
NGINXEOF

echo "Nginx 配置完成"

# ========== Step 7: 修改 Docker Compose 配置 ==========
echo ""
echo "[Step 7] 配置 Docker Compose..."

# 修改 docker-compose.prod.yml 使用 HTTP 而非 HTTPS
cat > docker-compose.prod.yml << 'COMPOSEEOF'
version: '3.8'

x-production-config: &production-config
  restart: unless-stopped
  logging:
    driver: json-file
    options:
      max-size: "100m"
      max-file: "3"

services:
  # SRS 流媒体服务器
  live-srs:
    image: ossrs/srs:5
    container_name: live-srs
    <<: *production-config
    ports:
      - "1935:1935"
      - "19350:19350"
    volumes:
      - ./deploy/srs/conf.srs:/usr/local/srs/conf/srs.conf:ro
      - ./data/srs/log:/usr/local/srs/log
      - ./data/srs/objs:/usr/local/srs/objs
    networks:
      - live-network
    healthcheck:
      test: ["CMD", "/usr/local/srs/bin/srs", "-t"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'

  # 后端服务
  live-server:
    build:
      context: ./live-server
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
    container_name: live-server
    <<: *production-config
    env_file:
      - ./live-server/.env.production
    ports:
      - "3000:3000"
    volumes:
      - ./data/server:/app/data
      - ./data/videos:/app/videos
      - ./data/uploads:/app/uploads
      - ./data/popups:/app/popups
      - ./logs:/app/logs
      - ./backups:/app/backups
    environment:
      - NODE_ENV=production
      - SRS_HOST=live-srs
      - JWT_SECRET=${JWT_SECRET}
      - SESSION_SECRET=${SESSION_SECRET}
    depends_on:
      live-srs:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/api/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1))"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
    networks:
      - live-network
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '2.0'
        reservations:
          memory: 512M
          cpus: '1.0'

  # 前端客户端
  live-client:
    build:
      context: ./live-client
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
        - VITE_API_BASE_URL=http://localhost
        - VITE_SRS_URL=http://localhost
    container_name: live-client
    <<: *production-config
    depends_on:
      - live-server
    networks:
      - live-network

  # 管理后台
  live-admin:
    build:
      context: ./live-admin
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
        - VITE_API_BASE_URL=http://localhost
    container_name: live-admin
    <<: *production-config
    depends_on:
      - live-server
    networks:
      - live-network

  # Nginx 网关
  live-gateway:
    image: nginx:alpine
    container_name: live-gateway
    <<: *production-config
    ports:
      - "80:80"
    volumes:
      - ./deploy/nginx/nginx.prod.conf:/etc/nginx/conf.d/default.conf:ro
      - ./deploy/nginx/cache:/var/cache/nginx
      - ./deploy/nginx/logs:/var/log/nginx
    depends_on:
      live-client:
        condition: service_started
      live-admin:
        condition: service_started
      live-srs:
        condition: service_healthy
    networks:
      - live-network
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
        reservations:
          memory: 128M
          cpus: '0.25'

  # 数据库备份服务
  live-backup:
    image: alpine:latest
    container_name: live-backup
    <<: *production-config
    volumes:
      - ./data/server:/app/data:ro
      - ./backups:/backups
    environment:
      - BACKUP_RETENTION_DAYS=30
    entrypoint: >
      sh -c '
        while true; do
          echo "[$(date)] 开始备份..."
          tar czf /backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /app data/
          find /backups -name "backup_*.tar.gz" -mtime +30 -delete
          echo "[$(date)] 备份完成"
          sleep 86400
        done
      '
    networks:
      - live-network

networks:
  live-network:
    driver: bridge

volumes:
  default:
    driver: local
COMPOSEEOF

echo "Docker Compose 配置完成"

# ========== Step 8: 构建并启动服务 ==========
echo ""
echo "[Step 8] 构建并启动服务..."

cd "$PROJECT_DIR"

echo "开始构建镜像（这可能需要几分钟）..."
docker compose -f docker-compose.prod.yml build

echo "启动服务..."
docker compose -f docker-compose.prod.yml up -d

echo ""
echo "等待服务启动..."
sleep 10

# ========== Step 9: 检查服务状态 ==========
echo ""
echo "[Step 9] 检查服务状态..."

echo ""
echo "容器状态:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo "健康检查:"
curl -s http://localhost/health || echo "健康检查接口暂无响应"

echo ""
echo "API 健康检查:"
curl -s http://localhost:3000/api/health || echo "API 暂无响应"

# ========== 完成 ==========
echo ""
echo "========================================="
echo "  部署完成！"
echo "========================================="
echo ""
echo "访问地址:"
echo "  客户端: http://${SERVER_DOMAIN}/"
echo "  管理后台: http://${SERVER_DOMAIN}/admin/"
echo "  直播流: http://${SERVER_DOMAIN}/live/"
echo ""
echo "常用命令:"
echo "  查看服务状态: docker compose -f docker-compose.prod.yml ps"
echo "  查看日志: docker compose -f docker-compose.prod.yml logs -f"
echo "  停止服务: docker compose -f docker-compose.prod.yml down"
echo "  重启服务: docker compose -f docker-compose.prod.yml restart"
echo ""
echo "注意:"
echo "  1. 首次登录管理后台请使用默认账号 admin / 123456"
echo "  2. 登录后请立即修改密码"
echo "  3. 生产环境建议配置 HTTPS 和域名"
echo "========================================="
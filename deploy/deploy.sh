#!/bin/bash

# ============================================
# 直播系统部署脚本
# 适用于阿里云 ECS 服务器
# ============================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN="zhibo.gdwkls.com"
ADMIN_DOMAIN="admin.zhibo.gdwkls.com"

echo -e "${GREEN}=== 直播系统部署脚本 ===${NC}"
echo ""

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}警告: 建议使用 root 用户运行此脚本${NC}"
fi

# 检查操作系统
if [ -f /etc/os-release ]; then
    OS=$(cat /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')
    echo "检测到操作系统: $OS"
else
    echo -e "${RED}无法检测操作系统${NC}"
    exit 1
fi

# ========== 第一步: 安装 Docker ==========
echo -e "${GREEN}[1/6] 检查 Docker 环境${NC}"

if command -v docker &> /dev/null; then
    echo "Docker 已安装: $(docker --version)"
else
    echo "正在安装 Docker..."
    
    if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"RHEL"* ]] || [[ "$OS" == *"Alibaba"* ]]; then
        # CentOS/Alibaba Cloud Linux
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]] || [[ "$OS" == *"Kylin"* ]]; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        echo -e "${RED}不支持的操作系统${NC}"
        exit 1
    fi
    
    # 启动 Docker
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}Docker 安装完成${NC}"
fi

# 检查 Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo "Docker Compose 已安装"
else
    echo -e "${RED}请手动安装 Docker Compose${NC}"
    exit 1
fi

# ========== 第二步: 配置域名解析 ==========
echo -e "${GREEN}[2/6] 检查域名解析${NC}"

echo "请确保以下域名已解析到服务器 IP:"
echo "  - $DOMAIN (客户端)"
echo "  - $ADMIN_DOMAIN (管理后台)"
echo ""
read -p "服务器公网 IP: " SERVER_IP

# ========== 第三步: 配置 SSL 证书 ==========
echo -e "${GREEN}[3/6] 配置 SSL 证书${NC}"

SSL_DIR="$PROJECT_DIR/deploy/ssl"
mkdir -p "$SSL_DIR"

if [ -f "$SSL_DIR/$DOMAIN.pem" ] && [ -f "$SSL_DIR/$DOMAIN.key" ]; then
    echo "SSL 证书已存在"
else
    echo ""
    echo "SSL 证书不存在，有以下几种获取方式:"
    echo "  1. Let's Encrypt 免费证书（推荐）"
    echo "  2. 阿里云 SSL 证书服务"
    echo "  3. 其他 CA 机构购买"
    echo ""
    
    read -p "是否需要自动申请 Let's Encrypt 证书？(y/n): " AUTO_SSL
    
    if [ "$AUTO_SSL" = "y" ]; then
        # 安装 certbot
        if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"RHEL"* ]] || [[ "$OS" == *"Alibaba"* ]]; then
            yum install -y certbot
        elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            apt-get install -y certbot
        fi
        
        # 申请证书
        certbot certonly --standalone \
            -d "$DOMAIN" \
            -d "$ADMIN_DOMAIN" \
            --agree-tos \
            --non-interactive \
            --email "admin@$DOMAIN"
        
        # 复制证书
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
        if [ -f "$CERT_PATH/fullchain.pem" ]; then
            cp "$CERT_PATH/fullchain.pem" "$SSL_DIR/$DOMAIN.pem"
            cp "$CERT_PATH/privkey.pem" "$SSL_DIR/$DOMAIN.key"
            chmod 644 "$SSL_DIR/$DOMAIN.pem"
            chmod 600 "$SSL_DIR/$DOMAIN.key"
            echo -e "${GREEN}SSL 证书申请成功${NC}"
        else
            echo -e "${RED}SSL 证书申请失败，请手动配置${NC}"
            exit 1
        fi
    else
        echo "请手动放置 SSL 证书文件到 $SSL_DIR 目录:"
        echo "  - $DOMAIN.pem"
        echo "  - $DOMAIN.key"
        exit 1
    fi
fi

# ========== 第四步: 创建数据目录 ==========
echo -e "${GREEN}[4/6] 创建数据目录${NC}"

DATA_DIR="$PROJECT_DIR/data"
mkdir -p "$DATA_DIR"/{videos,uploads,config}
chmod -R 755 "$DATA_DIR"

# ========== 第五步: 构建和启动服务 ==========
echo -e "${GREEN}[5/6] 构建和启动服务${NC}"

cd "$PROJECT_DIR"

echo "正在拉取/构建 Docker 镜像..."
docker compose build --no-cache

echo "正在启动服务..."
docker compose up -d

# ========== 第六步: 验证 ==========
echo -e "${GREEN}[6/6] 验证部署${NC}"

sleep 5

echo ""
echo "检查服务状态..."
docker compose ps

echo ""
echo -e "${GREEN}=== 部署完成 ===${NC}"
echo ""
echo "访问地址:"
echo -e "  客户端: ${YELLOW}https://$DOMAIN${NC}"
echo -e "  管理后台: ${YELLOW}https://$ADMIN_DOMAIN${NC}"
echo ""
echo "常用命令:"
echo "  查看日志: docker compose logs -f"
echo "  重启服务: docker compose restart"
echo "  停止服务: docker compose down"
echo "  更新部署: docker compose up -d --build"

#!/bin/bash
# ========================================
# SSL 证书生成脚本
# 支持 Let's Encrypt 自动签发或自签名证书
# ========================================

set -e

# 配置变量
CERT_DIR="./deploy/ssl"
DOMAIN=""
ADMIN_DOMAIN=""
USE_LETSENCRYPT=false
EMAIL=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 打印帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -d, --domain <域名>          主域名（如: example.com）"
    echo "  -a, --admin-domain <域名>    管理后台域名（如: admin.example.com）"
    echo "  -e, --email <邮箱>           邮箱地址（用于 Let's Encrypt）"
    echo "  -l, --letsencrypt            使用 Let's Encrypt 自动签发"
    echo "  -s, --self-signed            生成自签名证书（仅用于测试）"
    echo "  -h, --help                   显示帮助信息"
    echo ""
    echo "示例:"
    echo "  # 使用 Let's Encrypt"
    echo "  $0 -d example.com -a admin.example.com -e admin@example.com -l"
    echo ""
    echo "  # 生成自签名证书"
    echo "  $0 -d example.com -a admin.example.com -s"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -a|--admin-domain)
            ADMIN_DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -l|--letsencrypt)
            USE_LETSENCRYPT=true
            shift
            ;;
        -s|--self-signed)
            USE_LETSENCRYPT=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 检查必要参数
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}错误: 请指定主域名${NC}"
    show_help
    exit 1
fi

if [ "$USE_LETSENCRYPT" = true ] && [ -z "$EMAIL" ]; then
    echo -e "${RED}错误: 使用 Let's Encrypt 需要指定邮箱${NC}"
    show_help
    exit 1
fi

# 默认管理域名
if [ -z "$ADMIN_DOMAIN" ]; then
    ADMIN_DOMAIN="admin.${DOMAIN}"
fi

# 创建证书目录
mkdir -p "$CERT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  直播系统 SSL 证书生成${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "主域名: $DOMAIN"
echo "管理域名: $ADMIN_DOMAIN"
echo "证书目录: $CERT_DIR"
echo ""

# ========== 自签名证书 ==========
generate_self_signed() {
    echo -e "${YELLOW}生成自签名证书（仅用于测试环境）${NC}"
    echo ""

    # 生成主域名证书
    echo -n "生成 $DOMAIN 证书..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/${DOMAIN}.key" \
        -out "$CERT_DIR/${DOMAIN}.pem" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=BilldLive/CN=${DOMAIN}" \
        -addext "subjectAltName=DNS:${DOMAIN},DNS:www.${DOMAIN}" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e " ${GREEN}成功${NC}"
    else
        echo -e " ${RED}失败${NC}"
        exit 1
    fi

    # 生成管理后台证书
    echo -n "生成 $ADMIN_DOMAIN 证书..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/${ADMIN_DOMAIN}.key" \
        -out "$CERT_DIR/${ADMIN_DOMAIN}.pem" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=BilldLive/CN=${ADMIN_DOMAIN}" \
        -addext "subjectAltName=DNS:${ADMIN_DOMAIN}" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e " ${GREEN}成功${NC}"
    else
        echo -e " ${RED}失败${NC}"
        exit 1
    fi

    # 创建链证书副本
    cp "$CERT_DIR/${DOMAIN}.pem" "$CERT_DIR/chain.pem"

    echo ""
    echo -e "${GREEN}自签名证书生成完成！${NC}"
    echo ""
    echo "证书位置:"
    echo "  主域名: $CERT_DIR/${DOMAIN}.pem"
    echo "  管理域名: $CERT_DIR/${ADMIN_DOMAIN}.pem"
    echo ""
    echo -e "${YELLOW}注意: 自签名证书会导致浏览器警告，生产环境请使用 Let's Encrypt${NC}"
}

# ========== Let's Encrypt 证书 ==========
generate_letsencrypt() {
    echo -e "${YELLOW}使用 Let's Encrypt 自动签发证书${NC}"
    echo ""

    # 检查 certbot 是否安装
    if ! command -v certbot &> /dev/null; then
        echo -e "${YELLOW}安装 certbot...${NC}"
        
        # 根据系统类型安装
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case $ID in
                ubuntu|debian)
                    apt-get update -qq && apt-get install -y -qq certbot python3-certbot-nginx
                    ;;
                centos|rhel|fedora|almalinux)
                    yum install -y certbot python3-certbot-nginx
                    ;;
                *)
                    echo -e "${RED}不支持的操作系统${NC}"
                    exit 1
                    ;;
            esac
        else
            echo -e "${RED}无法检测操作系统类型${NC}"
            exit 1
        fi
    fi

    # 确保 Nginx 配置包含 Let's Encrypt 验证路径
    mkdir -p /var/www/certbot

    # 使用 certbot 生成证书
    echo -e "${YELLOW}开始签发证书...${NC}"

    # 停止 Nginx（如果正在运行）
    if docker ps | grep -q live-gateway; then
        echo "临时停止 Nginx 容器..."
        docker stop live-gateway 2>/dev/null || true
    fi

    # 签发证书
    certbot certonly \
        --standalone \
        -d "$DOMAIN" \
        -d "$ADMIN_DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        --cert-path "$CERT_DIR"

    if [ $? -ne 0 ]; then
        echo -e "${RED}证书签发失败${NC}"
        echo "请检查:"
        echo "  1. 域名 DNS 是否已指向本服务器"
        echo "  2. 80 端口是否开放"
        echo "  3. 防火墙是否阻止了 80 端口"
        exit 1
    fi

    # 复制证书到指定目录
    CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"
    
    if [ -f "$CERT_PATH/fullchain.pem" ]; then
        cp "$CERT_PATH/fullchain.pem" "$CERT_DIR/${DOMAIN}.pem"
        cp "$CERT_PATH/privkey.pem" "$CERT_DIR/${DOMAIN}.key"
        
        # 如果 admin 域名也有证书
        ADMIN_CERT_PATH="/etc/letsencrypt/live/${ADMIN_DOMAIN}"
        if [ -f "$ADMIN_CERT_PATH/fullchain.pem" ]; then
            cp "$ADMIN_CERT_PATH/fullchain.pem" "$CERT_DIR/${ADMIN_DOMAIN}.pem"
            cp "$ADMIN_CERT_PATH/privkey.pem" "$CERT_DIR/${ADMIN_DOMAIN}.key"
        else
            # 使用主域名证书作为管理域名证书
            cp "$CERT_PATH/fullchain.pem" "$CERT_DIR/${ADMIN_DOMAIN}.pem"
            cp "$CERT_PATH/privkey.pem" "$CERT_DIR/${ADMIN_DOMAIN}.key"
        fi
        
        # 链证书
        cp "$CERT_PATH/fullchain.pem" "$CERT_DIR/chain.pem"
        
        echo -e "${GREEN}Let's Encrypt 证书生成完成！${NC}"
    else
        echo -e "${RED}未找到生成的证书${NC}"
        exit 1
    fi

    # 设置正确的权限
    chmod 600 "$CERT_DIR"/*.key
    chmod 644 "$CERT_DIR"/*.pem
}

# ========== 生成 SSL 证书 ==========
if [ "$USE_LETSENCRYPT" = true ]; then
    generate_letsencrypt
else
    generate_self_signed
fi

# 显示证书信息
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  证书生成完成${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "证书文件列表:"
ls -la "$CERT_DIR/"
echo ""

# 设置正确的权限
echo -e "${YELLOW}设置文件权限...${NC}"
chmod 600 "$CERT_DIR"/*.key 2>/dev/null || true
chmod 644 "$CERT_DIR"/*.pem 2>/dev/null || true

echo ""
echo -e "${GREEN}下一步:${NC}"
echo "  1. 修改 .env.production 中的域名配置"
echo "  2. 修改 docker-compose.prod.yml 的相关配置"
echo "  3. 运行 docker compose -f docker-compose.prod.yml up -d 启动服务"
echo ""
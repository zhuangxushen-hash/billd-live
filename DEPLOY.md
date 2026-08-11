# 直播系统生产环境部署指南

## 1. 服务器准备

### 推荐配置
- **CPU**: 2核及以上
- **内存**: 4GB 及以上
- **硬盘**: 50GB SSD（根据视频存储需求调整）
- **操作系统**: Ubuntu 20.04/22.04 LTS 或 CentOS 7/8

### 必装软件
```bash
# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 安装 Docker Compose
apt-get install docker-compose-plugin
# 或
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 防火墙配置
需要开放以下端口：
```bash
# HTTP
ufw allow 80/tcp
# HTTPS
ufw allow 443/tcp
# RTMP 推流（OBS 等推流软件使用）
ufw allow 1935/tcp
# HTTP-FLV/HLS 直播流
ufw allow 8080/tcp
```

### 域名解析
需要提前配置以下 DNS 记录：
- `your-domain.com` → 服务器 IP（客户端）
- `admin.your-domain.com` → 服务器 IP（管理后台）

---

## 2. 获取项目代码

```bash
# 克隆项目
git clone https://github.com/你的用户名/billd-live.git
cd billd-live-project
```

---

## 3. 配置 SSL 证书

### 方式一：Let's Encrypt 自动签发（推荐）
```bash
# 运行证书生成脚本
chmod +x deploy/scripts/generate-ssl-cert.sh
./deploy/scripts/generate-ssl-cert.sh \
    -d your-domain.com \
    -a admin.your-domain.com \
    -e admin@your-domain.com \
    -l
```

### 方式二：自签名证书（测试用）
```bash
./deploy/scripts/generate-ssl-cert.sh \
    -d your-domain.com \
    -a admin.your-domain.com \
    -s
```

---

## 4. 修改配置文件

### 4.1 修改环境变量
```bash
# 复制生产环境配置
cp live-server/.env.production live-server/.env

# 编辑配置
vim live-server/.env
```

**必须修改的配置：**
```env
# 服务器域名
SERVER_DOMAIN=your-domain.com
ADMIN_DOMAIN=admin.your-domain.com

# JWT 密钥（生成随机字符串）
JWT_SECRET=使用以下命令生成: openssl rand -hex 32

# Session 密钥
SESSION_SECRET=使用以下命令生成: openssl rand -hex 32
```

### 4.2 修改 Nginx 配置
```bash
# 编辑生产环境 Nginx 配置
vim deploy/nginx/nginx.prod.conf
```

**需要修改的内容：**
- `${SERVER_DOMAIN}` → 替换为你的主域名
- `${ADMIN_DOMAIN}` → 替换为你的管理后台域名

### 4.3 修改 Docker Compose
```bash
# 编辑生产环境 docker-compose 文件
vim docker-compose.prod.yml
```

---

## 5. 创建必要目录

```bash
# 创建数据存储目录
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
```

---

## 6. 启动服务

### 6.1 构建并启动
```bash
# 使用生产环境配置启动
docker compose -f docker-compose.prod.yml up -d --build
```

### 6.2 查看服务状态
```bash
# 查看所有服务状态
docker compose -f docker-compose.prod.yml ps

# 查看日志
docker compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker compose -f docker-compose.prod.yml logs -f live-server
```

### 6.3 健康检查
```bash
# 后端服务健康检查
curl http://localhost:3000/api/health

# Nginx 健康检查
curl http://localhost/health
```

---

## 7. 初始配置

### 7.1 登录管理后台
1. 访问 `https://admin.your-domain.com`
2. 使用默认账号登录：
   - 用户名：`admin`
   - 密码：`123456`

### 7.2 修改默认密码
登录后立即修改管理员密码！

### 7.3 创建直播间
1. 进入"直播间管理"
2. 点击"创建直播间"
3. 填写直播间信息

---

## 8. 直播推流配置

### 8.1 伪直播（视频循环）
1. 进入"伪直播配置"
2. 选择"伪直播（视频循环）"模式
3. 选择直播间
4. 上传视频文件
5. 点击"开始伪直播"

### 8.2 正常直播（OBS 推流）
1. 进入"伪直播配置"
2. 选择"正常直播"模式
3. 选择直播间
4. 获取推流地址和密钥
5. 在 OBS 中配置推流

**OBS 配置：**
- 服务器地址：`rtmp://your-domain.com:1935/live`
- 串流密钥：管理后台显示的 `streamKey`

---

## 9. 日常运维

### 9.1 服务管理
```bash
# 停止所有服务
docker compose -f docker-compose.prod.yml down

# 重启服务
docker compose -f docker-compose.prod.yml restart

# 重新构建并启动（更新代码后）
docker compose -f docker-compose.prod.yml up -d --build

# 查看资源使用
docker stats
```

### 9.2 日志管理
```bash
# 实时查看后端日志
tail -f logs/*.log

# 查看 Nginx 访问日志
tail -f deploy/nginx/logs/access.log

# 查看 Nginx 错误日志
tail -f deploy/nginx/logs/error.log
```

### 9.3 数据备份
```bash
# 手动备份
docker compose -f docker-compose.prod.yml exec live-server \
    tar czf /backups/manual_backup_$(date +%Y%m%d).tar.gz /app/data

# 下载备份
docker cp live-server:/backups/manual_backup.tar.gz ./backups/

# 自动备份（已配置，默认每天一次）
# 备份保留 30 天
```

### 9.4 更新版本
```bash
# 拉取最新代码
git pull origin main

# 重新构建并启动
docker compose -f docker-compose.prod.yml up -d --build

# 清理旧镜像
docker image prune -f
```

---

## 10. 监控告警（可选）

### 10.1 健康检查脚本
```bash
# 创建健康检查脚本
cat > /opt/health-check.sh << 'EOF'
#!/bin/bash
HEALTH_URL="http://localhost:3000/api/health"
REPORT_URL="https://your-monitoring-service.com/webhook"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

if [ "$STATUS" != "200" ]; then
    # 发送告警
    curl -X POST $REPORT_URL \
        -H "Content-Type: application/json" \
        -d '{"message": "直播系统健康检查失败", "status": '$STATUS'}'
    
    # 重启服务
    cd /path/to/billd-live-project
    docker compose -f docker-compose.prod.yml restart live-server
fi
EOF

# 添加定时任务
crontab -e
# 每分钟检查
* * * * * /opt/health-check.sh
```

### 10.2 性能监控
```bash
# 使用 Docker 内置监控
docker stats --no-stream

# 查看容器资源限制
docker inspect live-server | grep -A 10 "Resources"
```

---

## 11. 常见问题

### Q1: RTMP 推流连接失败
检查：
1. SRS 服务是否正常运行：`docker compose -f docker-compose.prod.yml ps`
2. 1935 端口是否开放
3. OBS 推流地址是否正确

### Q2: 直播卡顿
可能原因：
1. 服务器带宽不足（建议至少 5Mbps）
2. SRS 配置需要优化
3. 考虑使用 CDN 加速

### Q3: SSL 证书更新
```bash
# Let's Encrypt 自动续期
certbot renew --quiet

# 手动触发续期
./deploy/scripts/generate-ssl-cert.sh -d your-domain.com -l
```

### Q4: 磁盘空间不足
```bash
# 查看磁盘使用
df -h

# 清理旧备份
find backups -name "*.tar.gz" -mtime +30 -delete

# 清理 Docker 缓存
docker system prune -a
```

---

## 12. 安全建议

1. **定期更新系统和软件**
   ```bash
   apt-get update && apt-get upgrade -y
   ```

2. **修改默认密码**
   - 首次部署后立即修改 admin 密码
   - 使用强密码（至少 12 位，包含大小写字母、数字和特殊字符）

3. **定期备份数据**
   - 建议每周手动备份一次
   - 重要数据可使用云存储备份

4. **限制管理后台访问**
   - 在 Nginx 配置中限制管理后台只允许特定 IP 访问
   - 使用 VPN 访问管理后台

5. **启用日志审计**
   - 定期检查访问日志和错误日志
   - 配置日志告警规则

---

## 附录：端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| 80 | Nginx | HTTP 访问，自动跳转 HTTPS |
| 443 | Nginx | HTTPS 加密访问 |
| 1935 | SRS | RTMP 推流端口 |
| 8080 | Nginx | HTTP-FLV/HLS 直播流代理 |
| 19350 | SRS | HTTPS 推流端口（可选） |

---

## 技术支持

如需技术支持，请提交 Issue 到 GitHub 仓库。
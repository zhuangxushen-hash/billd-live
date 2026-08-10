# SSL 证书目录

将您的 SSL 证书文件放在此目录：

- `zhibo.gdwkls.com.pem` - 证书文件
- `zhibo.gdwkls.com.key` - 私钥文件

## 获取 SSL 证书的方式

### 方式 1: Let's Encrypt（免费推荐）

```bash
# 安装 certbot
sudo apt-get install certbot python3-certbot-nginx -y

# 申请证书
sudo certbot certonly --standalone -d zhibo.gdwkls.com -d admin.zhibo.gdwkls.com

# 复制证书到本目录
sudo cp /etc/letsencrypt/live/zhibo.gdwkls.com/fullchain.pem ./zhibo.gdwkls.com.pem
sudo cp /etc/letsencrypt/live/zhibo.gdwkls.com/privkey.pem ./zhibo.gdwkls.com.key

# 设置权限
sudo chmod 644 ./zhibo.gdwkls.com.pem
sudo chmod 600 ./zhibo.gdwkls.com.key
```

### 方式 2: 阿里云 SSL 证书

1. 登录阿里云控制台
2. 进入 SSL 证书管理页面
3. 申请免费证书或上传自有证书
4. 下载 Nginx 格式证书
5. 将证书文件重命名为 `zhibo.gdwkls.com.pem` 和 `zhibo.gdwkls.com.key`

### 方式 3: 使用 acme.sh

```bash
# 安装 acme.sh
curl https://get.acme.sh | sh

# 申请证书
~/.acme.sh/acme.sh --issue -d zhibo.gdwkls.com -d admin.zhibo.gdwkls.com -w /var/www/html

# 安装证书到本目录
~/.acme.sh/acme.sh --install-cert -d zhibo.gdwkls.com \
  --fullchain-file ./zhibo.gdwkls.com.pem \
  --key-file ./zhibo.gdwkls.com.key
```

## 注意事项

- 证书域名必须包含 `zhibo.gdwkls.com` 和 `admin.zhibo.gdwkls.com`
- 证书有效期通常为 90 天，需要定期续签
- 续签后需要重启 live-gateway 容器生效

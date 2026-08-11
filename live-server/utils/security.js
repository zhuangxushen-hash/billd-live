/**
 * 安全工具模块
 * 提供密码加密、JWT令牌、API限流等功能
 */

const crypto = require('crypto');

// ========== 密码加密 ==========

/**
 * 生成密码哈希
 * 使用 SHA-256 + 随机盐值
 */
function hashPassword(password, salt = null) {
  if (!salt) {
    salt = crypto.randomBytes(16).toString('hex');
  }
  const hash = crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha256').toString('hex');
  return { salt, hash };
}

/**
 * 验证密码
 */
function verifyPassword(password, salt, hash) {
  const verifyHash = crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha256').toString('hex');
  return hash === verifyHash;
}

// ========== JWT 令牌 ==========

const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-key-change-in-production';
const JWT_EXPIRES_IN = 7 * 24 * 60 * 60; // 7天

/**
 * 生成 JWT 令牌
 */
function generateToken(payload) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
  
  const data = {
    ...payload,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + JWT_EXPIRES_IN
  };
  const encodedPayload = Buffer.from(JSON.stringify(data)).toString('base64url');
  
  const signature = crypto.createHmac('sha256', JWT_SECRET)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest('base64url');
  
  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

/**
 * 验证 JWT 令牌
 */
function verifyToken(token) {
  try {
    const [header, payload, signature] = token.split('.');
    
    // 验证签名
    const expectedSignature = crypto.createHmac('sha256', JWT_SECRET)
      .update(`${header}.${payload}`)
      .digest('base64url');
    
    if (signature !== expectedSignature) {
      return { valid: false, error: '无效的令牌签名' };
    }
    
    // 解析 payload
    const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString());
    
    // 检查过期
    if (decoded.exp && decoded.exp < Math.floor(Date.now() / 1000)) {
      return { valid: false, error: '令牌已过期' };
    }
    
    return { valid: true, data: decoded };
  } catch (e) {
    return { valid: false, error: '令牌格式错误' };
  }
}

// ========== API 限流 ==========

// 简单的内存限流存储
const rateLimitStore = new Map();

/**
 * API 限流中间件
 * @param {number} maxRequests - 时间窗口内最大请求数
 * @param {number} windowMs - 时间窗口（毫秒）
 */
function rateLimit(maxRequests = 100, windowMs = 60000) {
  return (req, res, next) => {
    const clientId = req.ip || req.connection.remoteAddress;
    const key = `${clientId}:${req.path}`;
    const now = Date.now();
    
    // 获取或创建时间窗口
    if (!rateLimitStore.has(key)) {
      rateLimitStore.set(key, []);
    }
    
    const timestamps = rateLimitStore.get(key);
    
    // 清理过期的时间戳
    while (timestamps.length > 0 && timestamps[0] <= now - windowMs) {
      timestamps.shift();
    }
    
    // 检查是否超过限制
    if (timestamps.length >= maxRequests) {
      res.setHeader('Retry-After', Math.ceil((timestamps[0] + windowMs - now) / 1000));
      return res.status(429).json({
        success: false,
        message: '请求过于频繁，请稍后再试',
        retryAfter: Math.ceil((timestamps[0] + windowMs - now) / 1000)
      });
    }
    
    // 添加当前请求时间戳
    timestamps.push(now);
    rateLimitStore.set(key, timestamps);
    
    next();
  };
}

/**
 * 登录接口限流（更严格）
 */
function loginRateLimit() {
  return rateLimit(5, 60000); // 每分钟最多 5 次登录尝试
}

// ========== 鉴权中间件 ==========

/**
 * 身份验证中间件
 */
function authenticate(req, res, next) {
  // 从 Authorization 头获取 token
  const authHeader = req.headers.authorization || req.headers.Authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: '未授权，请先登录'
    });
  }
  
  const token = authHeader.substring(7);
  const result = verifyToken(token);
  
  if (!result.valid) {
    return res.status(401).json({
      success: false,
      message: result.error
    });
  }
  
  req.user = result.data;
  next();
}

/**
 * 管理员权限验证中间件
 */
function requireAdmin(req, res, next) {
  if (req.user && req.user.role === 'admin') {
    next();
  } else {
    return res.status(403).json({
      success: false,
      message: '需要管理员权限'
    });
  }
}

/**
 * 可选鉴权（如果有 token 就解析，没有也允许访问）
 */
function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    const result = verifyToken(token);
    if (result.valid) {
      req.user = result.data;
    }
  }
  
  next();
}

// ========== 输入验证 ==========

/**
 * 清理用户输入，防止 XSS 攻击
 */
function sanitizeInput(input) {
  if (typeof input !== 'string') return input;
  
  return input
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/<\/?script[^>]*>/gi, '')
    .replace(/<\/?iframe[^>]*>/gi, '')
    .replace(/javascript:/gi, '')
    .replace(/on\w+=/gi, '')
    .replace(/<\/?object[^>]*>/gi, '')
    .replace(/<\/?embed[^>]*>/gi, '')
    .trim();
}

/**
 * 验证文件名（防止路径遍历）
 */
function validateFilename(filename) {
  if (!filename || typeof filename !== 'string') {
    return false;
  }
  
  // 检查是否包含路径遍历字符
  if (filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
    return false;
  }
  
  // 检查文件扩展名
  const allowedExtensions = [
    '.mp4', '.webm', '.flv', '.mkv', '.mov',
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'
  ];
  const ext = filename.toLowerCase().substring(filename.lastIndexOf('.'));
  
  return allowedExtensions.includes(ext);
}

// ========== 日志脱敏 ==========

/**
 * 敏感信息脱敏
 */
function maskSensitiveData(data, fields = ['password', 'token', 'secret', 'key']) {
  if (typeof data !== 'object' || data === null) return data;
  
  const masked = { ...data };
  for (const field of fields) {
    if (masked[field]) {
      masked[field] = '***';
    }
  }
  
  return masked;
}

// 导出模块
module.exports = {
  hashPassword,
  verifyPassword,
  generateToken,
  verifyToken,
  rateLimit,
  loginRateLimit,
  authenticate,
  requireAdmin,
  optionalAuth,
  sanitizeInput,
  validateFilename,
  maskSensitiveData
};

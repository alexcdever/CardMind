# 跨平台安全认证设计方案

## 概述

本文档描述了CardMind跨平台架构中的安全认证设计方案，包括CORS跨域支持、连接认证、权限管理和速率限制等核心安全机制。

## 设计目标

1. **跨域安全**: 支持安全的跨域请求，防止CSRF攻击
2. **连接认证**: 确保只有授权客户端可以连接信令服务器
3. **权限管理**: 实现细粒度的访问控制
4. **安全防护**: 防止常见的Web安全攻击
5. **性能优化**: 安全机制不应显著影响系统性能

## 核心安全机制

### 1. CORS跨域支持

#### Web平台特殊考虑
- Web平台作为客户端连接其他平台的信令服务器
- 需要支持动态CORS配置，允许来自不同源的请求
- 支持预检请求(OPTIONS)处理

#### CORS配置策略
```javascript
const corsOptions = {
  origin: function (origin, callback) {
    // 开发环境允许所有来源
    if (process.env.NODE_ENV === 'development') {
      return callback(null, true);
    }
    
    // 生产环境使用白名单
    const allowedOrigins = [
      'http://localhost:*',
      'http://127.0.0.1:*',
      'https://*.cardmind.app'
    ];
    
    // 检查来源是否匹配白名单
    const isAllowed = allowedOrigins.some(pattern => {
      if (pattern.includes('*')) {
        const regex = new RegExp(pattern.replace(/\*/g, '.*'));
        return regex.test(origin);
      }
      return pattern === origin;
    });
    
    callback(null, isAllowed);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Client-ID', 'X-Platform'],
  maxAge: 86400 // 24小时
};
```

### 2. 连接认证机制

#### 认证方式选择
- **Token认证**: 使用JWT Token进行无状态认证
- **客户端证书**: 支持客户端SSL证书认证（可选）
- **API Key**: 简单的API密钥认证（用于开发环境）

#### JWT Token设计
```javascript
// Token载荷结构
const tokenPayload = {
  clientId: 'unique-client-id',
  platform: 'web' | 'electron' | 'react-native',
  version: '1.0.0',
  permissions: ['read', 'write', 'signal'],
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24小时有效期
};
```

#### 认证流程
1. 客户端首次连接时请求Token
2. 服务器验证客户端身份并签发Token
3. 客户端在后续请求中携带Token
4. 服务器验证Token有效性
5. Token过期后客户端重新获取

### 3. WebSocket认证

#### 升级请求认证
```javascript
// WebSocket升级请求认证
const authenticateWebSocket = (request) => {
  const token = request.headers['authorization']?.replace('Bearer ', '');
  
  if (!token) {
    throw new Error('Missing authentication token');
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return {
      clientId: decoded.clientId,
      platform: decoded.platform,
      permissions: decoded.permissions
    };
  } catch (error) {
    throw new Error('Invalid authentication token');
  }
};
```

#### 连接后认证
- 支持WebSocket连接后的认证消息
- 未认证连接只能发送认证相关消息
- 认证超时机制（30秒内必须完成认证）

### 4. 权限管理系统

#### 权限模型
```javascript
// 权限定义
const PERMISSIONS = {
  READ: 'read',           // 读取数据权限
  WRITE: 'write',         // 写入数据权限
  SIGNAL: 'signal',       // 信令通信权限
  ADMIN: 'admin',         // 管理权限
  DISCOVER: 'discover'    // 设备发现权限
};

// 角色定义
const ROLES = {
  GUEST: [PERMISSIONS.READ],
  USER: [PERMISSIONS.READ, PERMISSIONS.WRITE, PERMISSIONS.SIGNAL],
  ADMIN: [PERMISSIONS.READ, PERMISSIONS.WRITE, PERMISSIONS.SIGNAL, PERMISSIONS.ADMIN]
};
```

#### 消息权限控制
- 检查客户端是否有权限发送特定类型的消息
- 根据消息类型和目标用户进行权限验证
- 支持房间级别的权限控制

### 5. 速率限制

#### 限制策略
```javascript
// 速率限制配置
const rateLimitConfig = {
  // 全局速率限制
  global: {
    windowMs: 60 * 1000,  // 1分钟
    max: 1000             // 每分钟最多1000个请求
  },
  
  // 连接速率限制
  connection: {
    windowMs: 60 * 1000,  // 1分钟
    max: 10               // 每分钟最多10个连接
  },
  
  // 消息速率限制
  message: {
    windowMs: 1000,       // 1秒
    max: 50               // 每秒最多50条消息
  },
  
  // 按客户端类型限制
  byPlatform: {
    web: { max: 100 },    // Web平台限制
    electron: { max: 200 }, // Electron平台限制
    'react-native': { max: 150 }
  }
};
```

#### 动态速率调整
- 根据服务器负载动态调整速率限制
- 对异常行为客户端加强限制
- 支持白名单客户端绕过限制

### 6. 安全防护

#### 输入验证
```javascript
// 消息格式验证
const validateMessage = (message) => {
  // 检查消息结构
  if (!message || typeof message !== 'object') {
    throw new Error('Invalid message format');
  }
  
  // 检查必需字段
  const requiredFields = ['type', 'data'];
  for (const field of requiredFields) {
    if (!(field in message)) {
      throw new Error(`Missing required field: ${field}`);
    }
  }
  
  // 检查字段类型和长度
  if (typeof message.type !== 'string' || message.type.length > 50) {
    throw new Error('Invalid message type');
  }
  
  // 深度检查数据字段
  if (typeof message.data !== 'object') {
    throw new Error('Invalid message data');
  }
  
  return true;
};
```

#### 消息大小限制
- 单条消息最大64KB
- WebSocket帧最大256KB
- 批量消息最大1MB

#### 防攻击机制
- **DDoS防护**: 基于IP的连接限制和异常检测
- **重放攻击**: Token中包含时间戳和随机数
- **中间人攻击**: 强制使用HTTPS/WSS加密传输
- **注入攻击**: 严格的消息格式验证和转义

## 平台差异处理

### Web平台
- 依赖浏览器的安全策略（CSP、SOP）
- 无法存储长期凭证，需要频繁重新认证
- 受限于浏览器的网络访问能力

### Electron平台
- 可以使用系统级安全功能
- 支持客户端证书认证
- 可以集成系统密钥链存储凭证

### React Native平台
- 使用原生安全存储（Keychain/Keystore）
- 支持生物识别认证
- 可以利用平台特有的安全机制

## 错误处理

### 认证错误
```javascript
const AUTH_ERRORS = {
  INVALID_TOKEN: { code: 401, message: 'Invalid authentication token' },
  EXPIRED_TOKEN: { code: 401, message: 'Authentication token expired' },
  MISSING_TOKEN: { code: 401, message: 'Missing authentication token' },
  INSUFFICIENT_PERMISSIONS: { code: 403, message: 'Insufficient permissions' },
  RATE_LIMIT_EXCEEDED: { code: 429, message: 'Rate limit exceeded' }
};
```

### 错误响应格式
```javascript
{
  type: 'error',
  code: 'AUTH_ERROR',
  message: 'Authentication failed',
  details: {
    error: 'INVALID_TOKEN',
    description: 'Invalid authentication token'
  },
  timestamp: '2024-01-01T00:00:00.000Z'
}
```

## 性能优化

### 认证缓存
- 缓存验证过的Token，避免重复验证
- 使用LRU缓存策略，控制内存使用
- 缓存过期时间与Token过期时间同步

### 异步处理
- 认证验证异步进行，不阻塞消息处理
- 使用连接池管理认证状态
- 批量处理认证请求

### 资源限制
- 限制并发认证请求数量
- 设置认证超时时间
- 使用熔断器模式防止认证服务过载

## 监控和审计

### 安全事件监控
- 记录所有认证失败事件
- 监控异常连接模式
- 跟踪权限提升请求

### 审计日志
```javascript
// 审计日志格式
const auditLog = {
  timestamp: '2024-01-01T00:00:00.000Z',
  event: 'AUTHENTICATION_SUCCESS',
  clientId: 'client-123',
  platform: 'web',
  ip: '192.168.1.100',
  userAgent: 'Mozilla/5.0...',
  result: 'SUCCESS',
  duration: 150 // 认证耗时(ms)
};
```

## 配置管理

### 环境变量配置
```bash
# 安全配置
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=24h
CORS_ORIGIN=http://localhost:3000
RATE_LIMIT_WINDOW=60000
RATE_LIMIT_MAX=1000

# 安全策略
ENABLE_RATE_LIMIT=true
ENABLE_AUTHENTICATION=true
LOG_LEVEL=info
```

### 运行时配置
- 支持运行时调整安全策略
- 动态更新CORS白名单
- 实时调整速率限制参数

## 测试策略

### 单元测试
- 认证逻辑单元测试
- 权限验证测试
- 输入验证测试

### 集成测试
- 跨域请求测试
- WebSocket认证测试
- 速率限制测试

### 安全测试
- 渗透测试
- DDoS攻击模拟
- 认证绕过测试

## 后续计划

1. **实现阶段**: 根据本文档设计实现具体的安全认证功能
2. **测试阶段**: 进行全面的安全测试和性能测试
3. **优化阶段**: 根据测试结果优化安全策略和性能
4. **文档更新**: 更新相关技术文档，添加安全配置说明

## 总结

本安全认证设计方案为CardMind跨平台架构提供了全面的安全保障，包括跨域支持、连接认证、权限管理和安全防护等核心机制。通过合理的安全策略和性能优化，确保系统在提供安全保障的同时保持良好的性能表现。

各平台的安全实现将根据本方案进行适配，确保在不同平台上都能提供一致的安全保护水平。
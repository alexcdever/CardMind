# CardMind 跨平台架构设计文档

## 1. 架构背景

### 1.1 原有架构限制
原有架构主要基于Web平台设计，使用BroadcastChannel实现同一浏览器内的设备通信。这种架构在全平台分发时面临以下挑战：

- **Web平台限制**：BroadcastChannel只能在同一浏览器内工作
- **跨设备隔离**：Electron、React Native无法与Web端通信
- **平台差异**：不同平台的通信机制差异巨大
- **网络环境**：无法处理复杂的网络环境和NAT穿透

### 1.2 全平台需求
- **桌面端**：Windows、macOS、Linux（通过Electron）
- **移动端**：iOS、Android（通过React Native）
- **Web端**：现代浏览器（Chrome、Firefox、Safari等）
- **跨平台通信**：所有平台间能够互相发现和通信

## 2. 混合架构设计

### 2.1 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        客户端层                                   │
├─────────────┬─────────────┬─────────────┬──────────────────────┤
│   Web端     │  Electron   │ React Native│    其他平台          │
│(浏览器环境)  │(桌面环境)    │(移动环境)    │(TV/嵌入式等)        │
└──────┬──────┴──────┬──────┴──────┬──────┴──────┬─────────────────┘
       │             │             │             │
       └─────────────┼─────────────┼─────────────┼─────────────────┘
                     │             │             │
              ┌──────▼─────────────────────────────▼─────────────────┐
              │              通信适配层                               │
              │  ┌─────────────┬─────────────┬────────────────────┐  │
              │  │ 平台检测  │  连接策略   │   协议适配         │  │
              │  └─────────────┴─────────────┴────────────────────┘  │
              └──────────────────┬─────────────────────────────────┘
                                 │
              ┌──────────────────┼─────────────────────────────────┐
              │                  │                                 │
       ┌──────▼──────┐    ┌──────▼──────┐                  ┌──────▼──────┐
       │本地通信优先 │    │局域网发现   │                  │云信令服务  │
       │BroadcastChan│    │mDNS/Bonjour │                  │WebSocket   │
       │IPC(原生)    │    │直接IP连接   │                  │Serverless  │
       └──────┬──────┘    └──────┬──────┘                  └──────┬──────┘
              │                  │                                 │
              └──────────────────┼─────────────────────────────────┘
                                 │
              ┌──────────────────▼─────────────────────────────────┐
              │              WebRTC核心层                        │
              │  ┌─────────────┬─────────────┬────────────────────┐  │
              │  │ 连接管理   │  NAT穿透    │   数据通道         │  │
              │  │ 状态监控   │  ICE处理    │   加密传输         │  │
              │  └─────────────┴─────────────┴────────────────────┘  │
              └──────────────────┬─────────────────────────────────┘
                                 │
              ┌──────────────────▼─────────────────────────────────┐
              │              Yjs CRDT层                         │
              │  ┌─────────────┬─────────────┬────────────────────┐  │
              │  │ 文档同步   │ 冲突解决    │   状态管理         │  │
              │  │ 版本控制   │ 合并策略    │   持久化           │  │
              │  └─────────────┴─────────────┴────────────────────┘  │
              └──────────────────┬─────────────────────────────────┘
                                 │
              ┌──────────────────▼─────────────────────────────────┐
              │              数据存储层                         │
              │  ┌─────────────┬─────────────┬────────────────────┐  │
              │  │ IndexedDB  │ AsyncStorage│   SQLite         │  │
              │  │ (Web/桌面)  │ (RN)        │   (原生)         │  │
              │  └─────────────┴─────────────┴────────────────────┘  │
              └──────────────────────────────────────────────────┘
```

### 2.2 通信优先级策略

#### 2.2.1 连接优先级（按速度和稳定性排序）
1. **同一设备内**（速度最快，延迟最低）
   - Web: BroadcastChannel
   - Electron: IPC通信
   - React Native: Native Event Bridge

2. **同一局域网**（速度较快，无网络成本）
   - mDNS/Bonjour服务发现
   - 直接IP连接
   - 本地WebSocket服务器

3. **跨网络/互联网**（覆盖范围广，需要服务器）
   - 云信令服务器
   - STUN/TURN服务器协助NAT穿透
   - 完全P2P数据传输

#### 2.2.2 自动降级机制
```typescript
class ConnectionManager {
  async establishConnection(targetDevice: DeviceInfo): Promise<Connection> {
    // 1. 尝试同一设备内通信
    if (this.isSameDevice(targetDevice)) {
      return await this.tryIntraDeviceConnection();
    }
    
    // 2. 尝试局域网发现
    const localConnection = await this.tryLocalNetworkDiscovery();
    if (localConnection) {
      return localConnection;
    }
    
    // 3. 使用云信令服务
    return await this.establishCloudSignalingConnection();
  }
}
```

## 3. 平台适配方案

### 3.1 Web平台适配

#### 3.1.1 通信机制
```typescript
class WebPlatformAdapter {
  private broadcastChannel: BroadcastChannel | null = null;
  private websocket: WebSocket | null = null;
  
  async initialize() {
    // 1. 初始化BroadcastChannel（同一浏览器内）
    this.broadcastChannel = new BroadcastChannel('cardmind_sync');
    
    // 2. 初始化WebSocket连接（跨设备）
    this.websocket = new WebSocket(SIGNALING_SERVER_URL);
  }
  
  async sendMessage(message: SyncMessage) {
    // 优先使用BroadcastChannel
    if (this.broadcastChannel) {
      this.broadcastChannel.postMessage(message);
    }
    
    // 同时通过WebSocket发送（确保跨设备可达）
    if (this.websocket?.readyState === WebSocket.OPEN) {
      this.websocket.send(JSON.stringify(message));
    }
  }
}
```

#### 3.1.2 存储方案
- **主存储**: IndexedDB（通过Dexie.js）
- **缓存**: localStorage（小数据）
- **会话存储**: sessionStorage

### 3.2 Electron平台适配

#### 3.2.1 通信机制
```typescript
class ElectronPlatformAdapter {
  private ipcRenderer: IpcRenderer;
  private websocket: WebSocket | null = null;
  
  constructor() {
    this.ipcRenderer = window.require('electron').ipcRenderer;
  }
  
  async initialize() {
    // 1. 设置IPC通信（主进程↔渲染进程）
    this.ipcRenderer.on('sync-message', this.handleSyncMessage);
    
    // 2. 初始化WebSocket（跨设备通信）
    this.websocket = new WebSocket(SIGNALING_SERVER_URL);
  }
  
  async sendMessage(message: SyncMessage) {
    // 通过IPC发送到主进程
    this.ipcRenderer.send('sync-message', message);
    
    // 同时通过WebSocket发送
    if (this.websocket?.readyState === WebSocket.OPEN) {
      this.websocket.send(JSON.stringify(message));
    }
  }
}
```

#### 3.2.2 存储方案
- **主存储**: IndexedDB（与Web平台兼容）
- **文件存储**: Node.js fs模块（大数据备份）
- **系统存储**: 系统钥匙串（加密密钥）

#### 3.2.3 原生功能集成
```typescript
// Electron主进程
class ElectronMainProcess {
  async handleSyncMessage(message: SyncMessage) {
    switch (message.type) {
      case 'DISCOVER_DEVICES':
        // 使用Node.js进行网络发现
        const devices = await this.discoverNetworkDevices();
        return devices;
        
      case 'ESTABLISH_CONNECTION':
        // 协助建立WebRTC连接
        return await this.establishWebRTCConnection(message.payload);
    }
  }
  
  async discoverNetworkDevices(): Promise<DeviceInfo[]> {
    // 使用Node.js的dgram模块进行UDP广播
    // 或者使用bonjour库进行mDNS发现
    const bonjour = require('bonjour');
    const browser = bonjour.find({ type: 'cardmind' });
    
    return new Promise((resolve) => {
      const devices: DeviceInfo[] = [];
      browser.on('up', (service) => {
        devices.push({
          id: service.name,
          name: service.host,
          address: service.addresses[0],
          port: service.port,
          platform: 'unknown'
        });
      });
      
      setTimeout(() => {
        browser.stop();
        resolve(devices);
      }, 5000);
    });
  }
}
```

### 3.3 React Native平台适配

#### 3.3.1 通信机制
```typescript
class ReactNativePlatformAdapter {
  private websocket: WebSocket | null = null;
  private netInfo: NetInfoSubscription | null = null;
  
  async initialize() {
    // 1. 监听网络状态变化
    this.netInfo = NetInfo.addEventListener(this.handleNetworkChange);
    
    // 2. 初始化WebSocket连接
    this.websocket = new WebSocket(SIGNALING_SERVER_URL);
    
    // 3. 设置原生事件桥
    this.setupNativeEventBridge();
  }
  
  async discoverLocalDevices() {
    // 使用React Native的网络API
    const networkInfo = await NetInfo.fetch();
    
    if (networkInfo.type === 'wifi') {
      // 在同一WiFi下进行网络扫描
      return await this.scanLocalNetwork(networkInfo.details.ipAddress);
    }
    
    return [];
  }
  
  private async scanLocalNetwork(myIp: string): Promise<DeviceInfo[]> {
    // 简单的IP段扫描（适用于小型网络）
    const subnet = myIp.substring(0, myIp.lastIndexOf('.'));
    const devices: DeviceInfo[] = [];
    
    // 并行扫描常用端口
    const scanPromises = [];
    for (let i = 1; i < 255; i++) {
      const targetIp = `${subnet}.${i}`;
      scanPromises.push(this.checkDevice(targetIp, 8080));
    }
    
    const results = await Promise.allSettled(scanPromises);
    results.forEach((result, index) => {
      if (result.status === 'fulfilled' && result.value) {
        devices.push({
          id: `device-${index}`,
          name: `Device ${index}`,
          address: `${subnet}.${index}`,
          port: 8080,
          platform: 'unknown'
        });
      }
    });
    
    return devices;
  }
}
```

#### 3.3.2 存储方案
- **主存储**: AsyncStorage（小数据）
- **数据库**: SQLite（通过react-native-sqlite-storage）
- **文件存储**: react-native-fs

#### 3.3.3 原生模块集成
```typescript
// 原生Android模块（Java/Kotlin）
@ReactModule(name = CardMindSyncModule.NAME)
public class CardMindSyncModule extends ReactContextBaseJavaModule {
    public static final String NAME = "CardMindSyncModule";
    
    @ReactMethod
    public void discoverDevices(Promise promise) {
        // 使用Android的Network Service Discovery
        NsdManager nsdManager = (NsdManager) getReactApplicationContext()
            .getSystemService(Context.NSD_SERVICE);
            
        nsdManager.discoverServices("_cardmind._tcp", 
            NsdManager.PROTOCOL_DNS_SD, 
            new NsdManager.DiscoveryListener() {
                @Override
                public void onServiceFound(NsdServiceInfo service) {
                    // 发现服务
                }
                
                @Override
                public void onStopDiscoveryFailed(String serviceType, int errorCode) {
                    promise.reject("DISCOVERY_FAILED", "Discovery failed: " + errorCode);
                }
                
                // 其他回调方法...
            });
    }
}
```

## 4. 信令服务器设计

### 4.1 轻量级信令服务器

#### 4.1.1 核心功能
```typescript
// server/signaling-server.ts
import { WebSocketServer, WebSocket } from 'ws';
import { createServer } from 'http';

interface SignalingMessage {
  id: string;
  type: 'offer' | 'answer' | 'candidate' | 'join' | 'leave' | 'discover';
  from: string;
  to?: string;
  room?: string;
  payload: any;
  timestamp: number;
}

interface Client {
  id: string;
  ws: WebSocket;
  room?: string;
  platform: string;
  deviceInfo: DeviceInfo;
}

class SignalingServer {
  private clients = new Map<string, Client>();
  private rooms = new Map<string, Set<string>>();
  
  constructor(private port: number) {
    this.initializeServer();
  }
  
  private initializeServer() {
    const server = createServer();
    const wss = new WebSocketServer({ server });
    
    wss.on('connection', (ws, request) => {
      const clientId = this.generateClientId();
      const client: Client = {
        id: clientId,
        ws,
        platform: this.detectPlatform(request.headers['user-agent']),
        deviceInfo: this.parseDeviceInfo(request.headers)
      };
      
      this.clients.set(clientId, client);
      this.setupClientHandlers(client);
    });
    
    server.listen(this.port, () => {
      console.log(`Signaling server listening on port ${this.port}`);
    });
  }
  
  private setupClientHandlers(client: Client) {
    client.ws.on('message', (data) => {
      try {
        const message: SignalingMessage = JSON.parse(data.toString());
        this.handleMessage(client, message);
      } catch (error) {
        console.error('Invalid message format:', error);
      }
    });
    
    client.ws.on('close', () => {
      this.handleClientDisconnect(client);
    });
    
    client.ws.on('error', (error) => {
      console.error('WebSocket error:', error);
    });
  }
  
  private handleMessage(client: Client, message: SignalingMessage) {
    switch (message.type) {
      case 'join':
        this.handleJoinRoom(client, message);
        break;
        
      case 'leave':
        this.handleLeaveRoom(client, message);
        break;
        
      case 'offer':
      case 'answer':
      case 'candidate':
        this.handleSignalingMessage(client, message);
        break;
        
      case 'discover':
        this.handleDiscoveryRequest(client, message);
        break;
        
      default:
        console.warn('Unknown message type:', message.type);
    }
  }
  
  private handleJoinRoom(client: Client, message: SignalingMessage) {
    const room = message.room;
    if (!room) return;
    
    // 离开之前的房间
    if (client.room) {
      this.leaveRoom(client);
    }
    
    // 加入新房间
    client.room = room;
    
    if (!this.rooms.has(room)) {
      this.rooms.set(room, new Set());
    }
    
    this.rooms.get(room)!.add(client.id);
    
    // 通知房间内的其他成员
    this.broadcastToRoom(room, {
      id: this.generateMessageId(),
      type: 'join',
      from: client.id,
      room,
      payload: {
        deviceInfo: client.deviceInfo,
        platform: client.platform
      },
      timestamp: Date.now()
    }, client.id);
  }
  
  private handleSignalingMessage(sender: Client, message: SignalingMessage) {
    if (!message.to) return;
    
    const targetClient = this.clients.get(message.to);
    if (!targetClient || targetClient.ws.readyState !== WebSocket.OPEN) {
      console.warn('Target client not available:', message.to);
      return;
    }
    
    // 转发信令消息
    targetClient.ws.send(JSON.stringify({
      ...message,
      id: this.generateMessageId(),
      timestamp: Date.now()
    }));
  }
  
  private handleDiscoveryRequest(client: Client, message: SignalingMessage) {
    const room = client.room;
    if (!room) return;
    
    const roomMembers = this.rooms.get(room);
    if (!roomMembers) return;
    
    // 收集房间内的其他成员信息
    const devices: DeviceInfo[] = [];
    roomMembers.forEach(memberId => {
      if (memberId !== client.id) {
        const member = this.clients.get(memberId);
        if (member) {
          devices.push(member.deviceInfo);
        }
      }
    });
    
    // 回复发现请求
    client.ws.send(JSON.stringify({
      id: this.generateMessageId(),
      type: 'discover',
      from: 'server',
      to: client.id,
      room,
      payload: { devices },
      timestamp: Date.now()
    }));
  }
  
  private broadcastToRoom(room: string, message: SignalingMessage, excludeClientId?: string) {
    const roomMembers = this.rooms.get(room);
    if (!roomMembers) return;
    
    roomMembers.forEach(memberId => {
      if (memberId !== excludeClientId) {
        const member = this.clients.get(memberId);
        if (member && member.ws.readyState === WebSocket.OPEN) {
          member.ws.send(JSON.stringify(message));
        }
      }
    });
  }
  
  private handleClientDisconnect(client: Client) {
    console.log('Client disconnected:', client.id);
    
    // 离开房间
    if (client.room) {
      this.leaveRoom(client);
    }
    
    // 移除客户端
    this.clients.delete(client.id);
  }
  
  private leaveRoom(client: Client) {
    if (!client.room) return;
    
    const room = client.room;
    const roomMembers = this.rooms.get(room);
    
    if (roomMembers) {
      roomMembers.delete(client.id);
      
      // 通知其他成员
      this.broadcastToRoom(room, {
        id: this.generateMessageId(),
        type: 'leave',
        from: client.id,
        room,
        payload: {
          deviceInfo: client.deviceInfo
        },
        timestamp: Date.now()
      });
      
      // 清理空房间
      if (roomMembers.size === 0) {
        this.rooms.delete(room);
      }
    }
    
    client.room = undefined;
  }
  
  private generateClientId(): string {
    return `client-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
  
  private generateMessageId(): string {
    return `msg-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
  
  private detectPlatform(userAgent?: string): string {
    if (!userAgent) return 'unknown';
    
    if (userAgent.includes('Electron')) return 'electron';
    if (userAgent.includes('ReactNative')) return 'react-native';
    if (userAgent.includes('Mobile')) return 'mobile-web';
    return 'web';
  }
  
  private parseDeviceInfo(headers: IncomingHttpHeaders): DeviceInfo {
    const userAgent = headers['user-agent'] || '';
    const xDeviceInfo = headers['x-device-info'] as string;
    
    if (xDeviceInfo) {
      try {
        return JSON.parse(xDeviceInfo);
      } catch (error) {
        console.warn('Failed to parse device info header:', error);
      }
    }
    
    return {
      id: 'unknown',
      name: 'Unknown Device',
      platform: this.detectPlatform(userAgent),
      version: 'unknown'
    };
  }
}

// 启动服务器
const signalingServer = new SignalingServer(
  parseInt(process.env.SIGNALING_PORT || '8080')
);
```

#### 4.1.2 Serverless部署方案
```typescript
// vercel/api/signaling.ts
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { WebSocketServer } from 'ws';

// Vercel Serverless函数适配
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method === 'GET' && req.url === '/api/signaling') {
    // 处理WebSocket连接升级
    res.writeHead(200, {
      'Content-Type': 'text/plain',
      'Upgrade': 'websocket',
      'Connection': 'Upgrade'
    });
    res.end('WebSocket endpoint ready');
  } else if (req.method === 'POST') {
    // 处理HTTP长轮询（WebSocket不可用时的备选方案）
    const { action, data } = req.body;
    
    switch (action) {
      case 'poll':
        return await handleLongPolling(req, res);
      case 'send':
        return await handleMessageSend(req, res);
      default:
        res.status(400).json({ error: 'Invalid action' });
    }
  }
}

// 长轮询实现（备选方案）
async function handleLongPolling(req: VercelRequest, res: VercelResponse) {
  const { clientId, lastMessageId } = req.body;
  
  // 等待新消息或超时
  const timeout = setTimeout(() => {
    res.json({ messages: [], timeout: true });
  }, 25000); // 25秒超时
  
  // 监听新消息
  messageBus.once(`message:${clientId}`, (messages) => {
    clearTimeout(timeout);
    res.json({ messages, timeout: false });
  });
}
```

### 4.2 部署和运维

#### 4.2.1 Docker容器化
```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# 安装依赖
COPY package*.json ./
RUN npm ci --only=production

# 复制源码
COPY server/ ./server/
COPY shared/ ./shared/

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# 启动服务
EXPOSE 8080
CMD ["node", "server/signaling-server.js"]
```

#### 4.2.2 Docker Compose配置
```yaml
# docker-compose.yml
version: '3.8'

services:
  signaling-server:
    build: .
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=production
      - SIGNALING_PORT=8080
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: unless-stopped
    
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    restart: unless-stopped
    
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - signaling-server
    restart: unless-stopped

volumes:
  redis-data:
```

#### 4.2.3 监控和日志
```typescript
// server/monitoring.ts
import prometheus from 'prom-client';

// 指标收集
const connectedClients = new prometheus.Gauge({
  name: 'signaling_connected_clients',
  help: 'Number of connected clients',
  labelNames: ['platform']
});

const messagesTotal = new prometheus.Counter({
  name: 'signaling_messages_total',
  help: 'Total number of messages processed',
  labelNames: ['type', 'status']
});

const messageDuration = new prometheus.Histogram({
  name: 'signaling_message_duration_seconds',
  help: 'Message processing duration',
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 5]
});

// 健康检查端点
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    clients: this.clients.size,
    rooms: this.rooms.size
  });
});

// 指标端点
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(await prometheus.register.metrics());
});
```

## 5. 实施计划

### 5.1 第一阶段：基础信令服务（2周）
- [ ] 实现轻量级信令服务器
- [ ] 添加WebSocket支持到现有SyncService
- [ ] 保持BroadcastChannel向后兼容
- [ ] 部署测试环境

### 5.2 第二阶段：平台适配（3周）
- [ ] Electron平台适配
- [ ] React Native平台适配
- [ ] 平台检测和自动切换
- [ ] 跨平台测试

### 5.3 第三阶段：网络优化（2周）
- [ ] mDNS/Bonjour服务发现
- [ ] STUN/TURN服务器集成
- [ ] NAT穿透优化
- [ ] 连接质量监控

### 5.4 第四阶段：生产部署（1周）
- [ ] Docker容器化
- [ ] CI/CD流水线
- [ ] 监控和告警
- [ ] 性能优化

## 6. 成本估算

### 6.1 服务器成本
- **轻量级信令服务器**: $5-20/月（支持1万并发）
- **STUN/TURN服务器**: $10-50/月（可选，用于NAT穿透）
- **监控和日志**: $5-15/月
- **总计**: $20-85/月

### 6.2 开发成本
- **开发时间**: 8周（2个月）
- **人力投入**: 1-2名开发者
- **测试资源**: 多设备测试环境

### 6.3 维护成本
- **日常监控**: 5小时/月
- **故障处理**: 10小时/月
- **功能更新**: 20小时/月

## 7. 风险评估

### 7.1 技术风险
- **WebRTC兼容性**: 不同平台实现差异
- **网络环境复杂**: 企业防火墙、代理服务器
- **设备性能差异**: 移动端资源限制

### 7.2 缓解措施
- **渐进式升级**: 保持向后兼容
- **多连接策略**: 自动降级机制
- **性能监控**: 实时性能指标
- **用户反馈**: 快速响应机制

## 8. 总结

新的跨平台架构设计通过引入轻量级信令服务器和智能连接管理，实现了以下目标：

1. **全平台支持**: Web、Electron、React Native全覆盖
2. **向后兼容**: 保持现有BroadcastChannel功能
3. **智能连接**: 自动选择最优通信路径
4. **成本可控**: 轻量级服务器，成本极低
5. **渐进升级**: 分阶段实施，风险可控

该架构既满足了全平台分发的需求，又保持了原有架构的简洁性和成本优势。
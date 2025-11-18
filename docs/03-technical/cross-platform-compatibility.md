# CardMind 跨平台兼容性设计方案

## 1. 设计目标与挑战

### 1.1 兼容性目标
- ✅ **功能一致性**：核心功能在各平台表现一致
- ✅ **体验一致性**：用户界面和交互保持统一
- ✅ **数据一致性**：跨平台数据格式和同步协议统一
- ✅ **性能一致性**：关键性能指标在各平台接近
- ✅ **开发一致性**：统一的开发语言和工具链

### 1.2 平台能力差异

| 能力 \ 平台 | Web | Electron | Win桌面 | macOS | Linux | Android | iOS |
|-------------|-----|----------|---------|-------|-------|---------|-----|
| **网络能力** |
| UDP广播 | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| HTTP服务器 | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| WebSocket服务器 | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| P2P连接 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **系统能力** |
| 后台运行 | ❌ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| 系统通知 | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 开机启动 | ❌ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| 电源管理 | ❌ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| **存储能力** |
| 大容量存储 | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 文件系统访问 | ⚠️ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| 数据库支持 | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

说明：✅ 完全支持，⚠️ 有限支持，❌ 不支持

## 2. 总体架构设计

### 2.1 分层兼容性架构
```
┌─────────────────────────────────────────┐
│          统一用户界面层 (React)           │
├─────────────────────────────────────────┤
│          业务逻辑抽象层 (TypeScript)       │
├─────────────────────────────────────────┤
│         平台适配层 (Platform Adapter)     │
├─────────────────────────────────────────┤
│    平台原生层 (Native Implementation)    │
└─────────────────────────────────────────┘
```

### 2.2 平台适配策略
```
核心策略：抽象统一接口 + 平台具体实现 + 渐进式降级

Web平台：
├─ 网络：Service Worker代理 + WebSocket客户端
├─ 存储：IndexedDB + LocalStorage
├─ 通知：Web Notification API
└─ 文件：File System Access API

Electron平台：
├─ 网络：Node.js HTTP服务器 + WebSocket
├─ 存储：SQLite + 本地文件系统
├─ 通知：系统通知 + 自定义通知
└─ 文件：完整文件系统访问

React Native平台：
├─ 网络：原生HTTP服务器 + WebSocket
├─ 存储：SQLite + AsyncStorage
├─ 通知：原生推送通知
└─ 文件：受限文件系统访问
```

## 3. 网络层兼容性设计

### 3.1 统一网络接口

**抽象网络接口**：
```typescript
// 统一的网络操作接口
interface NetworkAdapter {
  // 设备发现
  discoverDevices(): Promise<DeviceInfo[]>;
  advertiseDevice(device: DeviceInfo): Promise<void>;
  stopDiscovery(): Promise<void>;
  
  // 信令传输
  createSignalingServer(port?: number): Promise<SignalingServer>;
  connectToSignalingServer(url: string): Promise<SignalingClient>;
  
  // P2P连接
  createPeerConnection(config: RTCConfig): Promise<RTCPeerConnection>;
  getNetworkInfo(): Promise<NetworkInfo>;
  
  // 能力检测
  getCapabilities(): NetworkCapabilities;
}

// 网络能力定义
interface NetworkCapabilities {
  udpBroadcast: boolean;
  httpServer: boolean;
  websocketServer: boolean;
  mdns: boolean;
  webrtc: boolean;
  p2pDataChannel: boolean;
}
```

### 3.2 平台具体实现

**Web平台实现**：
```typescript
class WebNetworkAdapter implements NetworkAdapter {
  private serviceWorker: ServiceWorker | null = null;
  private wsConnections: Map<string, WebSocket> = new Map();
  
  async discoverDevices(): Promise<DeviceInfo[]> {
    // Web平台通过mDNS.js实现
    const mdns = await import('mdns-js');
    const browser = mdns.createBrowser(mdns.tcp('cardmind'));
    
    return new Promise((resolve) => {
      const devices: DeviceInfo[] = [];
      browser.on('update', (service) => {
        devices.push(this.parseServiceToDevice(service));
      });
      
      setTimeout(() => {
        browser.stop();
        resolve(devices);
      }, 5000); // 扫描5秒
      
      browser.start();
    });
  }
  
  async createSignalingServer(port?: number): Promise<SignalingServer> {
    // Web平台无法创建真实服务器，使用Service Worker代理
    if ('serviceWorker' in navigator) {
      const registration = await navigator.serviceWorker.register('/sw-signaling.js');
      return new WebSignalingServer(registration);
    } else {
      throw new Error('Service Worker not supported');
    }
  }
  
  async connectToSignalingServer(url: string): Promise<SignalingClient> {
    const ws = new WebSocket(url);
    return new WebSocketSignalingClient(ws);
  }
  
  getCapabilities(): NetworkCapabilities {
    return {
      udpBroadcast: false,
      httpServer: false,
      websocketServer: false,
      mdns: true, // 通过mdns-js支持
      webrtc: true,
      p2pDataChannel: true
    };
  }
}
```

**Service Worker代理模式**：
```javascript
// sw-signaling.js - Service Worker实现
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // 拦截信令API请求
  if (url.pathname.startsWith('/api/signal/')) {
    event.respondWith(handleSignalingRequest(event.request));
  }
});

async function handleSignalingRequest(request) {
  const deviceId = extractDeviceId(request.url);
  const targetConnection = await getWebSocketConnection(deviceId);
  
  if (!targetConnection) {
    return new Response('Device not connected', { status: 404 });
  }
  
  // 转发请求到目标设备的WebSocket
  const message = await request.json();
  targetConnection.send(JSON.stringify(message));
  
  // 等待响应
  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      resolve(new Response('Timeout', { status: 408 }));
    }, 5000);
    
    // 监听响应消息
    targetConnection.onmessage = (event) => {
      clearTimeout(timeout);
      resolve(new Response(event.data, {
        headers: { 'Content-Type': 'application/json' }
      }));
    };
  });
}
```

**Electron平台实现**：
```typescript
import express from 'express';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import * as mdns from 'mdns-js';

class ElectronNetworkAdapter implements NetworkAdapter {
  private app = express();
  private server = createServer(this.app);
  private wss = new WebSocketServer({ server: this.server });
  private mdnsAdvertisement: any = null;
  
  async createSignalingServer(port?: number): Promise<SignalingServer> {
    const availablePort = port || await this.findAvailablePort();
    
    return new Promise((resolve, reject) => {
      this.server.listen(availablePort, () => {
        const signalingServer = new ExpressSignalingServer(this.app, this.wss);
        resolve(signalingServer);
      });
      
      this.server.on('error', reject);
    });
  }
  
  async advertiseDevice(device: DeviceInfo): Promise<void> {
    this.mdnsAdvertisement = mdns.createAdvertisement(
      mdns.tcp('cardmind'),
      device.httpPort,
      {
        name: device.name,
        txt: {
          deviceId: device.id,
          platform: device.platform,
          version: device.version,
          capabilities: device.capabilities.join(',')
        }
      }
    );
    
    this.mdnsAdvertisement.start();
  }
  
  getCapabilities(): NetworkCapabilities {
    return {
      udpBroadcast: true,
      httpServer: true,
      websocketServer: true,
      mdns: true,
      webrtc: true,
      p2pDataChannel: true
    };
  }
}
```

**React Native平台实现**：
```typescript
import { NativeModules } from 'react-native';

class ReactNativeNetworkAdapter implements NetworkAdapter {
  private nativeNetwork: any = NativeModules.NetworkModule;
  
  async createSignalingServer(port?: number): Promise<SignalingServer> {
    try {
      const serverPort = await this.nativeNetwork.startHTTPServer(port || 8080);
      return new NativeSignalingServer(serverPort);
    } catch (error) {
      throw new Error(`Failed to start HTTP server: ${error.message}`);
    }
  }
  
  async discoverDevices(): Promise<DeviceInfo[]> {
    // React Native使用原生mDNS实现
    const devices = await this.nativeNetwork.discoverDevices('_cardmind._tcp');
    return devices.map((device: any) => ({
      id: device.deviceId,
      name: device.name,
      address: device.address,
      port: device.port,
      platform: device.platform,
      capabilities: device.capabilities.split(',')
    }));
  }
  
  getCapabilities(): NetworkCapabilities {
    // 查询原生模块支持的能力
    return this.nativeNetwork.getNetworkCapabilities();
  }
}
```

### 3.3 智能降级策略

**降级决策引擎**：
```typescript
class NetworkFallbackManager {
  private currentStrategy: NetworkStrategy;
  private strategies: Map<string, NetworkStrategy> = new Map();
  
  constructor() {
    // 注册不同平台的最优策略
    this.strategies.set('web', new WebNetworkStrategy());
    this.strategies.set('electron', new ElectronNetworkStrategy());
    this.strategies.set('react-native', new ReactNativeNetworkStrategy());
    
    // 注册降级策略
    this.strategies.set('web-fallback', new WebFallbackStrategy());
    this.strategies.set('polling', new HTTPPollingStrategy());
  }
  
  async selectOptimalStrategy(): Promise<NetworkStrategy> {
    const platform = this.detectPlatform();
    const capabilities = await this.assessNetworkCapabilities();
    
    // 根据平台选择最优策略
    let strategy = this.strategies.get(platform);
    
    // 如果最优策略不可用，选择降级策略
    if (!await strategy.isAvailable(capabilities)) {
      strategy = await this.selectFallbackStrategy(platform, capabilities);
    }
    
    return strategy;
  }
  
  private async selectFallbackStrategy(
    platform: string, 
    capabilities: NetworkCapabilities
  ): Promise<NetworkStrategy> {
    // 按优先级选择降级策略
    const fallbackOrder = this.getFallbackOrder(platform);
    
    for (const strategyName of fallbackOrder) {
      const strategy = this.strategies.get(strategyName);
      if (strategy && await strategy.isAvailable(capabilities)) {
        return strategy;
      }
    }
    
    throw new Error('No suitable network strategy available');
  }
}
```

## 4. 存储层兼容性设计

### 4.1 统一存储接口

**抽象存储接口**：
```typescript
interface StorageAdapter {
  // 基础操作
  init(): Promise<void>;
  close(): Promise<void>;
  
  // 数据操作
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T): Promise<void>;
  delete(key: string): Promise<void>;
  clear(): Promise<void>;
  
  // 批量操作
  batchGet<T>(keys: string[]): Promise<Map<string, T>>;
  batchSet(entries: Array<[string, any]>): Promise<void>;
  
  // 查询操作
  query<T>(filter: StorageFilter): Promise<T[]>;
  
  // 同步操作
  exportData(): Promise<Uint8Array>;
  importData(data: Uint8Array): Promise<void>;
  
  // 能力检测
  getCapabilities(): StorageCapabilities;
}

interface StorageCapabilities {
  maxSize: number;        // 最大容量 (MB)
  transactional: boolean; // 事务支持
  indexed: boolean;       // 索引支持
  queryable: boolean;     // 查询支持
  binary: boolean;        // 二进制支持
  encrypted: boolean;     // 加密支持
}
```

### 4.2 平台存储实现

**Web平台存储**：
```typescript
class WebStorageAdapter implements StorageAdapter {
  private db: IDBDatabase | null = null;
  private readonly DB_NAME = 'CardMindDB';
  private readonly STORE_NAME = 'keyval';
  
  async init(): Promise<void> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.DB_NAME, 1);
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve();
      };
      
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(this.STORE_NAME)) {
          db.createObjectStore(this.STORE_NAME);
        }
      };
    });
  }
  
  async get<T>(key: string): Promise<T | null> {
    return new Promise((resolve, reject) => {
      if (!this.db) throw new Error('Database not initialized');
      
      const transaction = this.db.transaction([this.STORE_NAME], 'readonly');
      const store = transaction.objectStore(this.STORE_NAME);
      const request = store.get(key);
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result || null);
    });
  }
  
  async set<T>(key: string, value: T): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.db) throw new Error('Database not initialized');
      
      const transaction = this.db.transaction([this.STORE_NAME], 'readwrite');
      const store = transaction.objectStore(this.STORE_NAME);
      const request = store.put(value, key);
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }
  
  getCapabilities(): StorageCapabilities {
    // IndexedDB在大多数现代浏览器中支持50%的可用空间
    const estimatedQuota = navigator.storage && navigator.storage.estimate ? 
      navigator.storage.estimate() : Promise.resolve({ quota: 0 });
    
    return {
      maxSize: 0, // 动态获取
      transactional: true,
      indexed: true,
      queryable: false, // 需要额外封装
      binary: true,
      encrypted: false
    };
  }
}
```

**Electron平台存储**：
```typescript
import Database from 'better-sqlite3';
import path from 'path';
import { app } from 'electron';

class ElectronStorageAdapter implements StorageAdapter {
  private db: Database.Database | null = null;
  private readonly dbPath: string;
  
  constructor() {
    this.dbPath = path.join(app.getPath('userData'), 'cardmind.db');
  }
  
  async init(): Promise<void> {
    this.db = new Database(this.dbPath);
    
    // 创建表结构
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS storage (
        key TEXT PRIMARY KEY,
        value BLOB NOT NULL,
        timestamp INTEGER DEFAULT (strftime('%s', 'now'))
      );
      
      CREATE INDEX IF NOT EXISTS idx_storage_timestamp ON storage(timestamp);
    `);
  }
  
  async get<T>(key: string): Promise<T | null> {
    if (!this.db) throw new Error('Database not initialized');
    
    const stmt = this.db.prepare('SELECT value FROM storage WHERE key = ?');
    const row = stmt.get(key) as { value: Buffer } | undefined;
    
    if (!row) return null;
    
    try {
      return JSON.parse(row.value.toString());
    } catch (error) {
      return row.value as T;
    }
  }
  
  async set<T>(key: string, value: T): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');
    
    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO storage (key, value) VALUES (?, ?)
    `);
    
    const serializedValue = Buffer.from(JSON.stringify(value));
    stmt.run(key, serializedValue);
  }
  
  async query<T>(filter: StorageFilter): Promise<T[]> {
    if (!this.db) throw new Error('Database not initialized');
    
    const conditions = this.buildQueryConditions(filter);
    const query = `SELECT value FROM storage WHERE ${conditions.where}`;
    const stmt = this.db.prepare(query);
    
    const rows = stmt.all(...conditions.params) as Array<{ value: Buffer }>;
    return rows.map(row => JSON.parse(row.value.toString()));
  }
  
  getCapabilities(): StorageCapabilities {
    return {
      maxSize: 1024, // 1GB，实际受磁盘空间限制
      transactional: true,
      indexed: true,
      queryable: true,
      binary: true,
      encrypted: false // 可选启用
    };
  }
}
```

**React Native平台存储**：
```typescript
import SQLite from 'react-native-sqlite-storage';

class ReactNativeStorageAdapter implements StorageAdapter {
  private db: SQLite.SQLiteDatabase | null = null;
  
  async init(): Promise<void> {
    this.db = await SQLite.openDatabase({
      name: 'cardmind.db',
      location: 'default',
    });
    
    return new Promise((resolve, reject) => {
      this.db!.transaction((tx) => {
        tx.executeSql(`
          CREATE TABLE IF NOT EXISTS storage (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            timestamp INTEGER DEFAULT (datetime('now'))
          )
        `, [], () => resolve(), (_, error) => {
          reject(error);
          return false;
        });
      });
    });
  }
  
  async get<T>(key: string): Promise<T | null> {
    if (!this.db) throw new Error('Database not initialized');
    
    return new Promise((resolve, reject) => {
      this.db!.transaction((tx) => {
        tx.executeSql(
          'SELECT value FROM storage WHERE key = ?',
          [key],
          (_, result) => {
            if (result.rows.length > 0) {
              const value = result.rows.item(0).value;
              try {
                resolve(JSON.parse(value));
              } catch (error) {
                resolve(value as T);
              }
            } else {
              resolve(null);
            }
          },
          (_, error) => {
            reject(error);
            return false;
          }
        );
      });
    });
  }
  
  getCapabilities(): StorageCapabilities {
    return {
      maxSize: 50, // 50MB，iOS限制
      transactional: true,
      indexed: false, // 需要额外实现
      queryable: false,
      binary: false, // 需要Base64编码
      encrypted: false
    };
  }
}
```

### 4.3 存储能力协调

**存储策略管理器**：
```typescript
class StorageStrategyManager {
  private strategies: Map<string, StorageStrategy> = new Map();
  private currentStrategy: StorageStrategy;
  
  constructor() {
    this.initializeStrategies();
  }
  
  private initializeStrategies(): void {
    // 注册不同平台的存储策略
    this.strategies.set('web', new WebStorageStrategy());
    this.strategies.set('electron', new ElectronStorageStrategy());
    this.strategies.set('react-native', new ReactNativeStorageStrategy());
    
    // 注册降级策略
    this.strategies.set('memory', new MemoryStorageStrategy());
    this.strategies.set('local-storage', new LocalStorageStrategy());
  }
  
  async selectOptimalStrategy(): Promise<StorageStrategy> {
    const platform = this.detectPlatform();
    const capabilities = await this.assessStorageCapabilities();
    
    // 根据数据类型和平台选择最优策略
    const strategy = this.strategies.get(platform);
    
    if (strategy && await strategy.isAvailable(capabilities)) {
      return strategy;
    }
    
    // 选择降级策略
    return this.selectFallbackStrategy(capabilities);
  }
  
  async migrateData(fromStrategy: StorageStrategy, toStrategy: StorageStrategy): Promise<void> {
    const data = await fromStrategy.exportData();
    await toStrategy.importData(data);
  }
}
```

## 5. 用户界面兼容性设计

### 5.1 响应式布局策略

**断点设计系统**：
```typescript
// 统一断点定义
const BREAKPOINTS = {
  mobile: 320,   // 手机
  tablet: 768,   // 平板
  desktop: 1024, // 桌面
  wide: 1440     // 宽屏
} as const;

// 响应式工具函数
export const useResponsive = () => {
  const [width, setWidth] = useState(window.innerWidth);
  
  useEffect(() => {
    const handleResize = () => setWidth(window.innerWidth);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);
  
  return {
    isMobile: width < BREAKPOINTS.tablet,
    isTablet: width >= BREAKPOINTS.tablet && width < BREAKPOINTS.desktop,
    isDesktop: width >= BREAKPOINTS.desktop,
    isWide: width >= BREAKPOINTS.wide,
    width
  };
};
```

**平台特定UI适配**：
```typescript
// 平台检测hook
export const usePlatform = () => {
  const [platform, setPlatform] = useState<Platform>('web');
  
  useEffect(() => {
    if (window.electron) {
      setPlatform('electron');
    } else if (window.ReactNativeWebView) {
      setPlatform('react-native');
    } else {
      setPlatform('web');
    }
  }, []);
  
  return {
    platform,
    isWeb: platform === 'web',
    isElectron: platform === 'electron',
    isReactNative: platform === 'react-native'
  };
};
```

### 5.2 平台特定组件

**网络状态组件**：
```typescript
interface NetworkStatusProps {
  onDeviceClick?: (device: DeviceInfo) => void;
  compact?: boolean;
}

const NetworkStatus: React.FC<NetworkStatusProps> = ({ onDeviceClick, compact }) => {
  const { platform } = usePlatform();
  const { isMobile } = useResponsive();
  
  // 根据平台选择渲染策略
  if (platform === 'web' && !hasWebRTCSupport()) {
    return <WebNetworkUpgradePrompt />;
  }
  
  if (platform === 'react-native') {
    return <NativeNetworkStatus compact={isMobile || compact} onDeviceClick={onDeviceClick} />;
  }
  
  return (
    <DesktopNetworkStatus 
      compact={compact} 
      onDeviceClick={onDeviceClick}
      showAdvanced={platform === 'electron'}
    />
  );
};
```

**文件选择组件**：
```typescript
interface FilePickerProps {
  onFileSelect: (file: File) => void;
  accept?: string;
  multiple?: boolean;
}

const FilePicker: React.FC<FilePickerProps> = ({ onFileSelect, accept, multiple }) => {
  const { platform } = usePlatform();
  
  // Web平台使用原生文件输入
  if (platform === 'web') {
    return <WebFileInput onFileSelect={onFileSelect} accept={accept} multiple={multiple} />;
  }
  
  // Electron平台使用系统文件选择器
  if (platform === 'electron') {
    return <ElectronFilePicker onFileSelect={onFileSelect} accept={accept} multiple={multiple} />;
  }
  
  // React Native使用原生文件选择
  return <NativeFilePicker onFileSelect={onFileSelect} accept={accept} multiple={multiple} />;
};
```

## 6. 系统能力兼容性设计

### 6.1 通知系统适配

**统一通知接口**：
```typescript
interface NotificationAdapter {
  // 基础通知
  show(title: string, options?: NotificationOptions): Promise<void>;
  
  // 富通知
  showRich(notification: RichNotification): Promise<void>;
  
  // 权限管理
  requestPermission(): Promise<NotificationPermission>;
  checkPermission(): NotificationPermission;
  
  // 事件监听
  onClick(handler: (notificationId: string) => void): void;
  onClose(handler: (notificationId: string) => void): void;
}

interface NotificationOptions {
  body?: string;
  icon?: string;
  tag?: string;
  requireInteraction?: boolean;
  silent?: boolean;
}

interface RichNotification extends NotificationOptions {
  actions?: NotificationAction[];
  image?: string;
  badge?: string;
  vibrate?: number[];
}
```

**平台通知实现**：
```typescript
// Web平台通知
class WebNotificationAdapter implements NotificationAdapter {
  async requestPermission(): Promise<NotificationPermission> {
    if (!('Notification' in window)) {
      return 'denied';
    }
    
    return Notification.requestPermission();
  }
  
  async show(title: string, options?: NotificationOptions): Promise<void> {
    if (Notification.permission !== 'granted') {
      return;
    }
    
    new Notification(title, options);
  }
  
  async showRich(notification: RichNotification): Promise<void> {
    if (Notification.permission !== 'granted') {
      return;
    }
    
    // Web平台富通知支持有限
    const { actions, ...basicOptions } = notification;
    new Notification('CardMind', basicOptions);
  }
}

// Electron平台通知
class ElectronNotificationAdapter implements NotificationAdapter {
  private readonly NOTIFICATION_ICON = path.join(__dirname, 'assets', 'icon.png');
  
  async show(title: string, options?: NotificationOptions): Promise<void> {
    const notification = new Notification({
      title,
      body: options?.body || '',
      icon: this.NOTIFICATION_ICON,
      silent: options?.silent || false
    });
    
    notification.show();
  }
  
  async showRich(notification: RichNotification): Promise<void> {
    const notification = new Notification({
      title: 'CardMind',
      body: notification.body || '',
      icon: notification.icon || this.NOTIFICATION_ICON,
      actions: notification.actions?.map(action => ({
        text: action.title,
        type: 'button'
      })) || []
    });
    
    notification.show();
  }
}
```

### 6.2 后台任务管理

**后台任务接口**：
```typescript
interface BackgroundTaskAdapter {
  // 任务注册
  registerTask(taskId: string, task: BackgroundTask): Promise<void>;
  unregisterTask(taskId: string): Promise<void>;
  
  // 任务执行
  startTask(taskId: string): Promise<void>;
  stopTask(taskId: string): Promise<void>;
  
  // 状态查询
  isTaskRunning(taskId: string): boolean;
  getRunningTasks(): string[];
  
  // 能力检测
  supportsBackgroundTasks(): boolean;
}

interface BackgroundTask {
  id: string;
  name: string;
  interval?: number; // 执行间隔（毫秒）
  immediate?: boolean; // 是否立即执行
  handler: () => Promise<void>;
}
```

**平台后台实现**：
```typescript
// Web平台（使用Web Workers）
class WebBackgroundTaskAdapter implements BackgroundTaskAdapter {
  private workers: Map<string, Worker> = new Map();
  
  async registerTask(taskId: string, task: BackgroundTask): Promise<void> {
    if (!window.Worker) {
      throw new Error('Web Workers not supported');
    }
    
    const worker = new Worker('/background-tasks.js');
    worker.postMessage({
      type: 'register',
      taskId,
      task: {
        id: task.id,
        name: task.name,
        interval: task.interval
      }
    });
    
    this.workers.set(taskId, worker);
  }
  
  supportsBackgroundTasks(): boolean {
    return 'Worker' in window;
  }
}

// React Native平台（使用原生后台模块）
class ReactNativeBackgroundTaskAdapter implements BackgroundTaskAdapter {
  async registerTask(taskId: string, task: BackgroundTask): Promise<void> {
    // iOS后台任务限制较多
    if (Platform.OS === 'ios') {
      await this.registerIOSBackgroundTask(taskId, task);
    } else {
      await this.registerAndroidBackgroundTask(taskId, task);
    }
  }
  
  private async registerIOSBackgroundTask(taskId: string, task: BackgroundTask): Promise<void> {
    // iOS使用Background Fetch API
    const { BackgroundFetch } = NativeModules;
    
    await BackgroundFetch.configure({
      minimumFetchInterval: Math.floor((task.interval || 15000) / 60000), // 转换为分钟
      stopOnTerminate: false,
      startOnBoot: true
    }, async () => {
      await task.handler();
      BackgroundFetch.finish();
    });
  }
  
  private async registerAndroidBackgroundTask(taskId: string, task: BackgroundTask): Promise<void> {
    // Android使用JobScheduler
    const { BackgroundJob } = NativeModules;
    
    await BackgroundJob.schedule({
      jobKey: taskId,
      period: task.interval || 15000,
      persist: true,
      exact: false
    });
  }
}
```

## 7. 性能优化兼容性

### 7.1 内存管理策略

**内存监控接口**：
```typescript
interface MemoryManager {
  getCurrentUsage(): MemoryUsage;
  getAvailableMemory(): number;
  onMemoryWarning(handler: (level: MemoryWarningLevel) => void): void;
  
  // 内存优化
  triggerGarbageCollection(): Promise<void>;
  clearCaches(): Promise<void>;
  
  // 能力检测
  supportsMemoryMonitoring(): boolean;
}

interface MemoryUsage {
  used: number;      // 已使用内存 (MB)
  total: number;     // 总内存 (MB)
  percentage: number;  // 使用率
}

type MemoryWarningLevel = 'low' | 'medium' | 'critical';
```

**平台内存管理**：
```typescript
// Electron平台内存管理
class ElectronMemoryManager implements MemoryManager {
  async getCurrentUsage(): Promise<MemoryUsage> {
    const usage = process.memoryUsage();
    const total = require('os').totalmem();
    
    return {
      used: usage.heapUsed / 1024 / 1024,
      total: total / 1024 / 1024,
      percentage: (usage.heapUsed / total) * 100
    };
  }
  
  async triggerGarbageCollection(): Promise<void> {
    if (global.gc) {
      global.gc();
    }
  }
  
  onMemoryWarning(handler: (level: MemoryWarningLevel) => void): void {
    // 监听系统内存警告
    const { systemPreferences } = require('electron');
    systemPreferences.on('memory-warning', (level: string) => {
      handler(level as MemoryWarningLevel);
    });
  }
}

// Web平台内存管理（有限支持）
class WebMemoryManager implements MemoryManager {
  async getCurrentUsage(): Promise<MemoryUsage> {
    if ('memory' in performance) {
      const memoryInfo = (performance as any).memory;
      return {
        used: memoryInfo.usedJSHeapSize / 1024 / 1024,
        total: memoryInfo.totalJSHeapSize / 1024 / 1024,
        percentage: (memoryInfo.usedJSHeapSize / memoryInfo.totalJSHeapSize) * 100
      };
    }
    
    // 估算内存使用
    return {
      used: 0,
      total: 0,
      percentage: 0
    };
  }
  
  async triggerGarbageCollection(): Promise<void> {
    // Web平台无法手动触发GC
    // 可以通过创建大量临时对象来诱导GC
    const temp = new Array(1000000).fill(0);
    temp.length = 0;
  }
}
```

### 7.2 网络性能优化

**网络优化策略**：
```typescript
class NetworkOptimizer {
  private platform: Platform;
  private connectionType: ConnectionType = 'unknown';
  
  constructor(platform: Platform) {
    this.platform = platform;
    this.detectConnectionType();
  }
  
  async optimizeNetworkSettings(): Promise<NetworkConfig> {
    const config: NetworkConfig = {
      batchSize: this.getOptimalBatchSize(),
      heartbeatInterval: this.getOptimalHeartbeatInterval(),
      compressionEnabled: this.shouldEnableCompression(),
      encryptionLevel: this.getOptimalEncryptionLevel()
    };
    
    // 平台特定优化
    if (this.platform === 'web') {
      config.enableServiceWorkerCache = true;
      config.maxConcurrentConnections = 6; // 浏览器限制
    } else if (this.platform === 'electron') {
      config.enableTCPNoDelay = true;
      config.socketKeepAlive = true;
    } else if (this.platform === 'react-native') {
      config.enableCellularDataWarning = true;
      config.backgroundSyncEnabled = this.connectionType !== 'cellular';
    }
    
    return config;
  }
  
  private getOptimalBatchSize(): number {
    // 根据网络类型调整批处理大小
    switch (this.connectionType) {
      case 'wifi': return 50;
      case 'ethernet': return 100;
      case 'cellular': return 10;
      default: return 30;
    }
  }
  
  private detectConnectionType(): void {
    if ('connection' in navigator) {
      const connection = (navigator as any).connection;
      this.connectionType = connection.effectiveType || 'unknown';
    }
  }
}
```

## 8. 错误处理与降级

### 8.1 统一错误处理

**错误分类与处理**：
```typescript
enum ErrorType {
  NETWORK_ERROR = 'NETWORK_ERROR',
  STORAGE_ERROR = 'STORAGE_ERROR',
  PLATFORM_ERROR = 'PLATFORM_ERROR',
  PERMISSION_ERROR = 'PERMISSION_ERROR',
  COMPATIBILITY_ERROR = 'COMPATIBILITY_ERROR'
}

class CrossPlatformErrorHandler {
  private errorHandlers: Map<ErrorType, ErrorHandler> = new Map();
  
  constructor() {
    this.initializeErrorHandlers();
  }
  
  private initializeErrorHandlers(): void {
    this.errorHandlers.set(ErrorType.NETWORK_ERROR, new NetworkErrorHandler());
    this.errorHandlers.set(ErrorType.STORAGE_ERROR, new StorageErrorHandler());
    this.errorHandlers.set(ErrorType.PLATFORM_ERROR, new PlatformErrorHandler());
    this.errorHandlers.set(ErrorType.PERMISSION_ERROR, new PermissionErrorHandler());
    this.errorHandlers.set(ErrorType.COMPATIBILITY_ERROR, new CompatibilityErrorHandler());
  }
  
  async handleError(error: Error, context: ErrorContext): Promise<ErrorResolution> {
    const errorType = this.classifyError(error);
    const handler = this.errorHandlers.get(errorType);
    
    if (handler) {
      return await handler.handle(error, context);
    }
    
    // 默认错误处理
    return {
      action: 'notify',
      message: this.getUserFriendlyMessage(error, context),
      retryable: false,
      fallbackAvailable: false
    };
  }
  
  private classifyError(error: Error): ErrorType {
    if (error.message.includes('Network') || error.message.includes('Connection')) {
      return ErrorType.NETWORK_ERROR;
    }
    if (error.message.includes('Storage') || error.message.includes('Database')) {
      return ErrorType.STORAGE_ERROR;
    }
    if (error.message.includes('Permission') || error.message.includes('Access')) {
      return ErrorType.PERMISSION_ERROR;
    }
    if (error.message.includes('Not supported') || error.message.includes('Compatibility')) {
      return ErrorType.COMPATIBILITY_ERROR;
    }
    return ErrorType.PLATFORM_ERROR;
  }
}
```

### 8.2 自动降级机制

**降级决策树**：
```typescript
class AutoDegradationManager {
  private degradationRules: DegradationRule[] = [
    {
      condition: (error: Error, context: ErrorContext) => 
        error.message.includes('Service Worker') && context.platform === 'web',
      action: 'fallback-to-polling',
      priority: 1
    },
    {
      condition: (error: Error, context: ErrorContext) => 
        error.message.includes('UDP') && context.platform === 'web',
      action: 'use-mdns-only',
      priority: 2
    },
    {
      condition: (error: Error, context: ErrorContext) => 
        error.message.includes('WebRTC') && context.platform === 'react-native',
      action: 'use-websocket-relay',
      priority: 3
    },
    {
      condition: (error: Error, context: ErrorContext) => 
        error.message.includes('Storage') && context.platform === 'web',
      action: 'use-memory-storage',
      priority: 4
    }
  ];
  
  async evaluateDegradation(error: Error, context: ErrorContext): Promise<DegradationAction[]> {
    const applicableRules = this.degradationRules
      .filter(rule => rule.condition(error, context))
      .sort((a, b) => a.priority - b.priority);
    
    const actions: DegradationAction[] = [];
    
    for (const rule of applicableRules) {
      const action = await this.createDegradationAction(rule.action, error, context);
      if (action) {
        actions.push(action);
      }
    }
    
    return actions;
  }
  
  private async createDegradationAction(
    actionType: string, 
    error: Error, 
    context: ErrorContext
  ): Promise<DegradationAction | null> {
    switch (actionType) {
      case 'fallback-to-polling':
        return {
          type: 'switch-strategy',
          from: 'websocket',
          to: 'http-polling',
          description: '切换到HTTP轮询模式',
          impact: 'increased-latency'
        };
      
      case 'use-mdns-only':
        return {
          type: 'disable-feature',
          feature: 'udp-broadcast',
          alternative: 'mdns-discovery',
          description: '仅使用mDNS发现',
          impact: 'reduced-compatibility'
        };
      
      case 'use-websocket-relay':
        return {
          type: 'switch-strategy',
          from: 'p2p-webrtc',
          to: 'websocket-relay',
          description: '使用WebSocket中继',
          impact: 'increased-bandwidth'
        };
      
      default:
        return null;
    }
  }
}
```

## 9. 测试策略

### 9.1 跨平台测试矩阵

**测试覆盖矩阵**：
```
功能测试 × 平台测试 × 网络环境测试

功能测试：
├─ 设备发现
├─ 信令传输
├─ P2P连接
├─ 数据同步
├─ 离线存储
└─ 错误处理

平台测试：
├─ Web (Chrome, Firefox, Safari, Edge)
├─ Electron (Windows, macOS, Linux)
├─ React Native (Android, iOS)
└─ 模拟器与真机

网络环境测试：
├─ 局域网 (同一交换机)
├─ 跨网段 (不同子网)
├─ 防火墙环境
└─ 离线环境
```

### 9.2 自动化测试框架

**跨平台E2E测试**：
```typescript
// Playwright配置支持多平台
deviceMatrix.forEach((device) => {
  test.describe(`${device.platform} - ${device.browser}`, () => {
    test('设备发现功能', async ({ page }) => {
      // 启动本地服务
      await startMockServices(device.platform);
      
      // 导航到应用
      await page.goto('http://localhost:3000');
      
      // 等待设备发现
      await page.waitForSelector('[data-testid="device-discovered"]', { timeout: 10000 });
      
      // 验证设备列表
      const devices = await page.$$('[data-testid="device-item"]');
      expect(devices.length).toBeGreaterThan(0);
    });
    
    test('P2P连接建立', async ({ page }) => {
      // 模拟两个设备
      const device1 = await createMockDevice('device1');
      const device2 = await createMockDevice('device2');
      
      // 建立连接
      await page.click('[data-testid="connect-device-1"]');
      
      // 等待连接建立
      await page.waitForSelector('[data-testid="connection-established"]', { timeout: 5000 });
      
      // 验证数据同步
      await page.fill('[data-testid="test-input"]', 'Hello World');
      await device2.waitForSync('Hello World');
    });
  });
});
```

## 10. 部署与发布策略

### 10.1 多平台构建流程

**统一构建配置**：
```yaml
# 多平台构建配置
platforms:
  web:
    buildCommand: "pnpm build:web"
    outputDir: "dist/web"
    artifacts:
      - "dist/web/**"
    
  electron:
    buildCommand: "pnpm build:electron"
    outputDir: "dist/electron"
    targets:
      - win
      - mac
      - linux
    artifacts:
      - "dist/electron/*.exe"
      - "dist/electron/*.dmg"
      - "dist/electron/*.AppImage"
  
  react-native:
    buildCommand: "pnpm build:mobile"
    outputDir: "dist/mobile"
    targets:
      - android
      - ios
    artifacts:
      - "dist/mobile/*.apk"
      - "dist/mobile/*.ipa"

# 平台检测与构建
build:
  script: |
    # 检测平台能力
    CAPABILITIES=$(node scripts/detect-capabilities.js)
    
    # 根据能力选择构建目标
    if [[ "$CAPABILITIES" == *"electron"* ]]; then
      pnpm build:electron
    elif [[ "$CAPABILITIES" == *"react-native"* ]]; then
      pnpm build:mobile
    else
      pnpm build:web
    fi
```

### 10.2 版本管理与兼容性

**版本兼容性策略**：
```typescript
interface VersionCompatibility {
  minVersion: string;
  maxVersion: string;
  compatibleFeatures: string[];
  deprecatedFeatures: string[];
}

class VersionCompatibilityManager {
  private compatibilityMatrix: Map<string, VersionCompatibility> = new Map();
  
  constructor() {
    this.initializeCompatibilityMatrix();
  }
  
  private initializeCompatibilityMatrix(): void {
    this.compatibilityMatrix.set('1.0.0', {
      minVersion: '1.0.0',
      maxVersion: '1.9.9',
      compatibleFeatures: ['basic-sync', 'p2p-connection'],
      deprecatedFeatures: []
    });
    
    this.compatibilityMatrix.set('2.0.0', {
      minVersion: '1.5.0',
      maxVersion: '2.9.9',
      compatibleFeatures: ['basic-sync', 'p2p-connection', 'offline-sync', 'rich-media'],
      deprecatedFeatures: ['old-protocol']
    });
  }
  
  checkCompatibility(localVersion: string, remoteVersion: string): CompatibilityResult {
    const localCompat = this.compatibilityMatrix.get(this.getMajorVersion(localVersion));
    const remoteCompat = this.compatibilityMatrix.get(this.getMajorVersion(remoteVersion));
    
    if (!localCompat || !remoteCompat) {
      return { compatible: false, reason: 'Unknown version' };
    }
    
    // 检查版本范围兼容性
    if (this.isVersionInRange(remoteVersion, localCompat)) {
      return { 
        compatible: true, 
        supportedFeatures: this.getCommonFeatures(localCompat, remoteCompat)
      };
    }
    
    return { 
      compatible: false, 
      reason: 'Version range mismatch',
      suggestedAction: 'upgrade'
    };
  }
}
```

## 总结

跨平台兼容性设计方案的核心要点：

1. **抽象统一接口**：通过抽象层屏蔽平台差异
2. **平台具体实现**：针对各平台特性提供最优实现
3. **智能降级策略**：根据平台能力自动选择最佳方案
4. **渐进增强**：从基础功能到高级特性的渐进支持
5. **性能优化**：针对不同平台的性能特点进行优化
6. **错误处理**：统一的错误处理和降级机制
7. **全面测试**：覆盖所有平台和场景的测试策略

这个设计方案确保CardMind在各种平台上都能提供一致的用户体验，同时充分利用各平台的独特优势。
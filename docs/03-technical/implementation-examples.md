# 技术实现示例文档

## 1. 概述

本文档提供了CardMind项目的技术实现示例，展示了如何实现统一业务逻辑层、跨平台迁移、网络发现、存储适配以及错误处理与降级机制。这些示例代码旨在帮助开发人员理解项目的具体实现方式，并作为实际开发的参考。

## 2. 核心内容

### 2.1 统一业务逻辑层实现示例

#### 2.1.1 业务服务接口实现
```typescript
// CardService.ts - 平台无关的卡片服务
export class CardService implements ICardService {
  constructor(
    private storage: IStorageAdapter,
    private syncService: ISyncService
  ) {}

  async createCard(card: CreateCardDto): Promise<Card> {
    const newCard: Card = {
      id: generateId(),
      title: card.title,
      content: card.content,
      createdAt: new Date(),
      updatedAt: new Date(),
      isDeleted: false
    };

    await this.storage.setItem(`card:${newCard.id}`, newCard);
    await this.syncService.broadcastCardUpdate(newCard);
    
    return newCard;
  }

  async updateCard(id: string, updates: UpdateCardDto): Promise<Card> {
    const card = await this.storage.getItem<Card>(`card:${id}`);
    if (!card) throw new Error('Card not found');

    const updatedCard = { ...card, ...updates, updatedAt: new Date() };
    await this.storage.setItem(`card:${id}`, updatedCard);
    await this.syncService.broadcastCardUpdate(updatedCard);
    
    return updatedCard;
  }

  async getAllCards(): Promise<Card[]> {
    const keys = await this.storage.keys();
    const cardKeys = keys.filter(key => key.startsWith('card:'));
    const cards = await Promise.all(
      cardKeys.map(key => this.storage.getItem<Card>(key))
    );
    return cards.filter(card => card && !card.isDeleted) as Card[];
  }
}
```

#### 2.1.2 平台适配器实现
```typescript
// WebAdapter.ts - Web平台适配器
export class WebAdapter implements IPlatformAdapter {
  storage: IStorageAdapter;
  network: INetworkAdapter;
  system: ISystemAdapter;

  constructor() {
    this.storage = new IndexedDBAdapter();
    this.network = new WebNetworkAdapter();
    this.system = new WebSystemAdapter();
  }

  getCapabilities(): PlatformCapabilities {
    return {
      network: {
        udpBroadcast: false, // Service Worker模拟支持
        httpServer: false,   // Service Worker处理
        websocketServer: false,
        websocketClient: true,
        mdns: false,         // Service Worker + mDNS.js
        webrtc: true,
        p2pDataChannel: true
      },
      storage: {
        maxSize: 50 * 1024 * 1024, // 50MB
        transactional: true,
        indexed: true,
        queryable: true,
        binary: true
      },
      system: {
        backgroundTasks: 'serviceWorker' in navigator,
        notifications: 'Notification' in window,
        fileSystem: 'showOpenFilePicker' in window,
        autoStart: false
      }
    };
  }
}
```

#### 2.1.3 平台能力检测实现
```typescript
// PlatformCapabilities.ts - 平台能力检测
export class PlatformCapabilities {
  static detect(): PlatformCapabilities {
    const userAgent = navigator.userAgent.toLowerCase();
    const isElectron = userAgent.includes('electron');
    const isReactNative = typeof navigator !== 'undefined' && navigator.product === 'ReactNative';
    
    if (isElectron) {
      return this.getElectronCapabilities();
    } else if (isReactNative) {
      return this.getReactNativeCapabilities();
    } else {
      return this.getWebCapabilities();
    }
  }

  private static getWebCapabilities(): PlatformCapabilities {
    return {
      network: {
        udpBroadcast: 'serviceWorker' in navigator,
        httpServer: false,
        websocketServer: false,
        websocketClient: 'WebSocket' in window,
        mdns: false,
        webrtc: 'RTCPeerConnection' in window,
        p2pDataChannel: 'RTCPeerConnection' in window
      },
      storage: {
        maxSize: this.getIndexedDBQuota(),
        transactional: true,
        indexed: true,
        queryable: true,
        binary: true
      },
      system: {
        backgroundTasks: 'serviceWorker' in navigator,
        notifications: 'Notification' in window,
        fileSystem: 'showOpenFilePicker' in window,
        autoStart: false
      }
    };
  }

  private static getElectronCapabilities(): PlatformCapabilities {
    return {
      network: {
        udpBroadcast: true,
        httpServer: true,
        websocketServer: true,
        websocketClient: true,
        mdns: true,
        webrtc: true,
        p2pDataChannel: true
      },
      storage: {
        maxSize: 1024 * 1024 * 1024, // 1GB
        transactional: true,
        indexed: true,
        queryable: true,
        binary: true
      },
      system: {
        backgroundTasks: true,
        notifications: true,
        fileSystem: true,
        autoStart: true
      }
    };
  }

  private static getReactNativeCapabilities(): PlatformCapabilities {
    return {
      network: {
        udpBroadcast: true,
        httpServer: true,
        websocketServer: true,
        websocketClient: true,
        mdns: true,
        webrtc: true,
        p2pDataChannel: true
      },
      storage: {
        maxSize: 100 * 1024 * 1024, // 100MB
        transactional: false,
        indexed: false,
        queryable: false,
        binary: false
      },
      system: {
        backgroundTasks: true,
        notifications: true,
        fileSystem: false,
        autoStart: false
      }
    };
  }
}
```

### 2.2 跨平台迁移实现示例

#### 2.2.1 Web → Electron迁移
```typescript
// electron-main.ts - Electron主进程
import { CardService } from './services/CardService';
import { SyncService } from './services/SyncService';
import { ElectronAdapter } from './adapters/ElectronAdapter';
import { createExpressServer } from './server/express-server';

class ElectronMain {
  private cardService: ICardService;
  private syncService: ISyncService;
  private adapter: IPlatformAdapter;
  private expressServer: Express;

  constructor() {
    // 复用Web平台的业务逻辑
    this.adapter = new ElectronAdapter();
    this.syncService = new SyncService(this.adapter.network);
    this.cardService = new CardService(this.adapter.storage, this.syncService);
    
    // 创建Express服务器（复用Web后端代码）
    this.expressServer = createExpressServer(this.cardService, this.syncService);
  }

  async initialize() {
    // 启动HTTP服务器
    await this.startHttpServer();
    
    // 初始化业务服务
    await this.syncService.initialize();
    
    // 设置IPC通信
    this.setupIpcCommunication();
  }

  private setupIpcCommunication() {
    // IPC通信替代HTTP通信
    ipcMain.handle('card:create', async (event, card) => {
      return await this.cardService.createCard(card);
    });

    ipcMain.handle('card:update', async (event, id, updates) => {
      return await this.cardService.updateCard(id, updates);
    });

    ipcMain.handle('sync:joinNetwork', async (event, accessCode) => {
      return await this.syncService.joinNetwork(accessCode);
    });
  }
}
```

#### 2.2.2 Web → React Native迁移
```typescript
// App.tsx - React Native应用入口
import { CardService } from './services/CardService';
import { SyncService } from './services/SyncService';
import { ReactNativeAdapter } from './adapters/ReactNativeAdapter';
import { NativeHttpServer } from './native/HttpServer';

export default function App() {
  const [cardService, setCardService] = useState<ICardService | null>(null);
  const [syncService, setSyncService] = useState<ISyncService | null>(null);

  useEffect(() => {
    initializeServices();
  }, []);

  const initializeServices = async () => {
    // 创建平台适配器
    const adapter = new ReactNativeAdapter();
    
    // 启动原生HTTP服务器
    const httpServer = new NativeHttpServer();
    await httpServer.start(8080);
    
    // 复用Web平台的业务逻辑
    const syncService = new SyncService(adapter.network);
    const cardService = new CardService(adapter.storage, syncService);
    
    setSyncService(syncService);
    setCardService(cardService);
    
    // 初始化服务
    await syncService.initialize();
  };

  return (
    <ServiceProvider cardService={cardService} syncService={syncService}>
      <NavigationContainer>
        <Stack.Navigator>
          <Stack.Screen name="CardList" component={CardListScreen} />
          <Stack.Screen name="CardEditor" component={CardEditorScreen} />
        </Stack.Navigator>
      </NavigationContainer>
    </ServiceProvider>
  );
}
```

### 2.3 网络发现实现示例

#### 2.3.1 统一发现机制
```typescript
// DiscoveryService.ts - 平台无关的设备发现服务
export class DiscoveryService implements IDiscoveryService {
  constructor(
    private networkAdapter: INetworkAdapter,
    private platformAdapter: IPlatformAdapter
  ) {}

  async startDiscovery(): Promise<void> {
    const capabilities = this.platformAdapter.getCapabilities();
    
    if (capabilities.network.mdns) {
      // 使用mDNS/Bonjour进行设备发现
      await this.startMdnsDiscovery();
    } else if (capabilities.network.udpBroadcast) {
      // 使用UDP广播进行设备发现
      await this.startUdpDiscovery();
    } else {
      // 降级到手动输入IP地址
      console.log('设备发现功能受限，请手动输入设备IP地址');
    }
  }

  private async startMdnsDiscovery(): Promise<void> {
    const mdns = this.networkAdapter.createMdnsService();
    
    // 广播自己的服务
    await mdns.advertise({
      name: 'CardMind-' + this.platformAdapter.system.getDeviceId(),
      type: '_cardmind._tcp',
      port: 8080,
      txt: {
        version: '1.0.0',
        platform: this.platformAdapter.system.getPlatform()
      }
    });

    // 发现其他设备
    mdns.on('serviceUp', (service) => {
      if (service.type === '_cardmind._tcp') {
        this.handleDeviceDiscovered({
          deviceId: service.name.replace('CardMind-', ''),
          deviceName: service.txt?.deviceName || 'Unknown Device',
          platform: service.txt?.platform || 'unknown',
          address: service.addresses[0],
          port: service.port
        });
      }
    });
  }

  private async startUdpDiscovery(): Promise<void> {
    const udpSocket = this.networkAdapter.createUdpSocket();
    
    // 定期发送广播消息
    const broadcastMessage = JSON.stringify({
      type: 'discovery',
      deviceId: this.platformAdapter.system.getDeviceId(),
      deviceName: this.platformAdapter.system.getDeviceName(),
      platform: this.platformAdapter.system.getPlatform()
    });

    setInterval(() => {
      udpSocket.send(broadcastMessage, 5353, '255.255.255.255');
    }, 5000);

    // 监听响应
    udpSocket.on('message', (message, remote) => {
      try {
        const data = JSON.parse(message.toString());
        if (data.type === 'discovery-response') {
          this.handleDeviceDiscovered({
            deviceId: data.deviceId,
            deviceName: data.deviceName,
            platform: data.platform,
            address: remote.address,
            port: data.port
          });
        }
      } catch (error) {
        console.error('解析发现消息失败:', error);
      }
    });
  }

  private handleDeviceDiscovered(device: DiscoveredDevice): void {
    console.log('发现设备:', device.deviceName, '地址:', device.address);
    // 触发设备发现事件
    this.emit('deviceDiscovered', device);
  }
}
```

#### 2.3.2 Web平台Service Worker实现
```typescript
// service-worker-discovery.js - Web平台设备发现
class ServiceWorkerDiscovery {
  constructor() {
    this.mdns = new MdnsJs();
    this.discoveredDevices = new Map();
  }

  async initialize() {
    // 注册Service Worker
    if ('serviceWorker' in navigator) {
      const registration = await navigator.serviceWorker.register('/sw-discovery.js');
      console.log('Service Worker注册成功');
      
      // 设置消息通道
      this.setupMessageChannel();
    }
  }

  setupMessageChannel() {
    const channel = new MessageChannel();
    
    // 向Service Worker发送发现请求
    navigator.serviceWorker.controller?.postMessage({
      type: 'START_DISCOVERY'
    }, [channel.port2]);

    // 接收发现的设备
    channel.port1.onmessage = (event) => {
      if (event.data.type === 'DEVICE_DISCOVERED') {
        this.handleDeviceDiscovered(event.data.device);
      }
    };
  }

  // Service Worker中的发现逻辑
  async handleDiscoveryInWorker() {
    // 使用mDNS.js库进行服务发现
    const browser = this.mdns.createBrowser('_cardmind._tcp');
    
    browser.on('serviceUp', (service) => {
      const device = {
        deviceId: service.name.replace('CardMind-', ''),
        deviceName: service.txt?.deviceName || 'Unknown Device',
        platform: service.txt?.platform || 'unknown',
        address: service.addresses[0],
        port: service.port
      };

      // 发送给主线程
      self.clients.matchAll().then(clients => {
        clients.forEach(client => {
          client.postMessage({
            type: 'DEVICE_DISCOVERED',
            device: device
          });
        });
      });
    });

    browser.start();
  }
}
```

### 2.4 存储适配实现示例

#### 2.4.1 统一存储接口
```typescript
// IndexedDBAdapter.ts - Web平台存储适配器
export class IndexedDBAdapter implements IStorageAdapter {
  private db: IDBDatabase | null = null;
  private readonly dbName = 'CardMindDB';
  private readonly storeName = 'cards';

  async initialize(): Promise<void> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, 1);
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve();
      };
      
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(this.storeName)) {
          const store = db.createObjectStore(this.storeName, { keyPath: 'id' });
          store.createIndex('title', 'title', { unique: false });
          store.createIndex('createdAt', 'createdAt', { unique: false });
        }
      };
    });
  }

  async getItem<T>(key: string): Promise<T | null> {
    if (!this.db) await this.initialize();
    
    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction([this.storeName], 'readonly');
      const store = transaction.objectStore(this.storeName);
      const request = store.get(key);
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result || null);
    });
  }

  async setItem<T>(key: string, value: T): Promise<void> {
    if (!this.db) await this.initialize();
    
    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction([this.storeName], 'readwrite');
      const store = transaction.objectStore(this.storeName);
      const request = store.put({ id: key, ...value });
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async removeItem(key: string): Promise<void> {
    if (!this.db) await this.initialize();
    
    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction([this.storeName], 'readwrite');
      const store = transaction.objectStore(this.storeName);
      const request = store.delete(key);
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve();
    });
  }

  async keys(): Promise<string[]> {
    if (!this.db) await this.initialize();
    
    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction([this.storeName], 'readonly');
      const store = transaction.objectStore(this.storeName);
      const request = store.getAllKeys();
      
      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result as string[]);
    });
  }
}
```

#### 2.4.2 React Native存储适配器
```typescript
// AsyncStorageAdapter.ts - React Native存储适配器
import AsyncStorage from '@react-native-async-storage/async-storage';

export class AsyncStorageAdapter implements IStorageAdapter {
  async getItem<T>(key: string): Promise<T | null> {
    try {
      const value = await AsyncStorage.getItem(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      console.error('AsyncStorage getItem error:', error);
      return null;
    }
  }

  async setItem<T>(key: string, value: T): Promise<void> {
    try {
      await AsyncStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.error('AsyncStorage setItem error:', error);
      throw error;
    }
  }

  async removeItem(key: string): Promise<void> {
    try {
      await AsyncStorage.removeItem(key);
    } catch (error) {
      console.error('AsyncStorage removeItem error:', error);
      throw error;
    }
  }

  async clear(): Promise<void> {
    try {
      await AsyncStorage.clear();
    } catch (error) {
      console.error('AsyncStorage clear error:', error);
      throw error;
    }
  }

  async keys(): Promise<string[]> {
    try {
      return await AsyncStorage.getAllKeys();
    } catch (error) {
      console.error('AsyncStorage keys error:', error);
      return [];
    }
  }
}
```

### 2.5 错误处理与降级机制

#### 2.5.1 统一错误处理
```typescript
// ErrorHandler.ts - 跨平台错误处理
export class ErrorHandler {
  constructor(
    private platformAdapter: IPlatformAdapter,
    private fallbackStrategy: FallbackStrategy
  ) {}

  async handleError(error: Error, context: ErrorContext): Promise<void> {
    console.error('Error occurred:', error, 'Context:', context);

    // 根据错误类型和平台能力选择降级策略
    const capabilities = this.platformAdapter.getCapabilities();
    
    if (error instanceof NetworkError) {
      await this.handleNetworkError(error, capabilities);
    } else if (error instanceof StorageError) {
      await this.handleStorageError(error, capabilities);
    } else {
      // 未知错误，使用通用降级策略
      await this.fallbackStrategy.handleUnknownError(error, context);
    }
  }

  private async handleNetworkError(error: NetworkError, capabilities: PlatformCapabilities): Promise<void> {
    if (capabilities.network.websocketClient) {
      // 尝试使用WebSocket连接
      console.log('尝试WebSocket连接作为降级方案');
      await this.fallbackStrategy.tryWebSocketConnection();
    } else if (capabilities.storage.maxSize > 0) {
      // 降级到本地存储
      console.log('网络不可用，降级到本地存储模式');
      await this.fallbackStrategy.enableOfflineMode();
    } else {
      // 最终降级到内存存储
      console.log('使用内存存储作为最终降级方案');
      await this.fallbackStrategy.enableMemoryMode();
    }
  }

  private async handleStorageError(error: StorageError, capabilities: PlatformCapabilities): Promise<void> {
    if (capabilities.storage.indexed && 'indexedDB' in window) {
      // 尝试使用IndexedDB
      console.log('尝试IndexedDB作为降级方案');
      await this.fallbackStrategy.tryIndexedDB();
    } else if (capabilities.storage.maxSize > 0) {
      // 降级到LocalStorage
      console.log('降级到LocalStorage');
      await this.fallbackStrategy.tryLocalStorage();
    } else {
      // 最终降级到内存存储
      console.log('使用内存存储作为最终降级方案');
      await this.fallbackStrategy.enableMemoryMode();
    }
  }
}
```

## 3. 注意事项

### 3.1 架构设计注意事项

#### 3.1.1 接口设计
- 保持接口的简洁性和一致性，避免过度设计
- 使用TypeScript类型系统确保接口的类型安全
- 为所有接口提供清晰的文档说明

#### 3.1.2 状态管理
- 避免在适配器层直接操作业务状态
- 使用观察者模式或事件系统处理跨组件状态同步
- 确保状态变更的可预测性和可追踪性

#### 3.1.3 错误处理
- 实现统一的错误处理机制，确保错误信息的一致性
- 提供有意义的错误消息，便于问题定位和解决
- 设计合理的降级策略，确保应用在部分功能失效时仍可正常使用

### 3.2 实施风险注意事项

#### 3.2.1 渐进式实施
- 采用渐进式迁移策略，避免大规模重构带来的风险
- 优先实现核心功能，逐步扩展平台适配范围
- 建立完善的测试体系，确保每次变更不会破坏现有功能

#### 3.2.2 测试策略
- 实现跨平台测试框架，确保代码在各平台的一致性
- 使用模拟对象隔离平台依赖，提高测试效率
- 建立自动化测试流程，减少人为错误

#### 3.2.3 性能监控
- 实现性能监控机制，及时发现和解决性能问题
- 建立性能基准，确保各平台性能表现符合预期
- 定期进行性能优化，保持应用的高效运行

### 3.3 团队协作注意事项

#### 3.3.1 技能要求
- 确保团队成员熟悉TypeScript和现代前端开发技术
- 提供跨平台开发培训，提高团队整体技术水平
- 建立技术分享机制，促进知识传播和经验积累

#### 3.3.2 代码规范
- 制定统一的代码规范，确保代码风格的一致性
- 使用代码检查工具，自动发现和修复常见问题
- 定期进行代码审查，提高代码质量和可维护性

#### 3.3.3 文档维护
- 保持文档与代码的同步更新，确保文档的准确性
- 提供详细的API文档和使用示例，降低学习成本
- 建立文档审查机制，确保文档质量和完整性

## 4. 相关文档

- [技术栈文档](0301-tech-stack.md) - 详细的技术栈介绍
- [技术概念文档](0302-tech-concepts.md) - 核心技术概念解析
- [统一业务逻辑架构设计](0302-unified-business-logic-design.md) - 架构设计原则和分层结构
- [实现计划文档](0303-implementation-plan.md) - 项目实施计划和里程碑
- [跨平台架构设计](0306-cross-platform-architecture.md) - 跨平台技术架构详细设计
- [纯离线局域网组网架构](0308-offline-lan-architecture.md) - 局域网组网技术方案
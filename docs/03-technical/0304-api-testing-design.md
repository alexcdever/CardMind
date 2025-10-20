# CardMind API与测试计划

## 1. API设计与单元测试

### 1.1 AuthService API

#### 接口定义
```typescript
/**
 * 认证服务类，负责网络ID生成和验证
 */
class AuthService {
  /**
   * 生成新的网络ID
   * @returns 生成的网络UUID
   */
  generateNetworkId(): string;
  
  /**
   * 验证网络ID格式
   * @param networkId 待验证的网络ID
   * @returns 验证结果
   */
  validateNetworkId(networkId: string): boolean;
  
  /**
   * 加入网络
   * @param networkId 网络ID
   * @returns 是否成功加入
   */
  joinNetwork(networkId: string): Promise<boolean>;
  
  /**
   * 获取当前网络ID
   * @returns 当前网络ID或null
   */
  getCurrentNetworkId(): string | null;
  
  /**
   * 离开当前网络
   */
  leaveNetwork(): void;
}
```

#### 单元测试
```typescript
// AuthService.test.ts
import { AuthService } from '@/services/AuthService';

describe('AuthService', () => {
  let authService: AuthService;
  
  beforeEach(() => {
    authService = new AuthService();
    // 清除所有存储的网络ID
    localStorage.removeItem('currentNetworkId');
  });
  
  test('should generate valid UUID as networkId', () => {
    const networkId = authService.generateNetworkId();
    expect(networkId).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
  });
  
  test('should validate correct networkId format', () => {
    const validId = '123e4567-e89b-12d3-a456-426614174000';
    expect(authService.validateNetworkId(validId)).toBe(true);
  });
  
  test('should reject invalid networkId format', () => {
    const invalidId = 'invalid-id';
    expect(authService.validateNetworkId(invalidId)).toBe(false);
  });
  
  test('should join network successfully', async () => {
    const networkId = '123e4567-e89b-12d3-a456-426614174000';
    const result = await authService.joinNetwork(networkId);
    expect(result).toBe(true);
    expect(authService.getCurrentNetworkId()).toBe(networkId);
  });
  
  test('should return null when no network is joined', () => {
    expect(authService.getCurrentNetworkId()).toBeNull();
  });
  
  test('should leave network successfully', () => {
    const networkId = '123e4567-e89b-12d3-a456-426614174000';
    authService.joinNetwork(networkId);
    authService.leaveNetwork();
    expect(authService.getCurrentNetworkId()).toBeNull();
  });
});
```

### 1.2 DeviceService API

#### 接口定义
```typescript
/**
 * 设备管理服务类，负责设备ID生成和昵称管理
 */
class DeviceService {
  /**
   * 生成设备ID（结合设备指纹和随机UUID）
   * @returns 设备唯一标识符
   */
  generateDeviceId(): string;
  
  /**
   * 获取当前设备ID
   * @returns 设备ID
   */
  getDeviceId(): string;
  
  /**
   * 设置设备昵称
   * @param nickname 设备昵称
   */
  setDeviceNickname(nickname: string): void;
  
  /**
   * 获取设备昵称
   * @returns 设备昵称
   */
  getDeviceNickname(): string;
  
  /**
   * 获取设备类型
   * @returns 设备类型
   */
  getDeviceType(): string;
  
  /**
   * 更新设备最后在线时间
   */
  updateLastSeen(): void;
  
  /**
   * 获取设备信息
   * @returns 设备完整信息
   */
  getDeviceInfo(): DeviceInfo;
}

interface DeviceInfo {
  id: string;
  nickname: string;
  deviceType: string;
  createdAt: number;
  lastSeen: number;
}
```

#### 单元测试
```typescript
// DeviceService.test.ts
import { DeviceService } from '@/services/DeviceService';

describe('DeviceService', () => {
  let deviceService: DeviceService;
  
  beforeEach(() => {
    deviceService = new DeviceService();
    // 清除本地存储的设备信息
    localStorage.removeItem('deviceId');
    localStorage.removeItem('deviceNickname');
  });
  
  test('should generate deviceId successfully', () => {
    const deviceId = deviceService.generateDeviceId();
    expect(deviceId).toBeTruthy();
    expect(typeof deviceId).toBe('string');
  });
  
  test('should return consistent deviceId', () => {
    const deviceId1 = deviceService.getDeviceId();
    const deviceId2 = deviceService.getDeviceId();
    expect(deviceId1).toBe(deviceId2);
  });
  
  test('should set and get device nickname', () => {
    const nickname = '测试设备';
    deviceService.setDeviceNickname(nickname);
    expect(deviceService.getDeviceNickname()).toBe(nickname);
  });
  
  test('should return default nickname if not set', () => {
    const nickname = deviceService.getDeviceNickname();
    expect(nickname).toMatch(/^设备类型/);
  });
  
  test('should get valid device type', () => {
    const deviceType = deviceService.getDeviceType();
    expect(['desktop', 'mobile', 'tablet']).toContain(deviceType);
  });
  
  test('should update last seen time', () => {
    const info1 = deviceService.getDeviceInfo();
    deviceService.updateLastSeen();
    const info2 = deviceService.getDeviceInfo();
    expect(info2.lastSeen).toBeGreaterThanOrEqual(info1.lastSeen);
  });
  
  test('should return complete device info', () => {
    const info = deviceService.getDeviceInfo();
    expect(info).toHaveProperty('id');
    expect(info).toHaveProperty('nickname');
    expect(info).toHaveProperty('deviceType');
    expect(info).toHaveProperty('createdAt');
    expect(info).toHaveProperty('lastSeen');
  });
});
```

### 1.3 CardService API

#### 接口定义
```typescript
/**
 * 卡片服务类，负责卡片的增删改查操作
 */
class CardService {
  /**
   * 创建新卡片
   * @param cardData 卡片数据
   * @returns 创建的卡片
   */
  createCard(cardData: Partial<Card>): Promise<Card>;
  
  /**
   * 获取卡片
   * @param cardId 卡片ID
   * @returns 卡片对象或null
   */
  getCard(cardId: string): Promise<Card | null>;
  
  /**
   * 获取所有非删除状态的卡片
   * @returns 卡片列表
   */
  getAllCards(): Promise<Card[]>;
  
  /**
   * 获取所有已删除卡片
   * @returns 已删除卡片列表
   */
  getDeletedCards(): Promise<Card[]>;
  
  /**
   * 更新卡片
   * @param cardId 卡片ID
   * @param updates 更新内容
   * @returns 更新后的卡片
   */
  updateCard(cardId: string, updates: Partial<Card>): Promise<Card>;
  
  /**
   * 软删除卡片
   * @param cardId 卡片ID
   * @returns 是否删除成功
   */
  deleteCard(cardId: string): Promise<boolean>;
  
  /**
   * 恢复已删除卡片
   * @param cardId 卡片ID
   * @returns 恢复后的卡片
   */
  restoreCard(cardId: string): Promise<Card>;
  
  /**
   * 从Yjs同步数据到IndexedDB
   * @param yjsDoc Yjs文档
   */
  syncFromYjsToIndexedDB(yjsDoc: Y.Doc): Promise<void>;
  
  /**
   * 同步所有卡片
   */
  syncAllCardsFromYjs(): Promise<void>;
  
  /**
   * 为已有卡片创建Yjs文档
   * @param cardId 卡片ID
   * @returns Yjs文档
   */
  createYjsDocForExistingCard(cardId: string): Promise<Y.Doc>;
}

interface Card {
  id: string;
  title: string;
  content: string;
  tags?: string[];
  createdAt: number;
  updatedAt: number;
  deleted: boolean;
  deletedAt?: number;
  lastModifiedBy: string;
}
```

#### 单元测试
```typescript
// CardService.test.ts
import { CardService } from '@/services/CardService';
import { getYjsDoc } from '@/utils/testUtils';

describe('CardService', () => {
  let cardService: CardService;
  
  beforeEach(async () => {
    cardService = new CardService();
    // 清空测试数据库
    await cardService.clearTestData();
  });
  
  test('should create a new card successfully', async () => {
    const cardData = {
      title: '测试卡片',
      content: '测试内容'
    };
    
    const card = await cardService.createCard(cardData);
    
    expect(card).toHaveProperty('id');
    expect(card.title).toBe(cardData.title);
    expect(card.content).toBe(cardData.content);
    expect(card.deleted).toBe(false);
    expect(card).toHaveProperty('createdAt');
    expect(card).toHaveProperty('updatedAt');
  });
  
  test('should get card by id', async () => {
    const card = await cardService.createCard({ title: '测试', content: '内容' });
    const fetchedCard = await cardService.getCard(card.id);
    
    expect(fetchedCard).not.toBeNull();
    expect(fetchedCard?.id).toBe(card.id);
  });
  
  test('should return null for non-existent card', async () => {
    const card = await cardService.getCard('non-existent-id');
    expect(card).toBeNull();
  });
  
  test('should get all non-deleted cards', async () => {
    await cardService.createCard({ title: '卡片1', content: '内容1' });
    await cardService.createCard({ title: '卡片2', content: '内容2' });
    
    const cards = await cardService.getAllCards();
    
    expect(cards.length).toBe(2);
    expect(cards.every(c => !c.deleted)).toBe(true);
  });
  
  test('should update card successfully', async () => {
    const card = await cardService.createCard({ title: '原标题', content: '原内容' });
    const updates = { title: '新标题', content: '新内容' };
    
    const updatedCard = await cardService.updateCard(card.id, updates);
    
    expect(updatedCard.title).toBe(updates.title);
    expect(updatedCard.content).toBe(updates.content);
    expect(updatedCard.updatedAt).toBeGreaterThan(card.updatedAt);
  });
  
  test('should soft delete card', async () => {
    const card = await cardService.createCard({ title: '测试', content: '内容' });
    
    const result = await cardService.deleteCard(card.id);
    const deletedCard = await cardService.getDeletedCards();
    const activeCards = await cardService.getAllCards();
    
    expect(result).toBe(true);
    expect(deletedCard.length).toBe(1);
    expect(deletedCard[0].deleted).toBe(true);
    expect(activeCards.length).toBe(0);
  });
  
  test('should restore deleted card', async () => {
    const card = await cardService.createCard({ title: '测试', content: '内容' });
    await cardService.deleteCard(card.id);
    
    const restoredCard = await cardService.restoreCard(card.id);
    const deletedCards = await cardService.getDeletedCards();
    const activeCards = await cardService.getAllCards();
    
    expect(restoredCard.deleted).toBe(false);
    expect(deletedCards.length).toBe(0);
    expect(activeCards.length).toBe(1);
  });
  
  test('should sync from Yjs to IndexedDB', async () => {
    const yjsDoc = getYjsDoc();
    const map = yjsDoc.getMap('card');
    map.set('id', 'test-id');
    map.set('title', 'Yjs同步测试');
    map.set('content', '同步内容');
    
    await cardService.syncFromYjsToIndexedDB(yjsDoc);
    
    const card = await cardService.getCard('test-id');
    expect(card).not.toBeNull();
    expect(card?.title).toBe('Yjs同步测试');
  });
});
```

### 1.4 EncryptionService API

#### 接口定义
```typescript
/**
 * 加密服务类，负责数据加密和解密
 */
class EncryptionService {
  /**
   * 生成加密密钥
   * @param password 用户密码
   * @returns 加密密钥
   */
  generateKey(password: string): Promise<CryptoKey>;
  
  /**
   * 加密数据
   * @param data 待加密数据
   * @param key 加密密钥
   * @returns 加密后的数据
   */
  encrypt(data: string, key: CryptoKey): Promise<string>;
  
  /**
   * 解密数据
   * @param encryptedData 加密数据
   * @param key 解密密钥
   * @returns 解密后的数据
   */
  decrypt(encryptedData: string, key: CryptoKey): Promise<string>;
  
  /**
   * 导出密钥为字符串
   * @param key 加密密钥
   * @returns 密钥字符串
   */
  exportKey(key: CryptoKey): Promise<string>;
  
  /**
   * 从字符串导入密钥
   * @param keyStr 密钥字符串
   * @returns 加密密钥
   */
  importKey(keyStr: string): Promise<CryptoKey>;
  
  /**
   * 验证密码强度
   * @param password 用户密码
   * @returns 密码强度评估
   */
  validatePasswordStrength(password: string): PasswordStrength;
}

interface PasswordStrength {
  valid: boolean;
  strength: 'weak' | 'medium' | 'strong';
  suggestions: string[];
}
```

#### 单元测试
```typescript
// EncryptionService.test.ts
import { EncryptionService } from '@/services/EncryptionService';

describe('EncryptionService', () => {
  let encryptionService: EncryptionService;
  
  beforeEach(() => {
    encryptionService = new EncryptionService();
  });
  
  test('should generate encryption key', async () => {
    const key = await encryptionService.generateKey('test-password');
    expect(key).toBeInstanceOf(CryptoKey);
  });
  
  test('should encrypt and decrypt data', async () => {
    const password = 'test-strong-password';
    const originalData = 'This is test data for encryption';
    
    const key = await encryptionService.generateKey(password);
    const encrypted = await encryptionService.encrypt(originalData, key);
    const decrypted = await encryptionService.decrypt(encrypted, key);
    
    expect(encrypted).not.toBe(originalData); // 确保加密后数据不同
    expect(decrypted).toBe(originalData); // 确保解密后恢复原始数据
  });
  
  test('should export and import key', async () => {
    const key = await encryptionService.generateKey('test-password');
    const exportedKey = await encryptionService.exportKey(key);
    
    expect(typeof exportedKey).toBe('string');
    
    const importedKey = await encryptionService.importKey(exportedKey);
    expect(importedKey).toBeInstanceOf(CryptoKey);
  });
  
  test('should validate password strength correctly', () => {
    // 弱密码测试
    const weakResult = encryptionService.validatePasswordStrength('123456');
    expect(weakResult.valid).toBe(false);
    expect(weakResult.strength).toBe('weak');
    
    // 中等密码测试
    const mediumResult = encryptionService.validatePasswordStrength('Password123');
    expect(mediumResult.valid).toBe(true);
    expect(mediumResult.strength).toBe('medium');
    
    // 强密码测试
    const strongResult = encryptionService.validatePasswordStrength('P@ssw0rd!234ABC');
    expect(strongResult.valid).toBe(true);
    expect(strongResult.strength).toBe('strong');
  });
});
```

### 1.5 SyncService API

#### 接口定义
```typescript
/**
 * 同步服务类，负责多设备数据同步
 */
class SyncService {
  /**
   * 初始化同步服务
   * @param networkId 网络ID
   */
  initialize(networkId: string): Promise<void>;
  
  /**
   * 创建卡片同步实例
   * @param cardId 卡片ID
   * @returns 同步实例
   */
  createCardSync(cardId: string): Promise<CardSyncInstance>;
  
  /**
   * 销毁卡片同步实例
   * @param cardId 卡片ID
   */
  destroyCardSync(cardId: string): void;
  
  /**
   * 获取当前连接的对等节点
   * @returns 对等节点信息列表
   */
  getPeers(): PeerInfo[];
  
  /**
   * 监听同步状态变化
   * @param callback 状态变化回调
   * @returns 取消监听函数
   */
  onSyncStatusChange(callback: (status: SyncStatus) => void): () => void;
  
  /**
   * 监听网络活动
   * @param callback 活动回调
   * @returns 取消监听函数
   */
  onNetworkActivity(callback: (activity: NetworkActivity) => void): () => void;
  
  /**
   * 手动触发同步
   */
  triggerSync(): Promise<void>;
  
  /**
   * 断开同步连接
   */
  disconnect(): void;
}

interface CardSyncInstance {
  ydoc: Y.Doc;
  provider: WebrtcProvider;
  map: Y.Map<any>;
  destroy: () => void;
}

interface PeerInfo {
  id: string;
  nickname?: string;
  deviceType?: string;
  connected: boolean;
}

interface SyncStatus {
  connected: boolean;
  syncing: boolean;
  lastSyncTime?: number;
  peersCount: number;
}

interface NetworkActivity {
  type: 'join' | 'leave' | 'update';
  peerId: string;
  timestamp: number;
  details?: any;
}
```

#### 单元测试
```typescript
// SyncService.test.ts
import { SyncService } from '@/services/SyncService';
import { mockWebRTCProvider } from '@/utils/testMocks';

describe('SyncService', () => {
  let syncService: SyncService;
  const mockNetworkId = 'test-network-id';
  
  beforeEach(async () => {
    // 模拟WebRTC Provider
    jest.mock('y-webrtc', () => ({
      WebrtcProvider: mockWebRTCProvider
    }));
    
    syncService = new SyncService();
    await syncService.initialize(mockNetworkId);
  });
  
  afterEach(() => {
    syncService.disconnect();
    jest.clearAllMocks();
  });
  
  test('should initialize sync service successfully', async () => {
    // 验证初始化逻辑
    expect(syncService).toBeTruthy();
  });
  
  test('should create card sync instance', async () => {
    const cardId = 'test-card-id';
    const syncInstance = await syncService.createCardSync(cardId);
    
    expect(syncInstance).toHaveProperty('ydoc');
    expect(syncInstance).toHaveProperty('provider');
    expect(syncInstance).toHaveProperty('map');
    expect(typeof syncInstance.destroy).toBe('function');
  });
  
  test('should destroy card sync instance', async () => {
    const cardId = 'test-card-id';
    const syncInstance = await syncService.createCardSync(cardId);
    
    // 模拟destroy方法
    const mockDestroy = jest.fn();
    syncInstance.destroy = mockDestroy;
    
    syncService.destroyCardSync(cardId);
    expect(mockDestroy).toHaveBeenCalled();
  });
  
  test('should get peers list', () => {
    const peers = syncService.getPeers();
    expect(Array.isArray(peers)).toBe(true);
  });
  
  test('should trigger sync manually', async () => {
    const result = await syncService.triggerSync();
    expect(result).toBeUndefined(); // 验证函数执行完成
  });
  
  test('should listen to sync status changes', () => {
    const callback = jest.fn();
    const unsubscribe = syncService.onSyncStatusChange(callback);
    
    expect(typeof unsubscribe).toBe('function');
    unsubscribe(); // 清理订阅
  });
});
```

## 2. 状态管理Store API

### 2.1 authStore

#### 接口定义
```typescript
/**
 * 认证状态管理
 */
const authStore = create<AuthState>((set, get) => ({
  isAuthenticated: false,
  currentNetworkId: null,
  
  // Actions
  joinNetwork: async (networkId: string) => {
    // 实现网络加入逻辑
  },
  
  leaveNetwork: () => {
    // 实现离开网络逻辑
  },
  
  generateNewNetwork: async () => {
    // 实现生成新网络逻辑
  },
  
  validateNetworkId: (networkId: string) => {
    // 实现网络ID验证逻辑
  },
  
  reset: () => {
    // 实现重置状态逻辑
  }
}));

interface AuthState {
  isAuthenticated: boolean;
  currentNetworkId: string | null;
  joinNetwork: (networkId: string) => Promise<void>;
  leaveNetwork: () => void;
  generateNewNetwork: () => Promise<string>;
  validateNetworkId: (networkId: string) => boolean;
  reset: () => void;
}
```

#### 单元测试
```typescript
// authStore.test.ts
import { authStore } from '@/stores/authStore';

describe('authStore', () => {
  beforeEach(() => {
    // 重置store状态
    authStore.getState().reset();
  });
  
  test('initial state should be unauthenticated', () => {
    const state = authStore.getState();
    expect(state.isAuthenticated).toBe(false);
    expect(state.currentNetworkId).toBeNull();
  });
  
  test('should join network successfully', async () => {
    const networkId = 'test-network-id';
    await authStore.getState().joinNetwork(networkId);
    
    const state = authStore.getState();
    expect(state.isAuthenticated).toBe(true);
    expect(state.currentNetworkId).toBe(networkId);
  });
  
  test('should leave network', () => {
    // 先加入网络
    const networkId = 'test-network-id';
    authStore.getState().joinNetwork(networkId);
    
    // 然后离开网络
    authStore.getState().leaveNetwork();
    
    const state = authStore.getState();
    expect(state.isAuthenticated).toBe(false);
    expect(state.currentNetworkId).toBeNull();
  });
  
  test('should generate new network', async () => {
    const networkId = await authStore.getState().generateNewNetwork();
    
    expect(networkId).toBeTruthy();
    
    const state = authStore.getState();
    expect(state.isAuthenticated).toBe(true);
    expect(state.currentNetworkId).toBe(networkId);
  });
  
  test('should validate network id format', () => {
    const validId = '123e4567-e89b-12d3-a456-426614174000';
    const invalidId = 'invalid-id';
    
    expect(authStore.getState().validateNetworkId(validId)).toBe(true);
    expect(authStore.getState().validateNetworkId(invalidId)).toBe(false);
  });
});
```

### 2.2 deviceStore

#### 接口定义
```typescript
/**
 * 设备管理状态
 */
const deviceStore = create<DeviceState>((set, get) => ({
  deviceId: '',
  nickname: '',
  deviceType: '',
  lastSeen: Date.now(),
  onlineDevices: [],
  
  // Actions
  initializeDevice: () => {
    // 实现设备初始化逻辑
  },
  
  updateNickname: (nickname: string) => {
    // 实现昵称更新逻辑
  },
  
  updateLastSeen: () => {
    // 实现最后在线时间更新逻辑
  },
  
  updateOnlineDevices: (devices: DeviceInfo[]) => {
    // 实现在线设备列表更新逻辑
  },
  
  getDeviceInfo: () => {
    // 实现获取设备信息逻辑
  }
}));

interface DeviceState {
  deviceId: string;
  nickname: string;
  deviceType: string;
  lastSeen: number;
  onlineDevices: DeviceInfo[];
  initializeDevice: () => void;
  updateNickname: (nickname: string) => void;
  updateLastSeen: () => void;
  updateOnlineDevices: (devices: DeviceInfo[]) => void;
  getDeviceInfo: () => DeviceInfo;
}
```

#### 单元测试
```typescript
// deviceStore.test.ts
import { deviceStore } from '@/stores/deviceStore';

describe('deviceStore', () => {
  beforeEach(() => {
    // 重置存储的设备信息
    localStorage.removeItem('deviceId');
    localStorage.removeItem('deviceNickname');
    
    // 初始化设备
    deviceStore.getState().initializeDevice();
  });
  
  test('should initialize device with proper values', () => {
    const state = deviceStore.getState();
    
    expect(state.deviceId).toBeTruthy();
    expect(state.nickname).toBeTruthy();
    expect(state.deviceType).toBeTruthy();
    expect(state.lastSeen).toBeLessThanOrEqual(Date.now());
  });
  
  test('should update nickname', () => {
    const newNickname = '测试设备昵称';
    deviceStore.getState().updateNickname(newNickname);
    
    const state = deviceStore.getState();
    expect(state.nickname).toBe(newNickname);
  });
  
  test('should update last seen time', () => {
    const oldLastSeen = deviceStore.getState().lastSeen;
    // 等待10ms确保时间变化
    setTimeout(() => {
      deviceStore.getState().updateLastSeen();
      const newLastSeen = deviceStore.getState().lastSeen;
      expect(newLastSeen).toBeGreaterThan(oldLastSeen);
    }, 10);
  });
  
  test('should update online devices list', () => {
    const mockDevices = [
      { id: 'device1', nickname: '设备1', deviceType: 'desktop', createdAt: Date.now(), lastSeen: Date.now() },
      { id: 'device2', nickname: '设备2', deviceType: 'mobile', createdAt: Date.now(), lastSeen: Date.now() }
    ];
    
    deviceStore.getState().updateOnlineDevices(mockDevices);
    
    const state = deviceStore.getState();
    expect(state.onlineDevices).toHaveLength(2);
    expect(state.onlineDevices[0].id).toBe('device1');
  });
  
  test('should get device info', () => {
    const deviceInfo = deviceStore.getState().getDeviceInfo();
    
    expect(deviceInfo).toHaveProperty('id');
    expect(deviceInfo).toHaveProperty('nickname');
    expect(deviceInfo).toHaveProperty('deviceType');
    expect(deviceInfo).toHaveProperty('createdAt');
    expect(deviceInfo).toHaveProperty('lastSeen');
  });
});
```

### 2.3 cardStore

#### 接口定义
```typescript
/**
 * 卡片状态管理
 */
const cardStore = create<CardState>((set, get) => ({
  cards: [],
  deletedCards: [],
  isLoading: false,
  error: null,
  
  // Actions
  fetchAllCards: async () => {
    // 实现获取所有卡片逻辑
  },
  
  fetchDeletedCards: async () => {
    // 实现获取已删除卡片逻辑
  },
  
  createCard: async (cardData: Partial<Card>) => {
    // 实现创建卡片逻辑
  },
  
  updateCard: async (cardId: string, updates: Partial<Card>) => {
    // 实现更新卡片逻辑
  },
  
  deleteCard: async (cardId: string) => {
    // 实现删除卡片逻辑
  },
  
  restoreCard: async (cardId: string) => {
    // 实现恢复卡片逻辑
  },
  
  clearError: () => {
    // 实现清除错误逻辑
  }
}));

interface CardState {
  cards: Card[];
  deletedCards: Card[];
  isLoading: boolean;
  error: string | null;
  fetchAllCards: () => Promise<void>;
  fetchDeletedCards: () => Promise<void>;
  createCard: (cardData: Partial<Card>) => Promise<void>;
  updateCard: (cardId: string, updates: Partial<Card>) => Promise<void>;
  deleteCard: (cardId: string) => Promise<void>;
  restoreCard: (cardId: string) => Promise<void>;
  clearError: () => void;
}
```

#### 单元测试
```typescript
// cardStore.test.ts
import { cardStore } from '@/stores/cardStore';
import { CardService } from '@/services/CardService';

// Mock CardService
jest.mock('@/services/CardService', () => ({
  CardService: jest.fn().mockImplementation(() => ({
    getAllCards: jest.fn().mockResolvedValue([{ id: '1', title: '测试', content: '内容', deleted: false }]),
    getDeletedCards: jest.fn().mockResolvedValue([]),
    createCard: jest.fn().mockResolvedValue({ id: 'new', title: '新卡片', content: '新内容', deleted: false }),
    updateCard: jest.fn().mockResolvedValue({ id: '1', title: '更新后', content: '更新内容', deleted: false }),
    deleteCard: jest.fn().mockResolvedValue(true),
    restoreCard: jest.fn().mockResolvedValue({ id: '1', title: '恢复的卡片', content: '内容', deleted: false }),
  }))
}));

describe('cardStore', () => {
  beforeEach(() => {
    // 重置store状态
    cardStore.setState({
      cards: [],
      deletedCards: [],
      isLoading: false,
      error: null
    });
  });
  
  test('initial state should be empty', () => {
    const state = cardStore.getState();
    expect(state.cards).toEqual([]);
    expect(state.deletedCards).toEqual([]);
    expect(state.isLoading).toBe(false);
    expect(state.error).toBeNull();
  });
  
  test('should fetch all cards', async () => {
    await cardStore.getState().fetchAllCards();
    
    const state = cardStore.getState();
    expect(state.cards).toHaveLength(1);
    expect(state.isLoading).toBe(false);
  });
  
  test('should create new card', async () => {
    await cardStore.getState().createCard({ title: '新卡片', content: '新内容' });
    
    const state = cardStore.getState();
    expect(state.cards).toHaveLength(1);
    expect(state.cards[0].title).toBe('新卡片');
  });
  
  test('should update card', async () => {
    // 先创建卡片
    await cardStore.getState().createCard({ title: '原标题', content: '原内容' });
    
    // 然后更新卡片
    const cardId = cardStore.getState().cards[0].id;
    await cardStore.getState().updateCard(cardId, { title: '更新后', content: '更新内容' });
    
    const state = cardStore.getState();
    expect(state.cards[0].title).toBe('更新后');
  });
  
  test('should delete card', async () => {
    // 先创建卡片
    await cardStore.getState().createCard({ title: '要删除的卡片', content: '内容' });
    
    // 然后删除卡片
    const cardId = cardStore.getState().cards[0].id;
    await cardStore.getState().deleteCard(cardId);
    
    // 验证卡片已从active列表移除
    const state = cardStore.getState();
    expect(state.cards).toHaveLength(0);
  });
  
  test('should clear error', () => {
    // 设置错误状态
    cardStore.setState({ error: '测试错误' });
    
    // 清除错误
    cardStore.getState().clearError();
    
    const state = cardStore.getState();
    expect(state.error).toBeNull();
  });
});
```

### 2.4 syncStore

#### 接口定义
```typescript
/**
 * 同步状态管理
 */
const syncStore = create<SyncState>((set, get) => ({
  isConnected: false,
  isSyncing: false,
  peers: [],
  lastSyncTime: null,
  syncErrors: [],
  
  // Actions
  initializeSync: async (networkId: string) => {
    // 实现同步初始化逻辑
  },
  
  updateConnectionStatus: (connected: boolean) => {
    // 实现连接状态更新逻辑
  },
  
  updateSyncStatus: (syncing: boolean) => {
    // 实现同步状态更新逻辑
  },
  
  updatePeers: (peers: PeerInfo[]) => {
    // 实现对等节点更新逻辑
  },
  
  recordSyncTime: () => {
    // 实现记录同步时间逻辑
  },
  
  addSyncError: (error: string) => {
    // 实现添加同步错误逻辑
  },
  
  clearSyncErrors: () => {
    // 实现清除同步错误逻辑
  },
  
  disconnect: () => {
    // 实现断开连接逻辑
  }
}));

interface SyncState {
  isConnected: boolean;
  isSyncing: boolean;
  peers: PeerInfo[];
  lastSyncTime: number | null;
  syncErrors: string[];
  initializeSync: (networkId: string) => Promise<void>;
  updateConnectionStatus: (connected: boolean) => void;
  updateSyncStatus: (syncing: boolean) => void;
  updatePeers: (peers: PeerInfo[]) => void;
  recordSyncTime: () => void;
  addSyncError: (error: string) => void;
  clearSyncErrors: () => void;
  disconnect: () => void;
}
```

#### 单元测试
```typescript
// syncStore.test.ts
import { syncStore } from '@/stores/syncStore';

describe('syncStore', () => {
  beforeEach(() => {
    // 重置store状态
    syncStore.setState({
      isConnected: false,
      isSyncing: false,
      peers: [],
      lastSyncTime: null,
      syncErrors: []
    });
  });
  
  test('initial state should be disconnected', () => {
    const state = syncStore.getState();
    expect(state.isConnected).toBe(false);
    expect(state.isSyncing).toBe(false);
    expect(state.peers).toEqual([]);
    expect(state.lastSyncTime).toBeNull();
    expect(state.syncErrors).toEqual([]);
  });
  
  test('should update connection status', () => {
    syncStore.getState().updateConnectionStatus(true);
    
    const state = syncStore.getState();
    expect(state.isConnected).toBe(true);
  });
  
  test('should update sync status', () => {
    syncStore.getState().updateSyncStatus(true);
    
    const state = syncStore.getState();
    expect(state.isSyncing).toBe(true);
  });
  
  test('should update peers list', () => {
    const mockPeers = [
      { id: 'peer1', nickname: '设备1', connected: true },
      { id: 'peer2', nickname: '设备2', connected: true }
    ];
    
    syncStore.getState().updatePeers(mockPeers);
    
    const state = syncStore.getState();
    expect(state.peers).toHaveLength(2);
    expect(state.peers[0].id).toBe('peer1');
  });
  
  test('should record sync time', () => {
    syncStore.getState().recordSyncTime();
    
    const state = syncStore.getState();
    expect(state.lastSyncTime).toBeTruthy();
    expect(state.lastSyncTime).toBeLessThanOrEqual(Date.now());
  });
  
  test('should add and clear sync errors', () => {
    // 添加错误
    syncStore.getState().addSyncError('同步错误1');
    syncStore.getState().addSyncError('同步错误2');
    
    let state = syncStore.getState();
    expect(state.syncErrors).toHaveLength(2);
    
    // 清除错误
    syncStore.getState().clearSyncErrors();
    
    state = syncStore.getState();
    expect(state.syncErrors).toEqual([]);
  });
  
  test('should disconnect and reset state', () => {
    // 先设置连接状态
    syncStore.getState().updateConnectionStatus(true);
    syncStore.getState().updateSyncStatus(true);
    
    // 断开连接
    syncStore.getState().disconnect();
    
    const state = syncStore.getState();
    expect(state.isConnected).toBe(false);
    expect(state.isSyncing).toBe(false);
  });
});
```

## 3. 系统测试计划

### 3.1 数据存储测试

#### 测试目标
验证IndexedDB数据存储的正确性、完整性和一致性。

#### 测试场景
1. **卡片CRUD操作测试**
   - 创建卡片并验证存储
   - 更新卡片并验证变更
   - 软删除卡片并验证状态变更
   - 恢复已删除卡片并验证状态变更
   - 获取所有卡片列表

2. **数据持久化测试**
   - 页面刷新后数据是否保留
   - 浏览器重启后数据是否恢复
   - 存储空间限制测试（大量数据）

3. **并发操作测试**
   - 多标签页同时读写操作
   - 快速连续操作响应性

#### 测试脚本示例
```typescript
// system-test/card-storage.test.ts
import { CardService } from '@/services/CardService';
import { openNewTab, closeTab, restartBrowser } from '@/utils/browserUtils';

describe('Card Storage System Tests', () => {
  let cardService: CardService;
  
  beforeEach(async () => {
    cardService = new CardService();
    // 清空测试数据
    await cardService.clearTestData();
  });
  
  test('should persist data across page reloads', async () => {
    // 创建卡片
    const card = await cardService.createCard({ title: '持久化测试', content: '测试内容' });
    
    // 模拟页面刷新
    window.location.reload();
    
    // 重新获取卡片
    const persistedCard = await cardService.getCard(card.id);
    
    expect(persistedCard).not.toBeNull();
    expect(persistedCard?.title).toBe('持久化测试');
  });
  
  test('should handle soft delete and restore correctly', async () => {
    // 创建卡片
    const card = await cardService.createCard({ title: '删除测试', content: '内容' });
    
    // 删除卡片
    await cardService.deleteCard(card.id);
    
    // 验证卡片不在活动列表中
    const activeCards = await cardService.getAllCards();
    expect(activeCards.find(c => c.id === card.id)).toBeUndefined();
    
    // 验证卡片在删除列表中
    const deletedCards = await cardService.getDeletedCards();
    expect(deletedCards.find(c => c.id === card.id)).not.toBeUndefined();
    
    // 恢复卡片
    await cardService.restoreCard(card.id);
    
    // 验证卡片恢复到活动列表
    const restoredActiveCards = await cardService.getAllCards();
    expect(restoredActiveCards.find(c => c.id === card.id)).not.toBeUndefined();
  });
  
  test('should handle concurrent operations from multiple tabs', async () => {
    // 创建卡片
    const card = await cardService.createCard({ title: '并发测试', content: '初始内容' });
    
    // 打开新标签
    const newTab = await openNewTab(window.location.href);
    
    // 在新标签中更新卡片
    await newTab.evaluate(async (cardId) => {
      const cardService = new CardService();
      await cardService.updateCard(cardId, { content: '更新后的内容' });
    }, card.id);
    
    // 关闭新标签
    await closeTab(newTab);
    
    // 在原标签中检查更新
    const updatedCard = await cardService.getCard(card.id);
    expect(updatedCard?.content).toBe('更新后的内容');
  });
});
```

### 3.2 同步功能测试

#### 测试目标
验证多设备间的实时数据同步功能的正确性和可靠性。

#### 测试场景
1. **基础同步测试**
   - 两设备加入同一网络
   - 创建卡片并验证同步
   - 更新卡片并验证同步
   - 删除卡片并验证同步

2. **网络异常测试**
   - 模拟网络断开重连
   - 网络恢复后的同步延迟
   - 离线操作后的批量同步

3. **冲突解决测试**
   - 多设备同时编辑同一卡片
   - Yjs自动冲突解决机制验证
   - 验证最终一致性

#### 测试脚本示例
```typescript
// system-test/sync.test.ts
import { AuthService } from '@/services/AuthService';
import { CardService } from '@/services/CardService';
import { SyncService } from '@/services/SyncService';
import { simulateDevice, disconnectNetwork, reconnectNetwork } from '@/utils/testUtils';

describe('Sync System Tests', () => {
  let authService: AuthService;
  let deviceService: DeviceService;
  let networkId: string;
  
  beforeEach(async () => {
    authService = new AuthService();
    deviceService = new DeviceService();
    networkId = authService.generateNetworkId();
  });
  
  test('should sync card creation between devices', async () => {
    // 创建设备1
    const device1 = await simulateDevice('device1');
    await device1.authService.joinNetwork(networkId);
    
    // 创建设备2
    const device2 = await simulateDevice('device2');
    await device2.authService.joinNetwork(networkId);
    
    // 等待设备连接建立
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 在设备1上创建卡片
    const card = await device1.cardService.createCard({
      title: '同步测试卡片',
      content: '这是一个同步测试'
    });
    
    // 等待同步完成
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // 在设备2上检查同步结果
    const syncedCard = await device2.cardService.getCard(card.id);
    
    expect(syncedCard).not.toBeNull();
    expect(syncedCard?.title).toBe('同步测试卡片');
    expect(syncedCard?.content).toBe('这是一个同步测试');
  });
  
  test('should handle offline operations and sync on reconnection', async () => {
    // 创建设备1和设备2
    const device1 = await simulateDevice('device1');
    const device2 = await simulateDevice('device2');
    
    // 加入同一网络
    await device1.authService.joinNetwork(networkId);
    await device2.authService.joinNetwork(networkId);
    
    // 等待连接建立
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 断开设备2的网络连接
    await disconnectNetwork(device2);
    
    // 在设备1上创建卡片
    await device1.cardService.createCard({
      title: '离线测试卡片',
      content: '在线设备创建'
    });
    
    // 在设备2上进行离线操作
    const offlineCard = await device2.cardService.createCard({
      title: '离线创建的卡片',
      content: '这是离线创建的'
    });
    
    // 重新连接设备2
    await reconnectNetwork(device2);
    
    // 等待同步完成
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 验证设备1上是否收到设备2离线创建的卡片
    const syncedToDevice1 = await device1.cardService.getCard(offlineCard.id);
    expect(syncedToDevice1).not.toBeNull();
    
    // 验证设备2上是否收到设备1创建的卡片
    const cardsOnDevice2 = await device2.cardService.getAllCards();
    expect(cardsOnDevice2.length).toBeGreaterThan(1); // 至少有两个卡片
  });
  
  test('should resolve conflicts automatically with Yjs', async () => {
    // 创建设备1和设备2
    const device1 = await simulateDevice('device1');
    const device2 = await simulateDevice('device2');
    
    // 加入同一网络
    await device1.authService.joinNetwork(networkId);
    await device2.authService.joinNetwork(networkId);
    
    // 等待连接建立
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 创建初始卡片
    const initialCard = await device1.cardService.createCard({
      title: '冲突测试卡片',
      content: '初始内容'
    });
    
    // 等待同步完成
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // 模拟网络延迟，让两个设备可以同时修改
    await disconnectNetwork(device1);
    await disconnectNetwork(device2);
    
    // 设备1修改卡片
    await device1.cardService.updateCard(initialCard.id, {
      content: '设备1的修改'
    });
    
    // 设备2修改同一卡片
    await device2.cardService.updateCard(initialCard.id, {
      content: '设备2的修改'
    });
    
    // 重新连接两个设备
    await reconnectNetwork(device1);
    await reconnectNetwork(device2);
    
    // 等待冲突解决和同步完成
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 验证两个设备的数据最终一致
    const card1 = await device1.cardService.getCard(initialCard.id);
    const card2 = await device2.cardService.getCard(initialCard.id);
    
    expect(card1?.content).toBe(card2?.content); // 两个设备的内容应该一致
  });
});
```

### 3.3 用户界面测试

#### 测试目标
验证用户界面组件的功能正确性、响应性和用户体验。

#### 测试场景
1. **网络认证流程测试**
   - 生成新网络
   - 输入现有网络ID加入
   - 网络ID格式验证

2. **卡片管理界面测试**
   - 卡片列表展示
   - 创建新卡片
   - 编辑现有卡片
   - 删除和恢复卡片
   - 卡片排序和过滤

3. **协作体验测试**
   - 显示在线设备
   - 实时编辑反馈
   - 同步状态指示
   - 离线模式UI反馈

#### 测试脚本示例
```typescript
// system-test/ui.test.ts
import { test, expect } from '@playwright/test';

test.describe('CardMind UI Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });
  
  test('should create new network and redirect to card list', async ({ page }) => {
    // 点击创建新网络按钮
    await page.click('text=创建新网络');
    
    // 验证是否重定向到卡片列表
    await expect(page.locator('.card-list')).toBeVisible();
    
    // 验证网络设置中是否有网络ID
    await page.click('text=设置');
    await expect(page.locator('.network-id')).toBeVisible();
  });
  
  test('should join existing network with valid ID', async ({ page }) => {
    // 输入有效的网络ID
    const testNetworkId = '123e4567-e89b-12d3-a456-426614174000';
    await page.fill('#networkIdInput', testNetworkId);
    
    // 点击加入网络按钮
    await page.click('text=加入网络');
    
    // 验证是否成功加入
    await expect(page.locator('.success-message')).toBeVisible();
    await expect(page.locator('.card-list')).toBeVisible();
  });
  
  test('should show error for invalid network ID format', async ({ page }) => {
    // 输入无效的网络ID
    await page.fill('#networkIdInput', 'invalid-id');
    
    // 点击加入网络按钮
    await page.click('text=加入网络');
    
    // 验证错误提示
    await expect(page.locator('.error-message')).toBeVisible();
    await expect(page.locator('.error-message')).toContainText('无效的网络ID格式');
  });
  
  test('should create, edit and delete a card', async ({ page }) => {
    // 首先创建一个网络
    await page.click('text=创建新网络');
    await expect(page.locator('.card-list')).toBeVisible();
    
    // 创建新卡片
    await page.click('text=新建卡片');
    await page.fill('#cardTitle', 'UI测试卡片');
    await page.fill('#cardContent', '测试卡片内容');
    await page.click('text=保存');
    
    // 验证卡片创建成功
    await expect(page.locator('.card-item')).toBeVisible();
    await expect(page.locator('.card-item')).toContainText('UI测试卡片');
    
    // 编辑卡片
    await page.click('.card-item >> text=编辑');
    await page.fill('#cardTitle', '更新后的标题');
    await page.click('text=保存');
    
    // 验证编辑成功
    await expect(page.locator('.card-item')).toContainText('更新后的标题');
    
    // 删除卡片
    await page.click('.card-item >> text=删除');
    await page.click('text=确认删除');
    
    // 验证卡片已从列表移除
    await expect(page.locator('.card-item')).not.toBeVisible();
    await expect(page.locator('.empty-state')).toBeVisible();
  });
});
```

## 4. 回归测试计划

### 4.1 回归测试策略

#### 自动化回归测试
- 每次代码提交自动运行单元测试套件
- 每次PR合并前运行集成测试
- 每日构建时运行完整系统测试

#### 手动回归测试
- 重点功能模块的交互测试
- 跨浏览器兼容性测试
- 移动设备响应式测试

#### 回归测试范围
- 核心数据操作功能
- 多设备同步功能
- 用户认证流程
- 数据安全与加密功能
- 离线模式功能

### 4.2 测试环境与配置

#### 测试环境
- 开发环境：本地开发机器
- 测试环境：模拟生产环境的测试服务器
- 浏览器环境：Chrome、Firefox、Safari、Edge最新版本
- 移动设备：iOS和Android主流设备

#### 测试数据
- 标准测试数据集（预定义卡片集合）
- 性能测试大数据集（1000+卡片）
- 边缘情况测试数据（空数据、特殊字符、大文本等）

### 4.3 回归测试执行计划

| 测试类型 | 执行频率 | 负责团队 | 自动化程度 | 验证内容 |
|---------|---------|---------|-----------|--------|
| 单元测试 | 每次提交 | 开发 | 100% | API功能正确性 |
| 集成测试 | 每次PR | CI/CD | 90% | 模块间交互 |
| 系统测试 | 每日构建 | CI/CD | 80% | 端到端功能 |
| UI回归测试 | 每周 | 测试 | 50% | 用户界面功能 |
| 性能测试 | 版本发布前 | 测试 | 70% | 系统响应性能 |
| 安全测试 | 版本发布前 | 安全 | 60% | 数据安全与加密 |

### 4.4 测试用例管理

- 使用Jest进行单元测试管理
- 使用Playwright进行UI自动化测试
- 使用GitHub Actions进行持续集成测试
- 测试结果报告自动生成并发送

### 4.5 缺陷管理流程

1. **缺陷发现**：通过测试或用户反馈发现缺陷
2. **缺陷记录**：在项目管理工具中记录缺陷详情
3. **缺陷分类**：按严重程度和优先级分类
4. **修复验证**：开发修复后进行回归测试验证
5. **关闭缺陷**：验证通过后关闭缺陷

## 5. 测试工具与技术

### 5.1 推荐工具

- **Jest**：JavaScript测试框架，用于单元测试和集成测试
- **Testing Library**：React组件测试工具
- **Playwright**：端到端测试工具，支持多种浏览器
- **Dexie.js Mock**：IndexedDB测试模拟库
- **Yjs测试工具**：Yjs同步测试工具
- **GitHub Actions**：持续集成与测试自动化

### 5.2 测试覆盖率要求

- 单元测试覆盖率：>80%
- 关键业务逻辑覆盖率：>90%
- 核心API覆盖率：100%
- 测试报告：每次构建自动生成覆盖率报告

### 5.3 测试最佳实践

- **隔离测试**：每个测试独立运行，不依赖外部状态
- **模拟依赖**：使用mock替代外部依赖
- **测试数据管理**：每个测试前准备干净的测试数据
- **断言明确**：使用清晰的断言描述预期行为
- **测试命名规范**：使用描述性的测试名称
- **持续测试**：开发过程中持续运行测试
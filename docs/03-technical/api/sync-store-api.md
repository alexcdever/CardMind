# syncStore API 文档

## 1. 接口定义

```typescript
import { create } from 'zustand';
import { SyncService, SyncStatus, SyncEvent, SyncEventType } from '../services/sync-service';
import { AuthStore } from './auth-store';

// 同步存储状态接口
export interface SyncStoreState {
  // 同步状态
  syncStatus: SyncStatus;
  // 最后同步时间
  lastSyncedAt: Date | null;
  // 同步错误信息
  syncError: string | null;
  // 是否正在强制同步
  isForceSyncing: boolean;
  // 同步冲突记录
  conflicts: SyncConflict[];
  // 等待同步的变更队列
  pendingChanges: SyncChange[];
  // 同步服务实例
  syncService: SyncService | null;
  // 自动同步间隔（毫秒）
  autoSyncInterval: number;
  // 自动同步定时器ID
  autoSyncTimer: NodeJS.Timeout | null;
  // 设备连接状态
  deviceConnectionStatus: 'connected' | 'disconnected' | 'connecting';
  // 已连接设备列表
  connectedDevices: DeviceInfo[];
  // 初始化同步服务
  initializeSync: () => Promise<boolean>;
  // 触发同步
  triggerSync: () => Promise<boolean>;
  // 触发强制同步
  triggerForceSync: () => Promise<boolean>;
  // 暂停自动同步
  pauseAutoSync: () => void;
  // 恢复自动同步
  resumeAutoSync: () => void;
  // 处理同步冲突
  handleSyncConflict: (conflict: SyncConflict, resolution: 'local_wins' | 'remote_wins' | 'merge') => Promise<void>;
  // 清除同步错误
  clearSyncError: () => void;
  // 重新连接同步服务
  reconnect: () => Promise<void>;
  // 设置同步间隔
  setAutoSyncInterval: (interval: number) => void;
  // 断开同步连接
  disconnect: () => Promise<void>;
  // 获取同步状态
  getSyncStatus: () => SyncStatus;
  // 检查是否有未解决的冲突
  hasUnresolvedConflicts: () => boolean;
  // 获取冲突计数
  getConflictCount: () => number;
}

// 同步冲突接口
export interface SyncConflict {
  // 冲突ID
  id: string;
  // 冲突类型
  type: 'card' | 'deck' | 'user_preference';
  // 冲突资源ID
  resourceId: string;
  // 本地版本
  localVersion: any;
  // 远程版本
  remoteVersion: any;
  // 冲突创建时间
  createdAt: Date;
  // 冲突解决状态
  resolved: boolean;
  // 解决方式
  resolution?: 'local_wins' | 'remote_wins' | 'merge';
  // 解决时间
  resolvedAt?: Date;
}

// 同步变更接口
export interface SyncChange {
  // 变更ID
  id: string;
  // 变更类型
  type: 'create' | 'update' | 'delete';
  // 资源类型
  resourceType: 'card' | 'deck' | 'user_preference';
  // 资源ID
  resourceId: string;
  // 变更内容
  content: any;
  // 变更时间戳
  timestamp: Date;
  // 变更作者（设备ID）
  author: string;
}

// 设备信息接口
export interface DeviceInfo {
  // 设备ID
  deviceId: string;
  // 设备名称
  deviceName: string;
  // 设备类型
  deviceType: 'mobile' | 'desktop' | 'tablet';
  // 设备平台
  platform: 'ios' | 'android' | 'windows' | 'macos' | 'web';
  // 应用版本
  appVersion: string;
  // 连接时间
  connectedAt: Date;
  // 最后活动时间
  lastActiveAt: Date;
  // 设备状态
  status: 'online' | 'idle' | 'offline';
}

// 创建同步存储的工厂函数
export const createSyncStore = (authStore: AuthStore) => {
  return create<SyncStoreState>((set, get) => ({
    // 初始状态
    syncStatus: SyncStatus.IDLE,
    lastSyncedAt: null,
    syncError: null,
    isForceSyncing: false,
    conflicts: [],
    pendingChanges: [],
    syncService: null,
    autoSyncInterval: 30000, // 默认30秒
    autoSyncTimer: null,
    deviceConnectionStatus: 'disconnected',
    connectedDevices: [],

    // 初始化同步服务
    initializeSync: async () => {
      try {
        // 获取认证信息
        const authState = authStore.getState();
        const { user, currentNetwork } = authState;

        if (!user || !currentNetwork) {
          set({ syncError: '用户未登录或未加入网络', syncStatus: SyncStatus.ERROR });
          return false;
        }

        // 更新状态为连接中
        set({ deviceConnectionStatus: 'connecting' });

        // 创建同步服务实例
        const syncService = new SyncService({
          userId: user.id,
          networkId: currentNetwork.id,
          authToken: authState.authToken,
          deviceId: authState.deviceId
        });

        // 注册事件监听器
        syncService.on('syncStatusChanged', (status) => {
          set({ syncStatus: status });
        });

        syncService.on('syncCompleted', () => {
          set({ 
            syncStatus: SyncStatus.IDLE, 
            lastSyncedAt: new Date(),
            syncError: null,
            isForceSyncing: false
          });
        });

        syncService.on('syncError', (error) => {
          set({ syncError: error, syncStatus: SyncStatus.ERROR });
        });

        syncService.on('conflictDetected', (conflict) => {
          set((state) => ({
            conflicts: [...state.conflicts, conflict],
            syncStatus: SyncStatus.CONFLICT
          }));
        });

        syncService.on('deviceConnected', (deviceInfo) => {
          set((state) => ({
            connectedDevices: [...state.connectedDevices, deviceInfo],
            deviceConnectionStatus: 'connected'
          }));
        });

        syncService.on('deviceDisconnected', (deviceId) => {
          set((state) => ({
            connectedDevices: state.connectedDevices.filter(d => d.deviceId !== deviceId)
          }));
        });

        syncService.on('deviceConnectionStatusChanged', (status) => {
          set({ deviceConnectionStatus: status });
        });

        // 连接同步服务
        const connected = await syncService.connect();

        if (connected) {
          set({ 
            syncService, 
            syncStatus: SyncStatus.IDLE,
            deviceConnectionStatus: 'connected'
          });

          // 启动自动同步
          get().resumeAutoSync();
          return true;
        } else {
          set({ 
            syncError: '无法连接到同步服务', 
            syncStatus: SyncStatus.ERROR,
            deviceConnectionStatus: 'disconnected'
          });
          return false;
        }
      } catch (error) {
        set({ 
          syncError: error instanceof Error ? error.message : '初始化同步失败', 
          syncStatus: SyncStatus.ERROR,
          deviceConnectionStatus: 'disconnected'
        });
        return false;
      }
    },

    // 触发同步
    triggerSync: async () => {
      try {
        const { syncService, syncStatus, isForceSyncing } = get();

        // 检查服务是否可用
        if (!syncService) {
          set({ syncError: '同步服务未初始化' });
          return false;
        }

        // 检查是否正在同步
        if (syncStatus === SyncStatus.SYNCING || isForceSyncing) {
          return false;
        }

        // 更新状态
        set({ syncStatus: SyncStatus.SYNCING, syncError: null });

        // 执行同步
        const success = await syncService.sync();

        if (success) {
          set({ 
            syncStatus: SyncStatus.IDLE, 
            lastSyncedAt: new Date()
          });
          return true;
        } else {
          set({ 
            syncStatus: SyncStatus.ERROR, 
            syncError: '同步失败'
          });
          return false;
        }
      } catch (error) {
        set({ 
          syncStatus: SyncStatus.ERROR, 
          syncError: error instanceof Error ? error.message : '同步过程中发生错误'
        });
        return false;
      }
    },

    // 触发强制同步
    triggerForceSync: async () => {
      try {
        const { syncService } = get();

        // 检查服务是否可用
        if (!syncService) {
          set({ syncError: '同步服务未初始化' });
          return false;
        }

        // 更新状态
        set({ 
          syncStatus: SyncStatus.SYNCING, 
          isForceSyncing: true, 
          syncError: null 
        });

        // 执行强制同步
        const success = await syncService.forceSync();

        if (success) {
          set({ 
            syncStatus: SyncStatus.IDLE, 
            lastSyncedAt: new Date(),
            isForceSyncing: false
          });
          return true;
        } else {
          set({ 
            syncStatus: SyncStatus.ERROR, 
            syncError: '强制同步失败',
            isForceSyncing: false
          });
          return false;
        }
      } catch (error) {
        set({ 
          syncStatus: SyncStatus.ERROR, 
          syncError: error instanceof Error ? error.message : '强制同步过程中发生错误',
          isForceSyncing: false
        });
        return false;
      }
    },

    // 暂停自动同步
    pauseAutoSync: () => {
      try {
        const { autoSyncTimer } = get();

        if (autoSyncTimer) {
          clearInterval(autoSyncTimer);
          set({ autoSyncTimer: null, syncStatus: SyncStatus.PAUSED });
        }

        const { syncService } = get();
        if (syncService) {
          syncService.pauseAutoSync();
        }
      } catch (error) {
        set({ 
          syncError: error instanceof Error ? error.message : '暂停自动同步失败',
          syncStatus: SyncStatus.ERROR
        });
      }
    },

    // 恢复自动同步
    resumeAutoSync: () => {
      try {
        const { autoSyncInterval, triggerSync } = get();

        // 清除现有定时器
        const { autoSyncTimer } = get();
        if (autoSyncTimer) {
          clearInterval(autoSyncTimer);
        }

        // 创建新定时器
        const timer = setInterval(() => {
          triggerSync();
        }, autoSyncInterval);

        set({ autoSyncTimer: timer, syncStatus: SyncStatus.IDLE });

        const { syncService } = get();
        if (syncService) {
          syncService.resumeAutoSync();
        }
      } catch (error) {
        set({ 
          syncError: error instanceof Error ? error.message : '恢复自动同步失败',
          syncStatus: SyncStatus.ERROR
        });
      }
    },

    // 处理同步冲突
    handleSyncConflict: async (conflict, resolution) => {
      try {
        const { syncService } = get();

        if (!syncService) {
          throw new Error('同步服务未初始化');
        }

        // 解决冲突
        await syncService.resolveConflict(conflict, resolution);

        // 更新状态
        set((state) => ({
          conflicts: state.conflicts.map(c => 
            c.id === conflict.id ? { ...c, resolved: true, resolution } : c
          ),
          syncStatus: state.conflicts.length === 1 ? SyncStatus.IDLE : state.syncStatus
        }));
      } catch (error) {
        set({ 
          syncError: error instanceof Error ? error.message : '处理同步冲突失败'
        });
      }
    },

    // 清除同步错误
    clearSyncError: () => {
      set({ syncError: null });
    },

    // 重新连接同步服务
    reconnect: async () => {
      try {
        const { syncService } = get();

        if (!syncService) {
          throw new Error('同步服务未初始化');
        }

        // 更新状态
        set({ 
          deviceConnectionStatus: 'connecting',
          syncError: null 
        });

        // 重新连接
        await syncService.reconnect();

        // 更新状态
        set({ 
          deviceConnectionStatus: 'connected',
          syncStatus: SyncStatus.IDLE
        });
      } catch (error) {
        set({ 
          syncError: error instanceof Error ? error.message : '重新连接失败',
          deviceConnectionStatus: 'disconnected',
          syncStatus: SyncStatus.ERROR
        });
        throw error;
      }
    },

    // 设置同步间隔
    setAutoSyncInterval: (interval) => {
      set({ autoSyncInterval: interval });
      
      // 重启自动同步以应用新间隔
      const { pauseAutoSync, resumeAutoSync } = get();
      pauseAutoSync();
      resumeAutoSync();
    },

    // 断开同步连接
    disconnect: async () => {
      try {
        const { syncService, autoSyncTimer } = get();

        // 清除自动同步定时器
        if (autoSyncTimer) {
          clearInterval(autoSyncTimer);
        }

        // 断开同步服务
        if (syncService) {
          await syncService.disconnect();
        }

        // 更新状态
        set({ 
          syncService: null,
          syncStatus: SyncStatus.IDLE,
          deviceConnectionStatus: 'disconnected',
          connectedDevices: [],
          autoSyncTimer: null
        });
      } catch (error) {
        set({ 
          syncError: error instanceof Error ? error.message : '断开连接失败'
        });
      }
    },

    // 获取同步状态
    getSyncStatus: () => {
      return get().syncStatus;
    },

    // 检查是否有未解决的冲突
    hasUnresolvedConflicts: () => {
      return get().conflicts.some(c => !c.resolved);
    },

    // 获取冲突计数
    getConflictCount: () => {
      return get().conflicts.filter(c => !c.resolved).length;
    }
  }));
};

// 同步存储类型
export type SyncStore = ReturnType<typeof createSyncStore>;
```

## 2. 单元测试

```typescript
import { describe, it, expect, beforeEach, afterEach, vi } from '@jest/globals';
import { createSyncStore, SyncStoreState } from './sync-store';
import { createAuthStore } from './auth-store';
import { SyncService, SyncStatus, SyncEvent, SyncEventType } from '../services/sync-service';

// 模拟SyncService
const mockSyncService = {
  connect: vi.fn().mockResolvedValue(true),
  disconnect: vi.fn().mockResolvedValue(undefined),
  sync: vi.fn().mockResolvedValue(true),
  forceSync: vi.fn().mockResolvedValue(true),
  pauseAutoSync: vi.fn(),
  resumeAutoSync: vi.fn(),
  resolveConflict: vi.fn().mockResolvedValue(undefined),
  reconnect: vi.fn().mockResolvedValue(undefined),
  on: vi.fn(),
  off: vi.fn(),
  getStatus: vi.fn().mockReturnValue(SyncStatus.IDLE)
};

// 模拟AuthStore
const mockAuthStore = {
  getState: vi.fn().mockReturnValue({
    user: { id: 'user-1' },
    currentNetwork: { id: 'network-1' },
    authToken: 'test-token',
    deviceId: 'device-1'
  })
};

// 保存事件回调
const eventCallbacks: Record<string, Function> = {};

// 模拟SyncService构造函数
vi.mock('../services/sync-service', () => ({
  SyncService: vi.fn().mockImplementation(() => ({
    connect: mockSyncService.connect,
    disconnect: mockSyncService.disconnect,
    sync: mockSyncService.sync,
    forceSync: mockSyncService.forceSync,
    pauseAutoSync: mockSyncService.pauseAutoSync,
    resumeAutoSync: mockSyncService.resumeAutoSync,
    resolveConflict: mockSyncService.resolveConflict,
    reconnect: mockSyncService.reconnect,
    on: (event, callback) => {
      eventCallbacks[event] = callback;
      mockSyncService.on(event, callback);
    },
    off: mockSyncService.off,
    getStatus: mockSyncService.getStatus
  })),
  SyncStatus: {
    IDLE: 'idle',
    SYNCING: 'syncing',
    ERROR: 'error',
    CONFLICT: 'conflict',
    PAUSED: 'paused'
  },
  SyncEventType: {
    CONFLICT_RESOLVED: 'conflictResolved'
  }
}));

describe('SyncStore', () => {
  let syncStore: any;

  beforeEach(() => {
    // 重置所有模拟
    vi.clearAllMocks();
    
    // 创建syncStore实例
    syncStore = createSyncStore(mockAuthStore as any);
  });

  describe('initial state', () => {
    it('should have correct initial state', () => {
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('idle');
      expect(state.lastSyncedAt).toBeNull();
      expect(state.syncError).toBeNull();
      expect(state.isForceSyncing).toBe(false);
      expect(state.conflicts).toEqual([]);
      expect(state.pendingChanges).toEqual([]);
      expect(state.syncService).toBeNull();
      expect(state.autoSyncInterval).toBe(30000);
      expect(state.autoSyncTimer).toBeNull();
      expect(state.deviceConnectionStatus).toBe('disconnected');
      expect(state.connectedDevices).toEqual([]);
    });
  });

  describe('initializeSync', () => {
    it('should initialize sync service successfully', async () => {
      // Call initializeSync
      const result = await syncStore.getState().initializeSync();
      
      // Verify result
      expect(result).toBe(true);
      
      // Verify SyncService was created
      expect(require('../services/sync-service').SyncService).toHaveBeenCalled();
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('idle');
      expect(state.syncService).not.toBeNull();
      expect(state.deviceConnectionStatus).toBe('connected');
      
      // Verify event listeners were registered
      expect(mockSyncService.on).toHaveBeenCalled();
    });

    it('should handle initialization failure', async () => {
      // Setup mock to fail connection
      mockSyncService.connect.mockResolvedValue(false);
      
      // Call initializeSync
      const result = await syncStore.getState().initializeSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify state was updated with error
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe('无法连接到同步服务');
      expect(state.deviceConnectionStatus).toBe('disconnected');
    });

    it('should handle missing auth information', async () => {
      // Setup mock to return null user
      mockAuthStore.getState.mockReturnValue({
        user: null,
        currentNetwork: null,
        authToken: null,
        deviceId: null
      });
      
      // Call initializeSync
      const result = await syncStore.getState().initializeSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify state was updated with error
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe('用户未登录或未加入网络');
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      // Initialize to set up event listeners
      syncStore.getState().initializeSync();
    });

    it('should handle syncStatusChanged event', () => {
      // Simulate a status change event
      eventCallbacks['syncStatusChanged']('syncing');
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('syncing');
    });

    it('should handle syncCompleted event', () => {
      // Set initial state to syncing with an error
      syncStore.setState({
        syncStatus: 'syncing',
        syncError: 'Some error',
        isForceSyncing: true
      });
      
      // Simulate a sync completed event
      eventCallbacks['syncCompleted']();
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('idle');
      expect(state.lastSyncedAt).not.toBeNull();
      expect(state.syncError).toBeNull();
      expect(state.isForceSyncing).toBe(false);
    });

    it('should handle syncError event', () => {
      // Simulate a sync error event
      const errorMessage = 'Sync failed';
      eventCallbacks['syncError'](errorMessage);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe(errorMessage);
    });

    it('should handle conflictDetected event', () => {
      // Simulate a conflict detected event
      const conflict = {
        id: 'conflict-1',
        type: 'card',
        resourceId: 'card-1',
        localVersion: { title: 'Local Title' },
        remoteVersion: { title: 'Remote Title' },
        createdAt: new Date(),
        resolved: false
      };
      
      eventCallbacks['conflictDetected'](conflict);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.conflicts).toHaveLength(1);
      expect(state.conflicts[0].id).toBe('conflict-1');
      expect(state.syncStatus).toBe('conflict');
    });

    it('should handle deviceConnected event', () => {
      // Simulate a device connected event
      const deviceInfo = {
        deviceId: 'device-2',
        deviceName: 'Test Device',
        deviceType: 'mobile',
        platform: 'ios',
        appVersion: '1.0.0',
        connectedAt: new Date(),
        lastActiveAt: new Date(),
        status: 'online'
      };
      
      eventCallbacks['deviceConnected'](deviceInfo);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.connectedDevices).toHaveLength(1);
      expect(state.connectedDevices[0].deviceId).toBe('device-2');
      expect(state.deviceConnectionStatus).toBe('connected');
    });

    it('should handle deviceDisconnected event', () => {
      // First add a device
      const deviceInfo = {
        deviceId: 'device-2',
        deviceName: 'Test Device',
        deviceType: 'mobile',
        platform: 'ios',
        appVersion: '1.0.0',
        connectedAt: new Date(),
        lastActiveAt: new Date(),
        status: 'online'
      };
      eventCallbacks['deviceConnected'](deviceInfo);
      
      // Then simulate device disconnected event
      eventCallbacks['deviceDisconnected']('device-2');
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.connectedDevices).toEqual([]);
    });

    it('should handle deviceConnectionStatusChanged event', () => {
      // Simulate connection status change
      eventCallbacks['deviceConnectionStatusChanged']('disconnected');
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.deviceConnectionStatus).toBe('disconnected');
    });
  });

  describe('triggerSync', () => {
    it('should trigger sync successfully when in IDLE state', async () => {
      // Setup mock to return success
      mockSyncService.sync.mockResolvedValue(true);
      
      // Call the method
      const result = await syncStore.getState().triggerSync();
      
      // Verify result
      expect(result).toBe(true);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('idle');
      expect(state.lastSyncedAt).not.toBeNull();
      expect(state.syncError).toBeNull();
      
      // Verify service method was called
      expect(mockSyncService.sync).toHaveBeenCalled();
    });

    it('should trigger sync successfully when in ERROR state', async () => {
      // Set initial state to ERROR
      syncStore.setState({ syncStatus: 'error' });
      
      // Setup mock to return success
      mockSyncService.sync.mockResolvedValue(true);
      
      // Call the method
      const result = await syncStore.getState().triggerSync();
      
      // Verify result
      expect(result).toBe(true);
    });

    it('should not trigger sync when already syncing', async () => {
      // Set initial state to SYNCING
      syncStore.setState({ syncStatus: 'syncing' });
      
      // Call the method
      const result = await syncStore.getState().triggerSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify service method was not called
      expect(mockSyncService.sync).not.toHaveBeenCalled();
    });

    it('should not trigger sync when force syncing', async () => {
      // Set initial state to force syncing
      syncStore.setState({ isForceSyncing: true });
      
      // Call the method
      const result = await syncStore.getState().triggerSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify service method was not called
      expect(mockSyncService.sync).not.toHaveBeenCalled();
    });

    it('should handle sync failure', async () => {
      // Setup mock to return failure
      mockSyncService.sync.mockResolvedValue(false);
      
      // Call the method
      const result = await syncStore.getState().triggerSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe('同步失败');
    });

    it('should handle sync errors', async () => {
      const errorMessage = 'Sync error';
      
      // Setup mock to throw error
      mockSyncService.sync.mockRejectedValue(new Error(errorMessage));
      
      // Call the method
      const result = await syncStore.getState().triggerSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe(errorMessage);
    });
  });

  describe('triggerForceSync', () => {
    it('should trigger force sync successfully', async () => {
      // Setup mock to return success
      mockSyncService.forceSync.mockResolvedValue(true);
      
      // Call the method
      const result = await syncStore.getState().triggerForceSync();
      
      // Verify result
      expect(result).toBe(true);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('idle');
      expect(state.isForceSyncing).toBe(false);
      expect(state.lastSyncedAt).not.toBeNull();
      
      // Verify service method was called
      expect(mockSyncService.forceSync).toHaveBeenCalled();
    });

    it('should not trigger force sync when already force syncing', async () => {
      // Set initial state to force syncing
      syncStore.setState({ isForceSyncing: true });
      
      // Call the method
      const result = await syncStore.getState().triggerForceSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify service method was not called
      expect(mockSyncService.forceSync).not.toHaveBeenCalled();
    });

    it('should handle force sync failure', async () => {
      // Setup mock to return failure
      mockSyncService.forceSync.mockResolvedValue(false);
      
      // Call the method
      const result = await syncStore.getState().triggerForceSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe('强制同步失败');
      expect(state.isForceSyncing).toBe(false);
    });

    it('should handle force sync errors', async () => {
      const errorMessage = 'Force sync error';
      
      // Setup mock to throw error
      mockSyncService.forceSync.mockRejectedValue(new Error(errorMessage));
      
      // Call the method
      const result = await syncStore.getState().triggerForceSync();
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe(errorMessage);
      expect(state.isForceSyncing).toBe(false);
    });
  });

  describe('pauseAutoSync', () => {
    it('should pause auto sync successfully', () => {
      // Call the method
      syncStore.getState().pauseAutoSync();
      
      // Verify service method was called
      expect(mockSyncService.pauseAutoSync).toHaveBeenCalled();
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('paused');
    });

    it('should handle errors during pause', () => {
      const errorMessage = 'Pause error';
      
      // Setup mock to throw error
      mockSyncService.pauseAutoSync.mockImplementation(() => {
        throw new Error(errorMessage);
      });
      
      // Call the method
      syncStore.getState().pauseAutoSync();
      
      // Verify error state was set
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe(errorMessage);
    });
  });

  describe('resumeAutoSync', () => {
    beforeEach(() => {
      // First pause auto sync
      syncStore.getState().pauseAutoSync();
    });

    it('should resume auto sync successfully', () => {
      // Call the method
      syncStore.getState().resumeAutoSync();
      
      // Verify service method was called
      expect(mockSyncService.resumeAutoSync).toHaveBeenCalled();
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('idle');
    });

    it('should handle errors during resume', () => {
      const errorMessage = 'Resume error';
      
      // Setup mock to throw error
      mockSyncService.resumeAutoSync.mockImplementation(() => {
        throw new Error(errorMessage);
      });
      
      // Call the method
      syncStore.getState().resumeAutoSync();
      
      // Verify error state was set
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe(errorMessage);
    });
  });

  describe('clearSyncError', () => {
    it('should clear any existing sync error', () => {
      // Set an error state
      const errorMessage = 'Test error';
      syncStore.setState({ syncError: errorMessage });
      
      // Call the method
      syncStore.getState().clearSyncError();
      
      // Verify error was cleared
      const state = syncStore.getState();
      expect(state.syncError).toBeNull();
    });
  });

  describe('reconnect', () => {
    it('should reconnect successfully', async () => {
      // Setup mock to resolve
      mockSyncService.reconnect.mockResolvedValue(undefined);
      
      // Call the method
      await syncStore.getState().reconnect();
      
      // Verify service method was called
      expect(mockSyncService.reconnect).toHaveBeenCalled();
      
      // Verify state was updated
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('idle');
      expect(state.lastSyncedAt).not.toBeNull();
      expect(state.syncError).toBeNull();
    });

    it('should handle reconnection errors', async () => {
      const errorMessage = 'Reconnection error';
      
      // Setup mock to throw error
      mockSyncService.reconnect.mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(syncStore.getState().reconnect()).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = syncStore.getState();
      expect(state.syncStatus).toBe('error');
      expect(state.syncError).toBe(errorMessage);
    });
  });
});
```

## 相关文档

- [API接口设计与单元测试](./api-interfaces-testing.md)
- [系统测试计划](../testing/system-testing-plan.md)
- [回归测试计划](../testing/regression-testing-plan.md)
- [用户界面测试](../testing/ui-testing.md)
- [测试工具与技术](../testing/testing-tools.md)

[返回API测试设计文档索引](./api-testing-design-index.md)
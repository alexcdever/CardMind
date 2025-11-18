# SyncService API

## 1. 接口定义

```typescript
// src/services/sync/SyncService.ts

/**
 * 同步事件类型
 */
export enum SyncEventType {
  /**
   * 卡片创建事件
   */
  CARD_CREATED = 'CARD_CREATED',
  
  /**
   * 卡片更新事件
   */
  CARD_UPDATED = 'CARD_UPDATED',
  
  /**
   * 卡片删除事件
   */
  CARD_DELETED = 'CARD_DELETED',
  
  /**
   * 设备状态更新事件
   */
  DEVICE_STATUS_UPDATED = 'DEVICE_STATUS_UPDATED',
  
  /**
   * 同步状态变更事件
   */
  SYNC_STATUS_CHANGED = 'SYNC_STATUS_CHANGED',
}

/**
 * 同步状态
 */
export enum SyncStatus {
  /**
   * 未同步
   */
  NOT_SYNCED = 'NOT_SYNCED',
  
  /**
   * 正在同步
   */
  SYNCING = 'SYNCING',
  
  /**
   * 已同步
   */
  SYNCED = 'SYNCED',
  
  /**
   * 同步错误
   */
  ERROR = 'ERROR',
}

/**
 * 同步事件接口
 */
export interface SyncEvent<T = any> {
  /**
   * 事件类型
   */
  type: SyncEventType;
  
  /**
   * 事件数据
   */
  data: T;
  
  /**
   * 事件创建时间
   */
  timestamp: number;
  
  /**
   * 发送者设备ID
   */
  senderId: string;
}

/**
 * 同步服务接口
 */
export interface SyncService {
  /**
   * 同步卡片更新
   * @param event 同步事件
   */
  syncCardUpdate(event: SyncEvent): void;
  
  /**
   * 广播设备信息
   * @param deviceInfo 设备信息
   */
  broadcastDeviceInfo(deviceInfo: any): void;
  
  /**
   * 开始同步服务
   */
  startSync(): void;
  
  /**
   * 停止同步服务
   */
  stopSync(): void;
  
  /**
   * 获取当前同步状态
   * @returns 同步状态
   */
  getSyncStatus(): SyncStatus;
  
  /**
   * 强制同步
   * @returns 同步结果
   */
  forceSync(): Promise<boolean>;
  
  /**
   * 注册同步事件监听器
   * @param eventType 事件类型
   * @param listener 事件监听器
   */
  on<T>(eventType: SyncEventType, listener: (event: SyncEvent<T>) => void): void;
  
  /**
   * 取消注册同步事件监听器
   * @param eventType 事件类型
   * @param listener 事件监听器
   */
  off<T>(eventType: SyncEventType, listener: (event: SyncEvent<T>) => void): void;
  
  /**
   * 处理冲突
   * @param localData 本地数据
   * @param remoteData 远程数据
   * @returns 解决冲突后的数据
   */
  resolveConflict<T>(localData: T, remoteData: T): T;
}
```

## 2. 单元测试

```typescript
// src/services/sync/SyncService.test.ts
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { SyncServiceImpl } from './SyncServiceImpl';
import { IDatabaseService } from '../database/DatabaseService';
import { DeviceServiceImpl } from '../device/DeviceServiceImpl';
import { SyncEventType, SyncStatus } from './SyncService';

// Mock dependencies
jest.mock('../database/DatabaseService');
jest.mock('../device/DeviceServiceImpl');

const mockDatabaseService = {
  get: jest.fn(),
  set: jest.fn(),
  getAll: jest.fn(),
} as unknown as IDatabaseService;

const mockDeviceService = {
  getCurrentDeviceInfo: jest.fn().mockReturnValue({
    id: 'current-device-id',
    name: 'Test Device',
    type: 'desktop',
    platform: 'windows',
    appVersion: '1.0.0',
    joinedAt: Date.now(),
    lastActiveAt: Date.now(),
    isOnline: true,
  }),
} as unknown as DeviceServiceImpl;

describe('SyncService', () => {
  let syncService: SyncServiceImpl;
  
  beforeEach(() => {
    syncService = new SyncServiceImpl(mockDatabaseService, mockDeviceService);
    jest.clearAllMocks();
  });

  describe('syncCardUpdate', () => {
    it('should broadcast card update event', () => {
      const mockEvent = {
        type: SyncEventType.CARD_CREATED,
        data: { id: 'card-123', title: 'Test Card' },
        timestamp: Date.now(),
        senderId: 'current-device-id',
      };
      
      // Mock the internal broadcast method to verify it's called
      const broadcastSpy = jest.spyOn(syncService as any, 'broadcastEvent').mockImplementation(() => {});
      
      syncService.syncCardUpdate(mockEvent);
      
      expect(broadcastSpy).toHaveBeenCalledWith(mockEvent);
      
      // Restore the original method
      broadcastSpy.mockRestore();
    });

    it('should handle different event types', () => {
      const events = [
        {
          type: SyncEventType.CARD_CREATED,
          data: { id: 'card-123', title: 'New Card' },
          timestamp: Date.now(),
          senderId: 'current-device-id',
        },
        {
          type: SyncEventType.CARD_UPDATED,
          data: { id: 'card-123', title: 'Updated Card' },
          timestamp: Date.now(),
          senderId: 'current-device-id',
        },
        {
          type: SyncEventType.CARD_DELETED,
          data: { id: 'card-123' },
          timestamp: Date.now(),
          senderId: 'current-device-id',
        },
      ];
      
      const broadcastSpy = jest.spyOn(syncService as any, 'broadcastEvent').mockImplementation(() => {});
      
      events.forEach(event => {
        syncService.syncCardUpdate(event);
        expect(broadcastSpy).toHaveBeenCalledWith(event);
      });
      
      broadcastSpy.mockRestore();
    });
  });

  describe('broadcastDeviceInfo', () => {
    it('should broadcast device info update', () => {
      const mockDeviceInfo = {
        id: 'device-456',
        name: 'New Device',
        isOnline: true,
      };
      
      const broadcastSpy = jest.spyOn(syncService as any, 'broadcastEvent').mockImplementation(() => {});
      
      syncService.broadcastDeviceInfo(mockDeviceInfo);
      
      expect(broadcastSpy).toHaveBeenCalledWith(expect.objectContaining({
        type: SyncEventType.DEVICE_STATUS_UPDATED,
        data: mockDeviceInfo,
        senderId: 'current-device-id',
      }));
      
      broadcastSpy.mockRestore();
    });
  });

  describe('startSync and stopSync', () => {
    it('should start and stop sync service', () => {
      // Mock the internal methods
      const initSpy = jest.spyOn(syncService as any, 'initializeSyncConnection').mockImplementation(() => {});
      const closeSpy = jest.spyOn(syncService as any, 'closeSyncConnection').mockImplementation(() => {});
      
      syncService.startSync();
      expect(initSpy).toHaveBeenCalled();
      expect(syncService.getSyncStatus()).not.toBe(SyncStatus.NOT_SYNCED);
      
      syncService.stopSync();
      expect(closeSpy).toHaveBeenCalled();
      
      initSpy.mockRestore();
      closeSpy.mockRestore();
    });
  });

  describe('getSyncStatus', () => {
    it('should return the current sync status', () => {
      // Initially, it should be NOT_SYNCED
      expect(syncService.getSyncStatus()).toBe(SyncStatus.NOT_SYNCED);
      
      // Mock the internal status
      (syncService as any).syncStatus = SyncStatus.SYNCED;
      expect(syncService.getSyncStatus()).toBe(SyncStatus.SYNCED);
      
      (syncService as any).syncStatus = SyncStatus.ERROR;
      expect(syncService.getSyncStatus()).toBe(SyncStatus.ERROR);
    });
  });

  describe('forceSync', () => {
    it('should trigger a force sync', async () => {
      // Mock the internal sync method
      const performSyncSpy = jest.spyOn(syncService as any, 'performFullSync').mockResolvedValue(true);
      
      const result = await syncService.forceSync();
      
      expect(result).toBe(true);
      expect(performSyncSpy).toHaveBeenCalled();
      
      performSyncSpy.mockRestore();
    });

    it('should handle sync failure', async () => {
      // Mock a failed sync
      const performSyncSpy = jest.spyOn(syncService as any, 'performFullSync').mockResolvedValue(false);
      
      const result = await syncService.forceSync();
      
      expect(result).toBe(false);
      
      performSyncSpy.mockRestore();
    });
  });

  describe('event listeners', () => {
    it('should register and trigger event listeners', () => {
      const mockListener = jest.fn();
      const testEvent = {
        type: SyncEventType.SYNC_STATUS_CHANGED,
        data: { status: SyncStatus.SYNCED },
        timestamp: Date.now(),
        senderId: 'test-sender',
      };
      
      // Register the listener
      syncService.on(SyncEventType.SYNC_STATUS_CHANGED, mockListener);
      
      // Manually trigger the event using the internal emit method
      (syncService as any).emit(testEvent.type, testEvent);
      
      expect(mockListener).toHaveBeenCalledWith(testEvent);
    });

    it('should unregister event listeners', () => {
      const mockListener = jest.fn();
      const testEvent = {
        type: SyncEventType.CARD_CREATED,
        data: { id: 'card-789' },
        timestamp: Date.now(),
        senderId: 'test-sender',
      };
      
      // Register then unregister the listener
      syncService.on(SyncEventType.CARD_CREATED, mockListener);
      syncService.off(SyncEventType.CARD_CREATED, mockListener);
      
      // Trigger the event
      (syncService as any).emit(testEvent.type, testEvent);
      
      // Listener should not be called
      expect(mockListener).not.toHaveBeenCalled();
    });

    it('should handle multiple listeners for the same event', () => {
      const listener1 = jest.fn();
      const listener2 = jest.fn();
      const testEvent = {
        type: SyncEventType.CARD_UPDATED,
        data: { id: 'card-123', title: 'Updated' },
        timestamp: Date.now(),
        senderId: 'test-sender',
      };
      
      // Register multiple listeners
      syncService.on(SyncEventType.CARD_UPDATED, listener1);
      syncService.on(SyncEventType.CARD_UPDATED, listener2);
      
      // Trigger the event
      (syncService as any).emit(testEvent.type, testEvent);
      
      // All listeners should be called
      expect(listener1).toHaveBeenCalledWith(testEvent);
      expect(listener2).toHaveBeenCalledWith(testEvent);
    });
  });

  describe('resolveConflict', () => {
    it('should resolve conflicts using last updated timestamp', () => {
      const localData = {
        id: 'card-123',
        title: 'Local Title',
        content: 'Local Content',
        updatedAt: 1000, // Older timestamp
      };
      
      const remoteData = {
        id: 'card-123',
        title: 'Remote Title',
        content: 'Remote Content',
        updatedAt: 2000, // Newer timestamp
      };
      
      const resolvedData = syncService.resolveConflict(localData, remoteData);
      
      // Should prefer the remote data with newer timestamp
      expect(resolvedData.title).toBe('Remote Title');
      expect(resolvedData.content).toBe('Remote Content');
    });

    it('should prefer local data if timestamps are equal', () => {
      const localData = {
        id: 'card-123',
        title: 'Local Title',
        content: 'Local Content',
        updatedAt: 1000,
      };
      
      const remoteData = {
        id: 'card-123',
        title: 'Remote Title',
        content: 'Remote Content',
        updatedAt: 1000, // Same timestamp
      };
      
      const resolvedData = syncService.resolveConflict(localData, remoteData);
      
      // Should prefer local data in case of timestamp tie
      expect(resolvedData.title).toBe('Local Title');
      expect(resolvedData.content).toBe('Local Content');
    });

    it('should handle complex object conflicts', () => {
      const localData = {
        id: 'card-123',
        title: 'Card Title',
        metadata: {
          tags: ['local-tag'],
          isStarred: false,
        },
        updatedAt: 2000, // Newer timestamp
      };
      
      const remoteData = {
        id: 'card-123',
        title: 'Card Title',
        metadata: {
          tags: ['remote-tag'],
          isStarred: true,
        },
        updatedAt: 1000, // Older timestamp
      };
      
      const resolvedData = syncService.resolveConflict(localData, remoteData);
      
      // Should prefer the local data with newer timestamp
      expect(resolvedData.metadata.tags).toEqual(['local-tag']);
      expect(resolvedData.metadata.isStarred).toBe(false);
    });
  });
});
```

## 导航与引用

- [API测试设计文档索引](../api-testing-design-index.md)
- [AuthService API](auth-service-api.md)
- [DeviceService API](device-service-api.md)
- [CardService API](card-service-api.md)
- [EncryptionService API](encryption-service-api.md)
- [状态管理Store API](store-apis-testing.md)
- [系统测试计划](../testing/system-testing-plan.md)
- [回归测试计划](../testing/regression-testing-plan.md)
- [用户界面测试](../testing/ui-testing.md)
- [测试工具与技术](../testing/testing-tools.md)
/**
 * 同步服务测试
 */

import syncService from '@/services/syncService';
import useSyncStore from '@/stores/syncStore';
import useDeviceStore from '@/stores/deviceStore';
import useAuthStore from '@/stores/authStore';
import { getCards, saveCards } from '@/services/localStorageService';

// Mock all dependencies
jest.mock('@/stores/syncStore');
jest.mock('@/stores/deviceStore');
jest.mock('@/stores/authStore');
jest.mock('@/services/localStorageService');

// Mock Yjs and related libraries
jest.mock('yjs', () => ({
  Doc: jest.fn().mockImplementation(() => ({
    getArray: jest.fn().mockReturnValue({
      toArray: jest.fn().mockReturnValue([]),
      push: jest.fn(),
      delete: jest.fn(),
      insert: jest.fn(),
      observe: jest.fn()
    }),
    on: jest.fn(),
    destroy: jest.fn()
  })),
  encodeStateAsUpdate: jest.fn().mockReturnValue(new Uint8Array([1, 2, 3])),
  applyUpdate: jest.fn()
}));

jest.mock('y-webrtc', () => ({
  WebrtcProvider: jest.fn().mockImplementation((roomId, doc, options) => ({
    disconnect: jest.fn(),
    destroy: jest.fn(),
    on: jest.fn(),
    awareness: {
      setLocalStateField: jest.fn(),
      getStates: jest.fn().mockReturnValue(new Map()),
      getStatesCount: jest.fn().mockReturnValue(1)
    }
  }))
}));

jest.mock('y-indexeddb', () => ({
  IndexeddbPersistence: jest.fn().mockImplementation((name, doc) => ({
    destroy: jest.fn()
  }))
}));

jest.mock('y-protocols/awareness', () => ({
  Awareness: jest.fn().mockImplementation((doc) => ({
    setLocalStateField: jest.fn(),
    getStates: jest.fn().mockReturnValue(new Map()),
    getStatesCount: jest.fn().mockReturnValue(1)
  }))
}));

// Mock stores
const mockSyncStore = {
  setOnlineStatus: jest.fn(),
  setSyncingStatus: jest.fn(),
  setSyncError: jest.fn(),
  updateLastSyncTime: jest.fn(),
  updateConnectedDevices: jest.fn(),
  isOnline: true,
  isSyncing: false,
  connectedDevices: 0
};

const mockDeviceStore = {
  getDeviceInfo: jest.fn().mockReturnValue({
    id: 'test-device-id',
    nickname: '测试设备',
    deviceType: 'desktop',
    lastSeen: Date.now()
  }),
  updateOnlineDevices: jest.fn()
};

const mockAuthStore = {
  currentNetworkId: null
};

describe('SyncService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Setup mock implementations
    (useSyncStore as any).getState = jest.fn().mockReturnValue(mockSyncStore);
    (useDeviceStore as any).getState = jest.fn().mockReturnValue(mockDeviceStore);
    (useAuthStore as any).getState = jest.fn().mockReturnValue(mockAuthStore);
    
    // Mock console methods to avoid cluttering test output
    jest.spyOn(console, 'log').mockImplementation();
    jest.spyOn(console, 'error').mockImplementation();
    jest.spyOn(console, 'warn').mockImplementation();
  });

  afterEach(() => {
    jest.restoreAllMocks();
    // Clean up any timers or intervals
    jest.clearAllTimers();
    // Clean up syncService state
    syncService.cleanup();
    // Reset the internal state
    (syncService as any).isInitialized = false;
    (syncService as any).isNetworkJoined = false;
    (syncService as any).networkId = null;
    (syncService as any).yCardsArray = null;
    (syncService as any).ydoc = null;
    (syncService as any).webrtcProvider = null;
    (syncService as any).persistence = null;
    (syncService as any).periodicBroadcastTimer = null;
  });

  describe('initialize', () => {
    it('应该成功初始化同步服务', () => {
      syncService.initialize();
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 开始初始化同步服务基础功能');
      expect(console.log).toHaveBeenCalledWith('[SyncService] 同步服务基础功能初始化完成');
    });

    it('应该避免重复初始化', () => {
      syncService.initialize();
      syncService.initialize();
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 同步服务已经初始化，跳过重复初始化');
    });
  });

  describe('joinNetwork', () => {
    const validAccessCode = 'eyJhZGRyZXNzIjoibG9jYWxob3N0OjUxNzMiLCJ0aW1lc3RhbXAiOjEyMzQ1Njc4OTAsInJhbmRvbUNvZGUiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAifQ';
    
    beforeEach(() => {
      syncService.initialize();
    });

    it('应该成功加入网络', () => {
      syncService.joinNetwork(validAccessCode);
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 开始加入网络:', validAccessCode);
      expect(mockSyncStore.setOnlineStatus).toHaveBeenCalledWith(true);
    });

    it('应该避免重复加入同一网络', () => {
      syncService.joinNetwork(validAccessCode);
      jest.clearAllMocks();
      
      syncService.joinNetwork(validAccessCode);
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 已经在该网络中，跳过加入');
    });

    it('应该处理无效的访问码', () => {
      const invalidAccessCode = 'invalid-code';
      syncService.joinNetwork(invalidAccessCode);
      
      expect(console.warn).toHaveBeenCalledWith('[SyncService] 无法解析访问码，使用默认设置');
    });

    it('应该在未初始化时返回错误', () => {
      // Reset to uninitialized state
      (syncService as any).isInitialized = false;
      
      syncService.joinNetwork(validAccessCode);
      
      expect(console.error).toHaveBeenCalledWith('[SyncService] 同步服务未初始化，请先调用initialize方法');
    });
  });

  describe('leaveNetwork', () => {
    beforeEach(async () => {
      syncService.initialize();
      const validAccessCode = 'eyJhZGRyZXNzIjoibG9jYWxob3N0OjUxNzMiLCJ0aW1lc3RhbXAiOjEyMzQ1Njc4OTAsInJhbmRvbUNvZGUiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAifQ';
      syncService.joinNetwork(validAccessCode);
      // 等待网络加入完成
      await new Promise(resolve => setTimeout(resolve, 300));
      jest.clearAllMocks();
    });

    it('应该成功离开网络', () => {
      syncService.leaveNetwork();
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 开始离开网络');
      expect(console.log).toHaveBeenCalledWith('[SyncService] 已离开网络');
      expect(mockDeviceStore.updateOnlineDevices).toHaveBeenCalledWith([]);
      expect(mockSyncStore.updateConnectedDevices).toHaveBeenCalledWith(0);
    });

    it('应该处理未加入网络的情况', () => {
      syncService.leaveNetwork(); // Leave first time
      jest.clearAllMocks();
      
      syncService.leaveNetwork(); // Try to leave again
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 未加入网络，跳过离开操作');
    });
  });

  describe('broadcastCardUpdate', () => {
    beforeEach(async () => {
      syncService.initialize();
      const validAccessCode = 'eyJhZGRyZXNzIjoibG9jYWxob3N0OjUxNzMiLCJ0aW1lc3RhbXAiOjEyMzQ1Njc4OTAsInJhbmRvbUNvZGUiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAifQ';
      syncService.joinNetwork(validAccessCode);
      // 等待Yjs环境完全设置
      await new Promise(resolve => setTimeout(resolve, 300));
    });

    it('应该成功广播卡片更新', () => {
      const testCard = {
        id: 'card-123',
        title: '测试卡片',
        content: '测试内容',
        createdAt: Date.now(),
        updatedAt: Date.now(),
        isDeleted: false,
        tags: []
      };

      // 检查Yjs数组是否已初始化
      const yCardsArray = (syncService as any).yCardsArray;
      console.log('Yjs数组状态:', yCardsArray ? '已初始化' : '未初始化');

      syncService.broadcastCardUpdate(testCard);
      
      // 检查调用的日志
      const calls = (console.log as jest.Mock).mock.calls;
      console.log('实际调用的日志:', calls);
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 广播卡片更新:', 'card-123');
      // 由于这是新卡片，应该显示"新卡片已添加到Yjs"
      if (yCardsArray) {
        expect(console.log).toHaveBeenCalledWith('[SyncService] 新卡片已添加到Yjs:', 'card-123');
      }
    });

    it('应该处理Yjs数组未初始化的情况', () => {
      // Force yCardsArray to be null
      (syncService as any).yCardsArray = null;
      
      const testCard = {
        id: 'card-123',
        title: '测试卡片',
        content: '测试内容',
        createdAt: Date.now(),
        updatedAt: Date.now(),
        isDeleted: false,
        tags: []
      };

      syncService.broadcastCardUpdate(testCard);
      
      expect(console.warn).toHaveBeenCalledWith('[SyncService] Yjs卡片数组未初始化，无法广播卡片更新');
    });
  });

  describe('requestSync', () => {
    beforeEach(async () => {
      syncService.initialize();
      const validAccessCode = 'eyJhZGRyZXNzIjoibG9jYWxob3N0OjUxNzMiLCJ0aW1lc3RhbXAiOjEyMzQ1Njc4OTAsInJhbmRvbUNvZGUiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAifQ';
      syncService.joinNetwork(validAccessCode);
      // 等待网络加入完成
      await new Promise(resolve => setTimeout(resolve, 300));
      jest.clearAllMocks();
    });

    it('应该成功执行同步请求', () => {
      syncService.requestSync();
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 执行同步请求');
      expect(console.log).toHaveBeenCalledWith('[SyncService] 同步请求完成');
    });

    it('应该处理同步失败的情况', () => {
      (getCards as jest.Mock).mockImplementation(() => {
        throw new Error('存储错误');
      });

      syncService.requestSync();
      
      expect(console.error).toHaveBeenCalledWith('[SyncService] 本地存储到Yjs同步失败:', expect.any(Error));
    });
  });

  describe('getConnectionStatus', () => {
    beforeEach(() => {
      syncService.initialize();
    });

    it('应该返回正确的连接状态（未加入网络）', () => {
      const status = syncService.getConnectionStatus();
      
      expect(status).toEqual({
        isConnected: false,
        peersCount: 0,
        isSyncing: false
      });
    });

    it('应该返回正确的连接状态（已加入网络）', async () => {
      const validAccessCode = 'eyJhZGRyZXNzIjoibG9jYWxob3N0OjUxNzMiLCJ0aW1lc3RhbXAiOjEyMzQ1Njc4OTAsInJhbmRvbUNvZGUiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAifQ';
      syncService.joinNetwork(validAccessCode);
      
      // 等待异步操作完成，给Yjs环境更多时间设置
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // 检查isNetworkJoined标志
      const isNetworkJoined = (syncService as any).isNetworkJoined;
      console.log('isNetworkJoined状态:', isNetworkJoined);
      
      const status = syncService.getConnectionStatus();
      console.log('连接状态:', status);
      
      // joinNetwork方法会设置isNetworkJoined为true，所以isConnected应该为true
      // 即使WebRTC连接失败，只要isNetworkJoined为true，就应该返回true
      expect(status.isConnected).toBe(true);
      expect(status.peersCount).toBeGreaterThanOrEqual(0);
      expect(status.isSyncing).toBe(false);
    });
  });

  describe('cleanup', () => {
    beforeEach(async () => {
      syncService.initialize();
      const validAccessCode = 'eyJhZGRyZXNzIjoibG9jYWxob3N0OjUxNzMiLCJ0aW1lc3RhbXAiOjEyMzQ1Njc4OTAsInJhbmRvbUNvZGUiOiIxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAifQ';
      syncService.joinNetwork(validAccessCode);
      // 等待网络加入完成
      await new Promise(resolve => setTimeout(resolve, 300));
    });

    it('应该成功清理资源', () => {
      syncService.cleanup();
      
      expect(console.log).toHaveBeenCalledWith('[SyncService] 清理同步服务资源');
      expect(console.log).toHaveBeenCalledWith('[SyncService] 同步服务资源清理完成');
      expect(mockSyncStore.setOnlineStatus).toHaveBeenCalledWith(false);
      expect(mockSyncStore.updateConnectedDevices).toHaveBeenCalledWith(0);
    });
  });

  describe('Base64 encoding/decoding', () => {
    it('应该正确解码Base64数据', () => {
      // 使用标准的btoa来编码测试数据
      const testData = {
        address: 'localhost:5173',
        timestamp: 1234567890,
        randomCode: '12345678901234567890123456789012'
      };

      // 使用标准的Base64编码
      const encoded = btoa(JSON.stringify(testData)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      const decoded = (syncService as any).decodeBase64(encoded);
      
      expect(JSON.parse(decoded)).toEqual(testData);
    });

    it('应该处理无效的Base64数据', () => {
      const invalidData = 'invalid-base64-data!';
      const result = (syncService as any).decodeBase64(invalidData);
      
      expect(result).toBe('');
    });
  });

  describe('extractNetworkInfo', () => {
    it('应该从有效网络ID中提取网络信息', () => {
      const testData = {
        address: 'localhost:5173',
        timestamp: 1234567890,
        randomCode: '12345678901234567890123456789012'
      };

      // 使用标准的Base64编码
      const encoded = btoa(JSON.stringify(testData)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      const result = (syncService as any).extractNetworkInfo(encoded);
      
      expect(result).toEqual(testData);
    });

    it('应该处理无效的网络ID', () => {
      const invalidCode = 'invalid-code';
      const result = (syncService as any).extractNetworkInfo(invalidCode);
      
      expect(result).toBeNull();
    });

    it('应该处理缺少必要字段的网络ID', () => {
      const incompleteData = {
        address: 'localhost:5173',
        timestamp: 1234567890
        // missing randomCode
      };

      // 使用标准的Base64编码
      const encoded = btoa(JSON.stringify(incompleteData)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      const result = (syncService as any).extractNetworkInfo(encoded);
      
      expect(result).toBeNull();
    });
  });
});
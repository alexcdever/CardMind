# deviceStore API

## 1. 接口定义

```typescript
// src/stores/deviceStore.ts
import { create } from 'zustand';
import { DeviceService, DeviceInfo } from '../services/device/DeviceService';

/**
 * 设备状态接口
 */
export interface DeviceState {
  /**
   * 当前设备信息
   */
  currentDevice: DeviceInfo | null;
  
  /**
   * 所有设备列表
   */
  devices: DeviceInfo[];
  
  /**
   * 在线设备列表
   */
  onlineDevices: DeviceInfo[];
  
  /**
   * 是否正在加载设备信息
   */
  isLoading: boolean;
  
  /**
   * 错误信息
   */
  error: string | null;
  
  /**
   * 初始化设备信息
   */
  initialize: () => Promise<void>;
  
  /**
   * 更新设备名称
   * @param name 新设备名称
   */
  updateDeviceName: (name: string) => Promise<void>;
  
  /**
   * 刷新设备列表
   */
  refreshDevices: () => Promise<void>;
  
  /**
   * 更新设备在线状态
   * @param deviceId 设备ID
   * @param isOnline 是否在线
   */
  updateDeviceStatus: (deviceId: string, isOnline: boolean) => void;
  
  /**
   * 清除错误信息
   */
  clearError: () => void;
}

/**
 * 创建设备状态存储
 * @param deviceService 设备服务实例
 * @returns 设备状态存储
 */
export const createDeviceStore = (deviceService: DeviceService) => 
  create<DeviceState>((set, get) => ({
    currentDevice: null,
    devices: [],
    onlineDevices: [],
    isLoading: false,
    error: null,
    
    initialize: async () => {
      set({ isLoading: true, error: null });
      try {
        // 获取当前设备信息
        const currentDevice = deviceService.getCurrentDeviceInfo();
        
        // 注册设备
        await deviceService.registerDevice();
        
        // 获取所有设备
        await get().refreshDevices();
        
        set({ 
          currentDevice,
          isLoading: false 
        });
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '设备初始化失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    updateDeviceName: async (name: string) => {
      set({ isLoading: true, error: null });
      try {
        const success = await deviceService.updateDeviceName(name);
        if (success) {
          const currentDevice = deviceService.getCurrentDeviceInfo();
          set({ 
            currentDevice,
            isLoading: false 
          });
        } else {
          throw new Error('更新设备名称失败');
        }
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '更新设备名称失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    refreshDevices: async () => {
      try {
        const devices = await deviceService.getAllDevices();
        const onlineDevices = await deviceService.getOnlineDevices();
        
        set({ 
          devices,
          onlineDevices 
        });
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '刷新设备列表失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    updateDeviceStatus: (deviceId: string, isOnline: boolean) => {
      deviceService.updateDeviceOnlineStatus(deviceId, isOnline);
      
      // 更新本地状态
      set((state) => {
        const updatedDevices = state.devices.map(device => 
          device.id === deviceId 
            ? { ...device, isOnline, lastActiveAt: Date.now() }
            : device
        );
        
        const updatedOnlineDevices = updatedDevices.filter(device => device.isOnline);
        
        return {
          devices: updatedDevices,
          onlineDevices: updatedOnlineDevices
        };
      });
    },
    
    clearError: () => set({ error: null }),
  }));

/**
 * 设备状态存储类型
 */
export type DeviceStore = ReturnType<typeof createDeviceStore>;
```

## 2. 单元测试

```typescript
// src/stores/deviceStore.test.ts
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { createDeviceStore, DeviceState } from './deviceStore';
import { DeviceService, DeviceInfo } from '../services/device/DeviceService';

// Mock the DeviceService
const mockDeviceService = {
  getCurrentDeviceInfo: jest.fn(),
  getAllDevices: jest.fn(),
  getOnlineDevices: jest.fn(),
  updateDeviceName: jest.fn(),
  registerDevice: jest.fn(),
  updateDeviceOnlineStatus: jest.fn(),
} as unknown as DeviceService;

// Mock device data
const mockCurrentDevice: DeviceInfo = {
  id: 'current-device-id',
  name: 'Current Device',
  type: 'desktop',
  platform: 'windows',
  appVersion: '1.0.0',
  joinedAt: Date.now() - 3600000,
  lastActiveAt: Date.now(),
  isOnline: true,
};

const mockDevices: DeviceInfo[] = [
  mockCurrentDevice,
  {
    id: 'device-1',
    name: 'Device 1',
    type: 'mobile',
    platform: 'android',
    appVersion: '1.0.0',
    joinedAt: Date.now() - 7200000,
    lastActiveAt: Date.now() - 60000,
    isOnline: true,
  },
  {
    id: 'device-2',
    name: 'Device 2',
    type: 'tablet',
    platform: 'ios',
    appVersion: '1.0.0',
    joinedAt: Date.now() - 10800000,
    lastActiveAt: Date.now() - 3600000,
    isOnline: false,
  },
];

describe('deviceStore', () => {
  let deviceStore: any;
  
  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();
    
    // Setup default mock return values
    (mockDeviceService.getCurrentDeviceInfo as jest.Mock).mockReturnValue(mockCurrentDevice);
    (mockDeviceService.getAllDevices as jest.Mock).mockResolvedValue(mockDevices);
    (mockDeviceService.getOnlineDevices as jest.Mock).mockResolvedValue(
      mockDevices.filter(device => device.isOnline)
    );
    (mockDeviceService.registerDevice as jest.Mock).mockResolvedValue(true);
    
    // Create a new store instance for each test
    deviceStore = createDeviceStore(mockDeviceService);
  });

  describe('initial state', () => {
    it('should initialize with correct default values', () => {
      const state = deviceStore.getState();
      
      expect(state.currentDevice).toBeNull();
      expect(state.devices).toEqual([]);
      expect(state.onlineDevices).toEqual([]);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
    });
  });

  describe('initialize', () => {
    it('should initialize device information successfully', async () => {
      // Call the method
      await deviceStore.getState().initialize();
      
      // Verify state was updated
      const state = deviceStore.getState();
      expect(state.currentDevice).toEqual(mockCurrentDevice);
      expect(state.devices).toEqual(mockDevices);
      expect(state.onlineDevices.length).toBe(2); // Only 2 devices are online in mock data
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service methods were called
      expect(mockDeviceService.getCurrentDeviceInfo).toHaveBeenCalled();
      expect(mockDeviceService.registerDevice).toHaveBeenCalled();
    });

    it('should handle errors during initialization', async () => {
      const errorMessage = 'Device initialization failed';
      
      // Setup mock to throw error
      (mockDeviceService.registerDevice as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(deviceStore.getState().initialize()).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = deviceStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('updateDeviceName', () => {
    it('should update the device name successfully', async () => {
      const newDeviceName = 'New Device Name';
      const updatedDevice = { ...mockCurrentDevice, name: newDeviceName };
      
      // First initialize to set current device
      await deviceStore.getState().initialize();
      
      // Setup mocks for this test
      (mockDeviceService.updateDeviceName as jest.Mock).mockResolvedValue(true);
      (mockDeviceService.getCurrentDeviceInfo as jest.Mock).mockReturnValue(updatedDevice);
      
      // Call the method
      await deviceStore.getState().updateDeviceName(newDeviceName);
      
      // Verify state was updated
      const state = deviceStore.getState();
      expect(state.currentDevice?.name).toBe(newDeviceName);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockDeviceService.updateDeviceName).toHaveBeenCalledWith(newDeviceName);
    });

    it('should handle failed device name update', async () => {
      const newDeviceName = 'New Device Name';
      
      // Setup mock to return failure
      (mockDeviceService.updateDeviceName as jest.Mock).mockResolvedValue(false);
      
      // Call the method and expect it to throw
      await expect(deviceStore.getState().updateDeviceName(newDeviceName)).rejects.toThrow('更新设备名称失败');
      
      // Verify error state was set
      const state = deviceStore.getState();
      expect(state.error).toBe('更新设备名称失败');
      expect(state.isLoading).toBe(false);
    });

    it('should handle errors during device name update', async () => {
      const newDeviceName = 'New Device Name';
      const errorMessage = 'Update error';
      
      // Setup mock to throw error
      (mockDeviceService.updateDeviceName as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(deviceStore.getState().updateDeviceName(newDeviceName)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = deviceStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('refreshDevices', () => {
    it('should refresh the device list successfully', async () => {
      // Call the method
      await deviceStore.getState().refreshDevices();
      
      // Verify state was updated
      const state = deviceStore.getState();
      expect(state.devices).toEqual(mockDevices);
      expect(state.onlineDevices.length).toBe(2); // Only 2 devices are online in mock data
      
      // Verify service methods were called
      expect(mockDeviceService.getAllDevices).toHaveBeenCalled();
      expect(mockDeviceService.getOnlineDevices).toHaveBeenCalled();
    });

    it('should handle errors during device list refresh', async () => {
      const errorMessage = 'Refresh error';
      
      // Setup mock to throw error
      (mockDeviceService.getAllDevices as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(deviceStore.getState().refreshDevices()).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = deviceStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('updateDeviceStatus', () => {
    it('should update a device\'s online status', async () => {
      // First initialize to set devices
      await deviceStore.getState().initialize();
      
      const deviceIdToUpdate = 'device-2'; // This device is offline in mock data
      
      // Call the method to update status
      deviceStore.getState().updateDeviceStatus(deviceIdToUpdate, true);
      
      // Verify state was updated
      const state = deviceStore.getState();
      const updatedDevice = state.devices.find((device: DeviceInfo) => device.id === deviceIdToUpdate);
      
      expect(updatedDevice?.isOnline).toBe(true);
      // Check if the device is now in the onlineDevices list
      expect(state.onlineDevices.some((device: DeviceInfo) => device.id === deviceIdToUpdate)).toBe(true);
      
      // Verify service method was called
      expect(mockDeviceService.updateDeviceOnlineStatus).toHaveBeenCalledWith(deviceIdToUpdate, true);
    });

    it('should update multiple devices\' status correctly', async () => {
      // First initialize to set devices
      await deviceStore.getState().initialize();
      
      // Update multiple devices
      deviceStore.getState().updateDeviceStatus('device-1', false); // Make online device offline
      deviceStore.getState().updateDeviceStatus('device-2', true); // Make offline device online
      
      // Verify state was updated correctly
      const state = deviceStore.getState();
      
      const device1 = state.devices.find((device: DeviceInfo) => device.id === 'device-1');
      const device2 = state.devices.find((device: DeviceInfo) => device.id === 'device-2');
      
      expect(device1?.isOnline).toBe(false);
      expect(device2?.isOnline).toBe(true);
      
      // Check onlineDevices list - should have current device and device-2
      expect(state.onlineDevices.length).toBe(2);
      expect(state.onlineDevices.some((device: DeviceInfo) => device.id === 'device-1')).toBe(false);
      expect(state.onlineDevices.some((device: DeviceInfo) => device.id === 'device-2')).toBe(true);
    });

    it('should handle updates for non-existent devices', () => {
      // This shouldn't throw, but also shouldn't change state
      const nonExistentDeviceId = 'non-existent-device';
      
      // Call the method
      deviceStore.getState().updateDeviceStatus(nonExistentDeviceId, true);
      
      // Verify service method was still called
      expect(mockDeviceService.updateDeviceOnlineStatus).toHaveBeenCalledWith(nonExistentDeviceId, true);
    });
  });

  describe('clearError', () => {
    it('should clear any existing error', () => {
      // Set an error state
      const errorMessage = 'Test error';
      deviceStore.setState({ error: errorMessage });
      
      // Call the method
      deviceStore.getState().clearError();
      
      // Verify error was cleared
      const state = deviceStore.getState();
      expect(state.error).toBeNull();
    });
  });
});
```

## 导航与引用

- [API测试设计文档索引](../api-testing-design-index.md)
- [认证Store API](auth-store-api.md)
- [卡片管理Store API](card-store-api.md)
- [同步管理Store API](sync-store-api.md)
- [系统测试计划](../testing/system-testing-plan.md)
- [回归测试计划](../testing/regression-testing-plan.md)
- [用户界面测试](../testing/ui-testing.md)
- [测试工具与技术](../testing/testing-tools.md)
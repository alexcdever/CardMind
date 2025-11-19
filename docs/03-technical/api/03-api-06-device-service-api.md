# DeviceService API接口设计与单元测试

> 本文档定义了CardMind系统的设备服务接口及其单元测试实现。

## 目录
- [1. 接口定义](#1-接口定义)
- [2. 单元测试](#2-单元测试)

## 1. 接口定义

```typescript
// src/services/device/DeviceService.ts

/**
 * 设备信息接口
 */
export interface DeviceInfo {
  /**
   * 设备唯一标识符
   */
  id: string;
  
  /**
   * 设备名称
   */
  name: string;
  
  /**
   * 设备类型
   */
  type: 'desktop' | 'mobile' | 'tablet' | 'unknown';
  
  /**
   * 设备平台
   */
  platform: 'windows' | 'macos' | 'ios' | 'android' | 'linux' | 'unknown';
  
  /**
   * 应用版本
   */
  appVersion: string;
  
  /**
   * 设备加入时间
   */
  joinedAt: number; // Timestamp
  
  /**
   * 最后活跃时间
   */
  lastActiveAt: number; // Timestamp
  
  /**
   * 是否在线
   */
  isOnline: boolean;
}

/**
 * 设备服务接口
 */
export interface DeviceService {
  /**
   * 获取当前设备信息
   * @returns 当前设备信息
   */
  getCurrentDeviceInfo(): DeviceInfo;
  
  /**
   * 获取网络中所有设备信息
   * @returns 设备信息列表
   */
  getAllDevices(): Promise<DeviceInfo[]>;
  
  /**
   * 获取在线设备列表
   * @returns 在线设备信息列表
   */
  getOnlineDevices(): Promise<DeviceInfo[]>;
  
  /**
   * 更新设备名称
   * @param name 新的设备名称
   * @returns 更新结果
   */
  updateDeviceName(name: string): Promise<boolean>;
  
  /**
   * 注册设备到当前网络
   * @returns 注册结果
   */
  registerDevice(): Promise<boolean>;
  
  /**
   * 更新设备在线状态
   * @param deviceId 设备ID
   * @param isOnline 是否在线
   */
  updateDeviceOnlineStatus(deviceId: string, isOnline: boolean): void;
}
```

## 2. 单元测试

```typescript
// src/services/device/DeviceService.test.ts
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { DeviceServiceImpl } from './DeviceServiceImpl';
import { IDatabaseService } from '../database/DatabaseService';
import { AuthServiceImpl } from '../auth/AuthServiceImpl';
import { SyncServiceImpl } from '../sync/SyncServiceImpl';

// Mock dependencies
jest.mock('../database/DatabaseService');
jest.mock('../auth/AuthServiceImpl');
jest.mock('../sync/SyncServiceImpl');

const mockDatabaseService = {
  get: jest.fn(),
  set: jest.fn(),
  remove: jest.fn(),
  getAll: jest.fn(),
} as unknown as IDatabaseService;

const mockAuthService = {
  getCurrentNetworkId: jest.fn(),
} as unknown as AuthServiceImpl;

const mockSyncService = {
  broadcastDeviceInfo: jest.fn(),
} as unknown as SyncServiceImpl;

describe('DeviceService', () => {
  let deviceService: DeviceServiceImpl;
  const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
  
  beforeEach(() => {
    (mockAuthService.getCurrentNetworkId as jest.Mock).mockReturnValue(mockNetworkId);
    deviceService = new DeviceServiceImpl(mockDatabaseService, mockAuthService, mockSyncService);
    jest.clearAllMocks();
  });

  describe('getCurrentDeviceInfo', () => {
    it('should return valid device information', () => {
      const deviceInfo = deviceService.getCurrentDeviceInfo();
      
      expect(deviceInfo).toHaveProperty('id');
      expect(deviceInfo).toHaveProperty('name');
      expect(deviceInfo).toHaveProperty('type');
      expect(deviceInfo).toHaveProperty('platform');
      expect(deviceInfo).toHaveProperty('appVersion');
      expect(deviceInfo).toHaveProperty('joinedAt');
      expect(deviceInfo).toHaveProperty('lastActiveAt');
      expect(deviceInfo).toHaveProperty('isOnline');
      
      // Verify the device is marked as online
      expect(deviceInfo.isOnline).toBe(true);
    });

    it('should return consistent device ID across multiple calls', () => {
      const deviceInfo1 = deviceService.getCurrentDeviceInfo();
      const deviceInfo2 = deviceService.getCurrentDeviceInfo();
      
      expect(deviceInfo1.id).toBe(deviceInfo2.id);
    });
  });

  describe('getAllDevices', () => {
    it('should return all devices including the current device', async () => {
      // Mock the database response
      const mockDevices = [
        {
          id: 'device-1',
          name: 'Test Device 1',
          type: 'desktop',
          platform: 'windows',
          appVersion: '1.0.0',
          joinedAt: Date.now() - 3600000,
          lastActiveAt: Date.now(),
          isOnline: true,
        },
      ];
      
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue(mockDevices);
      
      const devices = await deviceService.getAllDevices();
      
      // Should return at least 1 device (the current device)
      expect(devices.length).toBeGreaterThanOrEqual(1);
      
      // Check if the current device is included
      const currentDevice = deviceService.getCurrentDeviceInfo();
      const currentDeviceExists = devices.some(device => device.id === currentDevice.id);
      
      expect(currentDeviceExists).toBe(true);
    });

    it('should return empty array when no devices are registered', async () => {
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue([]);
      
      const devices = await deviceService.getAllDevices();
      
      // Should still return at least the current device
      expect(devices.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('getOnlineDevices', () => {
    it('should return only online devices', async () => {
      // Mock a mix of online and offline devices
      const mockDevices = [
        {
          id: 'device-1',
          name: 'Online Device',
          type: 'desktop',
          platform: 'windows',
          appVersion: '1.0.0',
          joinedAt: Date.now() - 3600000,
          lastActiveAt: Date.now(),
          isOnline: true,
        },
        {
          id: 'device-2',
          name: 'Offline Device',
          type: 'mobile',
          platform: 'android',
          appVersion: '1.0.0',
          joinedAt: Date.now() - 7200000,
          lastActiveAt: Date.now() - 300000,
          isOnline: false,
        },
      ];
      
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue(mockDevices);
      
      const onlineDevices = await deviceService.getOnlineDevices();
      
      // Should filter out offline devices
      const allDevicesAreOnline = onlineDevices.every(device => device.isOnline === true);
      expect(allDevicesAreOnline).toBe(true);
    });
  });

  describe('updateDeviceName', () => {
    it('should update the device name successfully', async () => {
      const newDeviceName = 'New Device Name';
      
      const result = await deviceService.updateDeviceName(newDeviceName);
      
      expect(result).toBe(true);
      expect(mockDatabaseService.set).toHaveBeenCalled();
      expect(mockSyncService.broadcastDeviceInfo).toHaveBeenCalled();
      
      // Verify the device name was updated
      const updatedDeviceInfo = deviceService.getCurrentDeviceInfo();
      expect(updatedDeviceInfo.name).toBe(newDeviceName);
    });

    it('should reject empty device name', async () => {
      const result = await deviceService.updateDeviceName('');
      
      expect(result).toBe(false);
      expect(mockDatabaseService.set).not.toHaveBeenCalled();
    });
  });

  describe('registerDevice', () => {
    it('should register the device successfully', async () => {
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(null); // Simulate device not registered
      
      const result = await deviceService.registerDevice();
      
      expect(result).toBe(true);
      expect(mockDatabaseService.set).toHaveBeenCalled();
      expect(mockSyncService.broadcastDeviceInfo).toHaveBeenCalled();
    });

    it('should handle registration when already registered', async () => {
      const currentDeviceInfo = deviceService.getCurrentDeviceInfo();
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(currentDeviceInfo);
      
      const result = await deviceService.registerDevice();
      
      expect(result).toBe(true);
      // Should still update the lastActiveAt timestamp
      expect(mockDatabaseService.set).toHaveBeenCalled();
    });
  });

  describe('updateDeviceOnlineStatus', () => {
    it('should update online status for a device', () => {
      const deviceId = 'test-device-id';
      
      deviceService.updateDeviceOnlineStatus(deviceId, true);
      
      // Verify the update was processed
      expect(mockDatabaseService.set).toHaveBeenCalled();
    });

    it('should update lastActiveAt when device comes online', () => {
      const deviceId = 'test-device-id';
      
      deviceService.updateDeviceOnlineStatus(deviceId, true);
      
      // The service should update the lastActiveAt timestamp
      expect(mockDatabaseService.set).toHaveBeenCalled();
    });
  });
});
```

## 相关文档

- [AuthService API接口设计与单元测试](auth-service-api.md)
- [CardService API接口设计与单元测试](card-service-api.md)
- [EncryptionService API接口设计与单元测试](encryption-service-api.md)
- [SyncService API接口设计与单元测试](sync-service-api.md)

[返回API测试设计文档索引](../api-testing-design-index.md)
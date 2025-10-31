/**
 * 设备管理服务测试
 */

import deviceService, { DeviceInfo } from '../../src/services/deviceService';
import * as localStorageService from '../../src/services/localStorageService';

// 模拟本地存储服务
jest.mock('../../src/services/localStorageService', () => ({
  getDeviceData: jest.fn(),
  saveDeviceData: jest.fn()
}));

const mockLocalStorageService = localStorageService as jest.Mocked<typeof localStorageService>;

// 模拟uuid
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-device-id')
}));

describe('DeviceService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // 重置设备服务实例
    (deviceService as any).currentDevice = null;
  });

  describe('initializeDevice', () => {
    it('应该成功初始化设备', async () => {
      mockLocalStorageService.getDeviceData.mockReturnValue(null);
      mockLocalStorageService.saveDeviceData.mockImplementation(() => {});

      const result = await deviceService.initializeDevice();

      expect(result).toBeDefined();
      expect(result.id).toBe('mocked-device-id');
      expect(result.deviceType).toBeDefined();
      expect(result.nickname).toBeDefined();
      expect(result.lastSeen).toBeDefined();
      expect(mockLocalStorageService.getDeviceData).toHaveBeenCalledTimes(1);
      expect(mockLocalStorageService.saveDeviceData).toHaveBeenCalledTimes(1);
    });

    it('当本地存储存在设备数据时应该返回现有数据', async () => {
      const existingDevice: DeviceInfo = {
        id: 'existing-id',
        nickname: '现有设备',
        deviceType: 'desktop',
        lastSeen: Date.now()
      };

      mockLocalStorageService.getDeviceData.mockReturnValue(existingDevice);

      const result = await deviceService.initializeDevice();

      expect(result).toEqual(existingDevice);
      expect(result.id).toBe('existing-id');
      expect(mockLocalStorageService.getDeviceData).toHaveBeenCalledTimes(1);
      expect(mockLocalStorageService.saveDeviceData).not.toHaveBeenCalled();
    });

    it('当初始化失败时应该抛出错误', async () => {
      mockLocalStorageService.getDeviceData.mockImplementation(() => {
        throw new Error('存储错误');
      });

      await expect(deviceService.initializeDevice()).rejects.toThrow('初始化设备失败');
    });
  });

  describe('getDeviceInfo', () => {
    it('应该返回当前设备信息', async () => {
      const mockDevice: DeviceInfo = {
        id: 'test-id',
        nickname: '测试设备',
        deviceType: 'desktop',
        lastSeen: Date.now()
      };

      mockLocalStorageService.getDeviceData.mockReturnValue(mockDevice);
      await deviceService.initializeDevice();

      const result = deviceService.getDeviceInfo();

      expect(result).toEqual(mockDevice);
    });

    it('当设备未初始化时应该抛出错误', () => {
      expect(() => {
        deviceService.getDeviceInfo();
      }).toThrow('设备未初始化');
    });
  });

  describe('updateNickname', () => {
    it('应该成功更新设备昵称', async () => {
      const mockDevice: DeviceInfo = {
        id: 'test-id',
        nickname: '原始昵称',
        deviceType: 'desktop',
        lastSeen: Date.now()
      };

      mockLocalStorageService.getDeviceData.mockReturnValue(mockDevice);
      mockLocalStorageService.saveDeviceData.mockImplementation(() => {});
      await deviceService.initializeDevice();

      deviceService.updateNickname('新昵称');

      const result = deviceService.getDeviceInfo();
      expect(result.nickname).toBe('新昵称');
      expect(mockLocalStorageService.saveDeviceData).toHaveBeenCalledTimes(1); // 更新1次
    });

    it('当设备未初始化时应该抛出错误', () => {
      expect(() => {
        deviceService.updateNickname('新昵称');
      }).toThrow('设备未初始化');
    });
  });

  describe('updateLastSeen', () => {
    it('应该更新最后在线时间', async () => {
      const mockDevice: DeviceInfo = {
        id: 'test-id',
        nickname: '测试设备',
        deviceType: 'desktop',
        lastSeen: Date.now() - 1000
      };

      mockLocalStorageService.getDeviceData.mockReturnValue(mockDevice);
      mockLocalStorageService.saveDeviceData.mockImplementation(() => {});
      await deviceService.initializeDevice();

      const beforeUpdate = deviceService.getDeviceInfo().lastSeen;
      
      // 等待一小段时间
      await new Promise(resolve => setTimeout(resolve, 10));
      
      deviceService.updateLastSeen();

      const result = deviceService.getDeviceInfo();
      expect(result.lastSeen).toBeGreaterThan(beforeUpdate);
      expect(mockLocalStorageService.saveDeviceData).toHaveBeenCalledTimes(1);
    });

    it('当设备未初始化时应该抛出错误', () => {
      expect(() => {
        deviceService.updateLastSeen();
      }).toThrow('设备未初始化');
    });
  });

  describe('getDeviceType', () => {
    it('应该正确检测移动设备', () => {
      // 模拟移动设备User Agent
      Object.defineProperty(navigator, 'userAgent', {
        value: 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)',
        configurable: true
      });

      const result = deviceService.getDeviceType();

      expect(result).toBe('mobile');
    });

    it('应该正确检测桌面设备', () => {
      // 模拟桌面设备User Agent
      Object.defineProperty(navigator, 'userAgent', {
        value: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        configurable: true
      });

      const result = deviceService.getDeviceType();

      expect(result).toBe('desktop');
    });

    it('当无法检测设备类型时应该返回unknown', () => {
      // 模拟无法识别的User Agent
      Object.defineProperty(navigator, 'userAgent', {
        value: 'Unknown User Agent',
        configurable: true
      });

      const result = deviceService.getDeviceType();

      expect(result).toBe('unknown');
    });
  });

  describe('getOnlineDevices', () => {
    it('应该返回空数组（需要与syncService集成）', () => {
      const result = deviceService.getOnlineDevices();

      expect(result).toEqual([]);
    });
  });

  describe('updateOnlineDevices', () => {
    it('应该记录设备列表更新（需要与syncService集成）', () => {
      const mockDevices: DeviceInfo[] = [
        {
          id: 'device1',
          nickname: '设备1',
          deviceType: 'mobile',
          lastSeen: Date.now()
        },
        {
          id: 'device2',
          nickname: '设备2',
          deviceType: 'desktop',
          lastSeen: Date.now()
        }
      ];

      // 模拟console.log以验证调用
      const consoleSpy = jest.spyOn(console, 'log');

      deviceService.updateOnlineDevices(mockDevices);

      expect(consoleSpy).toHaveBeenCalledWith('更新在线设备列表:', mockDevices);
      consoleSpy.mockRestore();
    });
  });

  describe('isDeviceOnline', () => {
    it('应该返回正确的在线状态', () => {
      // 模拟在线状态
      Object.defineProperty(navigator, 'onLine', {
        value: true,
        configurable: true
      });

      const result = deviceService.isDeviceOnline();

      expect(result).toBe(true);
    });

    it('应该返回正确的离线状态', () => {
      // 模拟离线状态
      Object.defineProperty(navigator, 'onLine', {
        value: false,
        configurable: true
      });

      const result = deviceService.isDeviceOnline();

      expect(result).toBe(false);
    });
  });
});
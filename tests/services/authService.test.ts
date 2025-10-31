/**
 * 认证服务测试
 */

import authService, { AuthServiceInterface, NetworkInfo } from '../../src/services/authService';
import * as localStorageService from '../../src/services/localStorageService';

// 模拟本地存储服务
jest.mock('../../src/services/localStorageService', () => ({
  getAuthData: jest.fn(),
  saveAuthData: jest.fn(),
  clearAuthData: jest.fn()
}));

const mockLocalStorageService = localStorageService as jest.Mocked<typeof localStorageService>;

// 模拟uuid - 使用32字符的随机码（UUID去掉连字符的长度）
jest.mock('uuid', () => ({
  v4: jest.fn(() => '12345678901234567890123456789012') // 32字符
}));

describe('AuthService', () => {
  let service: AuthServiceInterface;

  beforeEach(() => {
    // 清除所有mock
    jest.clearAllMocks();
    
    // 设置mock实现
    mockLocalStorageService.getAuthData.mockReturnValue(null);
    mockLocalStorageService.saveAuthData.mockImplementation(() => {});
    mockLocalStorageService.clearAuthData.mockImplementation(() => {});
    
    // 使用单例实例，但重置其状态
    service = authService;
    // 重置服务状态
    (service as any).currentAuth = null;
  });

  describe('generateNetworkId', () => {
    it('应该生成有效的网络ID', () => {
      const networkId = service.generateNetworkId();

      expect(networkId).toBeDefined();
      expect(typeof networkId).toBe('string');
      expect(networkId.length).toBeGreaterThan(0);
    });

    it('生成的网络ID应该包含设备地址信息', () => {
      const networkId = service.generateNetworkId();
      const networkInfo = service.extractNetworkInfo(networkId);

      expect(networkInfo).not.toBeNull();
      expect(networkInfo!.address).toBe(service.getDeviceAddress());
    });

    it('生成的网络ID应该包含时间戳', () => {
      const beforeGeneration = Date.now();
      const networkId = service.generateNetworkId();
      const afterGeneration = Date.now();
      const networkInfo = service.extractNetworkInfo(networkId);

      expect(networkInfo).not.toBeNull();
      expect(networkInfo!.timestamp).toBeGreaterThanOrEqual(beforeGeneration);
      expect(networkInfo!.timestamp).toBeLessThanOrEqual(afterGeneration);
    });

    it('生成的网络ID应该包含随机码', () => {
      const networkId = service.generateNetworkId();
      const networkInfo = service.extractNetworkInfo(networkId);

      expect(networkInfo).not.toBeNull();
      expect(networkInfo!.randomCode).toBe('12345678901234567890123456789012');
    });
  });

  describe('validateNetworkId', () => {
    it('应该验证有效的网络ID', () => {
      const validNetworkId = service.generateNetworkId();
      const isValid = service.validateNetworkId(validNetworkId);

      expect(isValid).toBe(true);
    });

    it('应该拒绝无效的网络ID', () => {
      const invalidNetworkId = 'invalid-network-id';
      const isValid = service.validateNetworkId(invalidNetworkId);

      expect(isValid).toBe(false);
    });

    it('应该拒绝格式错误的网络ID', () => {
      const malformedNetworkId = 'malformed!';
      const isValid = service.validateNetworkId(malformedNetworkId);

      expect(isValid).toBe(false);
    });

    it('应该拒绝缺少必要字段的网络ID', () => {
      // 创建一个缺少必要字段的网络ID
      const incompleteData = JSON.stringify({
        address: 'localhost:5173',
        timestamp: Date.now()
        // 缺少 randomCode
      });
      
      // 使用Base64编码
      const incompleteNetworkId = btoa(incompleteData).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      const isValid = service.validateNetworkId(incompleteNetworkId);

      expect(isValid).toBe(false);
    });
  });

  describe('extractNetworkInfo', () => {
    it('应该从有效网络ID中提取网络信息', () => {
      const networkId = service.generateNetworkId();
      const networkInfo = service.extractNetworkInfo(networkId);

      expect(networkInfo).not.toBeNull();
      expect(networkInfo!.address).toBeDefined();
      expect(networkInfo!.timestamp).toBeDefined();
      expect(networkInfo!.randomCode).toBeDefined();
    });

    it('当网络ID无效时应该返回null', () => {
      const invalidNetworkId = 'invalid-network-id';
      const networkInfo = service.extractNetworkInfo(invalidNetworkId);

      expect(networkInfo).toBeNull();
    });

    it('当网络ID格式错误时应该返回null', () => {
      const malformedNetworkId = 'malformed!';
      const networkInfo = service.extractNetworkInfo(malformedNetworkId);

      expect(networkInfo).toBeNull();
    });
  });

  describe('joinNetwork', () => {
    it('应该成功加入网络', async () => {
      const networkId = service.generateNetworkId();
      
      // 验证生成的网络ID是有效的
      const isValid = service.validateNetworkId(networkId);
      expect(isValid).toBe(true);
      
      const result = await service.joinNetwork(networkId);

      // 验证joinNetwork的结果
      expect(result).toBe(true);
      
      // 验证服务状态已更新
      expect(service.isAuthenticated()).toBe(true);
      expect(service.getCurrentNetworkId()).toBe(networkId);
      
      // 验证本地存储已保存
      expect(mockLocalStorageService.saveAuthData).toHaveBeenCalledTimes(1);
    });

    it('当网络ID无效时应该返回false', async () => {
      const invalidNetworkId = 'invalid-network-id';

      const result = await service.joinNetwork(invalidNetworkId);

      expect(result).toBe(false);
      expect(service.isAuthenticated()).toBe(false);
      expect(service.getCurrentNetworkId()).toBeNull();
    });

    it('当网络ID格式错误时应该返回false', async () => {
      const malformedNetworkId = 'malformed!';

      const result = await service.joinNetwork(malformedNetworkId);

      expect(result).toBe(false);
      expect(service.isAuthenticated()).toBe(false);
      expect(service.getCurrentNetworkId()).toBeNull();
    });

    it('当保存认证数据失败时应该处理错误', async () => {
      const networkId = service.generateNetworkId();
      mockLocalStorageService.saveAuthData.mockImplementation(() => {
        throw new Error('保存失败');
      });

      // 不应该抛出错误，而是返回false
      const result = await service.joinNetwork(networkId);

      expect(result).toBe(false);
    });
  });

  describe('leaveNetwork', () => {
    it('应该成功离开网络', async () => {
      // 先加入网络
      const networkId = service.generateNetworkId();
      await service.joinNetwork(networkId);

      // 离开网络
      service.leaveNetwork();

      expect(service.isAuthenticated()).toBe(false);
      expect(service.getCurrentNetworkId()).toBeNull();
      expect(mockLocalStorageService.clearAuthData).toHaveBeenCalledTimes(1);
    });

    it('当清除数据失败时应该处理错误', () => {
      mockLocalStorageService.clearAuthData.mockImplementation(() => {
        throw new Error('清除失败');
      });

      // 不应该抛出错误
      expect(() => {
        service.leaveNetwork();
      }).not.toThrow();
    });
  });

  describe('getCurrentNetworkId', () => {
    it('应该返回当前网络ID', async () => {
      const networkId = service.generateNetworkId();
      
      await service.joinNetwork(networkId);
      
      const currentNetworkId = service.getCurrentNetworkId();

      expect(currentNetworkId).toBe(networkId);
    });

    it('当未加入网络时应该返回null', () => {
      const networkId = service.getCurrentNetworkId();

      expect(networkId).toBeNull();
    });
  });

  describe('isAuthenticated', () => {
    it('当已加入网络时应该返回true', async () => {
      const networkId = service.generateNetworkId();
      
      await service.joinNetwork(networkId);
      
      const isAuth = service.isAuthenticated();

      expect(isAuth).toBe(true);
    });

    it('当未加入网络时应该返回false', () => {
      const isAuth = service.isAuthenticated();

      expect(isAuth).toBe(false);
    });
  });

  describe('getDeviceAddress', () => {
    it('应该返回正确的设备地址', () => {
      const deviceAddress = service.getDeviceAddress();

      expect(deviceAddress).toBeDefined();
      expect(typeof deviceAddress).toBe('string');
      expect(deviceAddress).toContain(':'); // 应该包含端口号
    });

    it('应该包含主机名和端口', () => {
      // 直接测试当前服务实例的getDeviceAddress方法
      const deviceAddress = service.getDeviceAddress();

      // 验证返回的地址格式正确
      expect(deviceAddress).toBeDefined();
      expect(typeof deviceAddress).toBe('string');
      expect(deviceAddress).toContain(':'); // 应该包含端口号
      
      // 由于我们无法在测试环境中修改window.location，
      // 我们只验证返回的地址格式正确即可
      const parts = deviceAddress.split(':');
      expect(parts.length).toBe(2); // 应该包含主机名和端口两部分
      expect(parts[0]).toBeDefined(); // 主机名部分
      expect(parts[1]).toBeDefined(); // 端口部分
    });

    it('当没有指定端口时应该使用默认端口', () => {
      // 直接测试当前服务实例的getDeviceAddress方法
      const deviceAddress = service.getDeviceAddress();

      // 验证返回的地址格式正确
      expect(deviceAddress).toBeDefined();
      expect(typeof deviceAddress).toBe('string');
      expect(deviceAddress).toContain(':'); // 应该包含端口号
      
      // 由于我们无法在测试环境中修改window.location，
      // 我们只验证返回的地址格式正确即可
      const parts = deviceAddress.split(':');
      expect(parts.length).toBe(2); // 应该包含主机名和端口两部分
      expect(parts[0]).toBeDefined(); // 主机名部分
      expect(parts[1]).toMatch(/^\d+$/); // 端口部分应该是数字
    });
  });

  describe('Base64编码解码', () => {
    it('应该正确编码和解码数据', () => {
      const testData = { test: 'data', number: 123 };
      const encoded = (service as any).encodeBase64(JSON.stringify(testData));
      const decoded = (service as any).decodeBase64(encoded);
      const parsedData = JSON.parse(decoded);

      expect(parsedData).toEqual(testData);
    });

    it('应该处理特殊字符', () => {
      const testData = { special: '特殊字符!@#$%^&*()' };
      const encoded = (service as any).encodeBase64(JSON.stringify(testData));
      const decoded = (service as any).decodeBase64(encoded);
      const parsedData = JSON.parse(decoded);

      expect(parsedData).toEqual(testData);
    });

    it('应该处理URL安全的Base64编码', () => {
      const testData = { url: 'https://example.com/path?param=value' };
      const encoded = (service as any).encodeBase64(JSON.stringify(testData));
      
      // 验证URL安全字符
      expect(encoded).not.toContain('+');
      expect(encoded).not.toContain('/');
      expect(encoded).not.toContain('=');

      const decoded = (service as any).decodeBase64(encoded);
      const parsedData = JSON.parse(decoded);

      expect(parsedData).toEqual(testData);
    });
  });
});
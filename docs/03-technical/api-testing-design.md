# CardMind API与测试计划

## 1. 概述

本文档详细描述了CardMind应用的API设计与测试计划，包括各种服务的接口定义、单元测试、集成测试、端到端测试以及回归测试策略。文档旨在为开发团队提供完整的测试指导，确保应用质量和稳定性。

本文档主要包含以下内容：
- API设计与单元测试
- 集成测试策略
- 端到端测试方案
- 回归测试计划
- 测试工具与技术

## 2. API设计与单元测试

### 2.1 AuthService API

#### 2.1.1 接口定义
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
  
  /**
   * 生成Access Code
   * @param networkId 网络ID
   * @returns Access Code
   */
  generateAccessCode(networkId: string): Promise<string>;
  
  /**
   * 解析Access Code
   * @param accessCode Access Code
   * @returns 解析后的数据
   */
  parseAccessCode(accessCode: string): Promise<AccessCodeData>;
  
  /**
   * 验证Access Code有效性
   * @param accessCode Access Code
   * @returns 是否有效
   */
  validateAccessCode(accessCode: string): Promise<boolean>;
}

interface AccessCodeData {
  networkId: string;
  createdAt: number;
  expiresAt: number;
}

/**
 * 集成测试示例
 */
describe('Network Integration', () => {
  it('should create and join network', async () => {
    // 创建网络
    const networkId = await authService.generateNetworkId()
    await authService.joinNetwork(networkId)
    
    // 模拟另一个设备加入
    const deviceService2 = new DeviceService()
    await deviceService2.joinNetwork(networkId)
    
    // 验证网络状态
    expect(authService.getCurrentNetworkId()).toBe(networkId)
    expect(deviceService2.getCurrentNetworkId()).toBe(networkId)
  })
})

describe('Access Code Integration', () => {
  it('should generate and use Access Code for network joining', async () => {
    // 创建网络并生成Access Code
    const networkId = await authService.generateNetworkId()
    await authService.joinNetwork(networkId)
    const accessCode = await authService.generateAccessCode(networkId)
    
    // 解析Access Code获取网络信息
    const accessData = await authService.parseAccessCode(accessCode)
    expect(accessData.networkId).toBe(networkId)
    
    // 模拟新设备使用Access Code加入
    const authService2 = new AuthService()
    const isValid = await authService2.validateAccessCode(accessCode)
    expect(isValid).toBe(true)
    
    await authService2.joinNetwork(accessData.networkId)
    expect(authService2.getCurrentNetworkId()).toBe(networkId)
  })

  it('should handle Access Code copy and paste flow', async () => {
    // 生成Access Code
    const networkId = await authService.generateNetworkId()
    const accessCode = await authService.generateAccessCode(networkId)
    
    // 模拟复制到剪贴板
    await navigator.clipboard.writeText(accessCode)
    
    // 模拟粘贴和验证
    const pastedCode = await navigator.clipboard.readText()
    expect(pastedCode).toBe(accessCode)
    
    const isValid = await authService.validateAccessCode(pastedCode)
    expect(isValid).toBe(true)
  })
})
```

#### 2.1.2 单元测试
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

  test('should generate valid Access Code', async () => {
    const networkId = '123e4567-e89b-12d3-a456-426614174000';
    const accessCode = await authService.generateAccessCode(networkId);
    expect(accessCode).toBeTruthy();
    expect(typeof accessCode).toBe('string');
    expect(accessCode.length).toBeGreaterThan(50);
  });

  test('should parse Access Code correctly', async () => {
    const networkId = '123e4567-e89b-12d3-a456-426614174000';
    const accessCode = await authService.generateAccessCode(networkId);
    const data = await authService.parseAccessCode(accessCode);
    expect(data.networkId).toBe(networkId);
    expect(data.createdAt).toBeGreaterThan(Date.now() - 60000);
    expect(data.expiresAt).toBeGreaterThan(Date.now());
  });

  test('should validate valid Access Code', async () => {
    const networkId = '123e4567-e89b-12d3-a456-426614174000';
    const accessCode = await authService.generateAccessCode(networkId);
    const isValid = await authService.validateAccessCode(accessCode);
    expect(isValid).toBe(true);
  });

  test('should reject invalid Access Code', async () => {
    const isValid = await authService.validateAccessCode('invalid_code');
    expect(isValid).toBe(false);
  });

  test('should handle old Access Code with graceful warning', async () => {
    const networkId = '123e4567-e89b-12d3-a456-426614174000';
    const accessCode = await authService.generateAccessCode(networkId);
    jest.spyOn(Date, 'now').mockReturnValue(Date.now() + 7200000);
    const result = await authService.validateAccessCode(accessCode);
    // 过期Access Code应给出警告但仍可使用，体现家庭场景友好性
    expect(result.isValid).toBe(true);
    expect(result.isStale).toBe(true);
    (Date.now as jest.Mock).mockRestore();
  });
});
```

### 2.2 DeviceService API

#### 2.2.1 接口定义
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

#### 2.2.2 单元测试
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

### 2.3 CardService API

详细的CardService API文档请参考：[CardService API接口设计与单元测试](./card-service-api.md)

### 2.4 EncryptionService API

详细的EncryptionService API文档请参考：[EncryptionService API接口设计与单元测试](./encryption-service-api.md)

### 2.5 SyncService API

详细的SyncService API文档请参考：[SyncService API接口定义与单元测试](./sync-service-api.md)

## 3. 状态管理Store API

状态管理Store API的详细设计与测试文档已拆分到以下独立文件中：

- [认证Store API](api/auth-store-api.md) - 认证状态管理接口与测试
- [设备Store API](api/device-store-api.md) - 设备管理状态接口与测试
- [卡片Store API](api/card-store-api.md) - 卡片数据状态接口与测试
- [同步Store API](api/sync-store-api.md) - 同步状态管理接口与测试

## 4. 系统测试计划

系统测试计划已拆分为独立文档，详细内容请参考：

- [系统测试计划](./testing/system-testing-plan.md)

## 5. 回归测试计划

回归测试计划已拆分为独立文档，详细内容请参考：

- [回归测试计划](./testing/regression-testing-plan.md)

## 6. 测试工具与技术

### 6.1 推荐工具

- **Jest**：JavaScript测试框架，用于单元测试和集成测试
- **Testing Library**：React组件测试工具
- **Playwright**：端到端测试工具，支持多种浏览器
- **Dexie.js Mock**：IndexedDB测试模拟库
- **Yjs测试工具**：Yjs同步测试工具
- **GitHub Actions**：持续集成与测试自动化

### 6.2 测试覆盖率要求

- 单元测试覆盖率：>80%
- 关键业务逻辑覆盖率：>90%
- 核心API覆盖率：100%
- 测试报告：每次构建自动生成覆盖率报告

### 6.3 测试最佳实践

- **隔离测试**：每个测试独立运行，不依赖外部状态
- **模拟依赖**：使用mock替代外部依赖
- **测试数据管理**：每个测试前准备干净的测试数据
- **断言明确**：使用清晰的断言描述预期行为
- **测试命名规范**：使用描述性的测试名称
- **持续测试**：开发过程中持续运行测试
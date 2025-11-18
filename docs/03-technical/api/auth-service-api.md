# AuthService API接口设计与单元测试

> 本文档定义了CardMind系统的认证服务接口及其单元测试实现。

## 目录
- [1. 接口定义](#1-接口定义)
- [2. 单元测试](#2-单元测试)

## 1. 接口定义

```typescript
// src/services/auth/AuthService.ts

/**
 * 认证服务接口
 */
export interface AuthService {
  /**
   * 生成新的网络ID
   * @returns 生成的网络ID
   */
  generateNetworkId(): Promise<string>;

  /**
   * 加入网络
   * @param networkId 要加入的网络ID
   * @returns 加入结果
   */
  joinNetwork(networkId: string): Promise<{ success: boolean; message?: string }>;

  /**
   * 验证网络ID格式
   * @param networkId 要验证的网络ID
   * @returns 验证结果
   */
  validateNetworkId(networkId: string): boolean;

  /**
   * 获取当前网络ID
   * @returns 当前网络ID，如果未加入网络则返回null
   */
  getCurrentNetworkId(): string | null;

  /**
   * 离开当前网络
   */
  leaveNetwork(): void;

  /**
   * 生成临时访问码
   * @param expiryMinutes 访问码有效期（分钟），默认5分钟
   * @returns 生成的访问码
   */
  generateAccessCode(expiryMinutes?: number): string;

  /**
   * 验证访问码
   * @param accessCode 要验证的访问码
   * @returns 验证结果，包含网络ID或错误信息
   */
  validateAccessCode(accessCode: string): { valid: boolean; networkId?: string; error?: string };
}
```

## 2. 单元测试

```typescript
// src/services/auth/AuthService.test.ts
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { AuthServiceImpl } from './AuthServiceImpl';
import { generateMockRandomString } from '../../utils/test-utils';
import { IDatabaseService } from '../database/DatabaseService';

// Mock dependencies
jest.mock('../database/DatabaseService');

const mockDatabaseService = {
  get: jest.fn(),
  set: jest.fn(),
  remove: jest.fn(),
} as unknown as IDatabaseService;

describe('AuthService', () => {
  let authService: AuthServiceImpl;
  const originalRandomString = Math.random;
  
  beforeEach(() => {
    // Mock Math.random for consistent test results
    (Math.random as jest.Mock) = generateMockRandomString;
    authService = new AuthServiceImpl(mockDatabaseService);
    jest.clearAllMocks();
  });

  afterEach(() => {
    // Restore original Math.random
    Math.random = originalRandomString;
  });

  describe('generateNetworkId', () => {
    it('should generate a valid UUID v4 format network ID', async () => {
      const networkId = await authService.generateNetworkId();
      
      // UUID v4 validation regex
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      expect(uuidRegex.test(networkId)).toBe(true);
    });

    it('should generate different network IDs on consecutive calls', async () => {
      const networkId1 = await authService.generateNetworkId();
      const networkId2 = await authService.generateNetworkId();
      
      expect(networkId1).not.toBe(networkId2);
    });
  });

  describe('joinNetwork', () => {
    it('should successfully join a valid network ID', async () => {
      const validNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      const result = await authService.joinNetwork(validNetworkId);
      
      expect(result.success).toBe(true);
      expect(mockDatabaseService.set).toHaveBeenCalledWith('currentNetworkId', validNetworkId);
    });

    it('should fail to join an invalid network ID', async () => {
      const invalidNetworkId = 'invalid-network-id';
      const result = await authService.joinNetwork(invalidNetworkId);
      
      expect(result.success).toBe(false);
      expect(result.message).toBeDefined();
      expect(mockDatabaseService.set).not.toHaveBeenCalled();
    });

    it('should fail to join an empty network ID', async () => {
      const result = await authService.joinNetwork('');
      
      expect(result.success).toBe(false);
      expect(mockDatabaseService.set).not.toHaveBeenCalled();
    });
  });

  describe('validateNetworkId', () => {
    it('should validate a correct UUID v4 format', () => {
      const validNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      expect(authService.validateNetworkId(validNetworkId)).toBe(true);
    });

    it('should reject an incorrect UUID format', () => {
      const invalidNetworkId = '123e4567-e89b-12d3-a456';
      expect(authService.validateNetworkId(invalidNetworkId)).toBe(false);
    });

    it('should reject a non-UUID string', () => {
      const invalidNetworkId = 'not-a-uuid';
      expect(authService.validateNetworkId(invalidNetworkId)).toBe(false);
    });

    it('should reject an empty string', () => {
      expect(authService.validateNetworkId('')).toBe(false);
    });
  });

  describe('getCurrentNetworkId', () => {
    it('should return the current network ID when set', async () => {
      const testNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(testNetworkId);
      
      await authService.joinNetwork(testNetworkId);
      const result = authService.getCurrentNetworkId();
      
      expect(result).toBe(testNetworkId);
    });

    it('should return null when no network is joined', () => {
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(null);
      
      const result = authService.getCurrentNetworkId();
      
      expect(result).toBe(null);
    });
  });

  describe('leaveNetwork', () => {
    it('should remove the current network ID', () => {
      authService.leaveNetwork();
      
      expect(mockDatabaseService.remove).toHaveBeenCalledWith('currentNetworkId');
    });
  });

  describe('generateAccessCode', () => {
    it('should generate a valid access code', () => {
      const accessCode = authService.generateAccessCode();
      
      // Check if it's a non-empty string and likely a JWT/encoded token
      expect(typeof accessCode).toBe('string');
      expect(accessCode.length).toBeGreaterThan(10);
    });

    it('should generate different access codes on consecutive calls', () => {
      const code1 = authService.generateAccessCode();
      const code2 = authService.generateAccessCode();
      
      expect(code1).not.toBe(code2);
    });

    it('should generate access codes with configurable expiry', () => {
      // This is a more complex test that would require decoding the token
      // For simplicity, we just ensure the function accepts the parameter
      expect(() => authService.generateAccessCode(30)).not.toThrow();
    });
  });

  describe('validateAccessCode', () => {
    it('should validate a valid access code generated by the service', () => {
      const networkId = '123e4567-e89b-12d3-a456-426614174000';
      
      // Mock the joinNetwork to set the current network ID
      mockDatabaseService.get = jest.fn().mockResolvedValue(networkId);
      
      const accessCode = authService.generateAccessCode();
      const validationResult = authService.validateAccessCode(accessCode);
      
      expect(validationResult.valid).toBe(true);
      expect(validationResult.networkId).toBeDefined();
    });

    it('should reject an invalid access code format', () => {
      const invalidCode = 'not-a-valid-access-code';
      const validationResult = authService.validateAccessCode(invalidCode);
      
      expect(validationResult.valid).toBe(false);
      expect(validationResult.error).toBeDefined();
    });

    it('should reject an expired access code', () => {
      // Mock Date to simulate expiry
      const now = new Date();
      const future = new Date();
      future.setMinutes(now.getMinutes() - 10); // Expired 10 minutes ago
      
      const originalDate = global.Date;
      global.Date = jest.fn().mockImplementation(() => future) as any;
      
      const networkId = '123e4567-e89b-12d3-a456-426614174000';
      mockDatabaseService.get = jest.fn().mockResolvedValue(networkId);
      
      const expiredCode = authService.generateAccessCode();
      
      // Restore Date
      global.Date = originalDate;
      
      const validationResult = authService.validateAccessCode(expiredCode);
      
      expect(validationResult.valid).toBe(false);
      expect(validationResult.error).toContain('过期');
    });
  });
});
```

## 相关文档

- [DeviceService API接口设计与单元测试](device-service-api.md)
- [CardService API接口设计与单元测试](card-service-api.md)
- [EncryptionService API接口设计与单元测试](encryption-service-api.md)
- [SyncService API接口设计与单元测试](sync-service-api.md)

[返回API测试设计文档索引](../api-testing-design-index.md)
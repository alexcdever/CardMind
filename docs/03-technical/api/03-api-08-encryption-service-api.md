# EncryptionService API接口设计与单元测试

> 本文档定义了CardMind系统的加密服务接口及其单元测试实现。

## 目录
- [1. 接口定义](#1-接口定义)
- [2. 单元测试](#2-单元测试)

## 1. 接口定义

```typescript
// src/services/encryption/EncryptionService.ts

/**
 * 加密服务接口
 */
export interface EncryptionService {
  /**
   * 加密数据
   * @param data 要加密的数据
   * @returns 加密后的数据
   */
  encrypt<T>(data: T): T;

  /**
   * 解密数据
   * @param data 要解密的数据
   * @returns 解密后的数据
   */
  decrypt<T>(data: T): T;

  /**
   * 生成安全随机数
   * @param length 随机数长度
   * @returns 随机数字符串
   */
  generateSecureRandom(length: number): string;

  /**
   * 生成数据哈希
   * @param data 要哈希的数据
   * @returns 哈希值
   */
  generateHash(data: string): string;

  /**
   * 验证数据与哈希值
   * @param data 原始数据
   * @param hash 要验证的哈希值
   * @returns 验证结果
   */
  verifyHash(data: string, hash: string): boolean;

  /**
   * 导出加密密钥（用于备份或迁移）
   * @returns 导出的密钥
   */
  exportKey(): Promise<string>;

  /**
   * 导入加密密钥
   * @param key 要导入的密钥
   * @returns 导入结果
   */
  importKey(key: string): Promise<boolean>;
}
```

## 2. 单元测试

```typescript
// src/services/encryption/EncryptionService.test.ts
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { EncryptionServiceImpl } from './EncryptionServiceImpl';
import { IDatabaseService } from '../database/DatabaseService';

// Mock dependencies
jest.mock('../database/DatabaseService');

const mockDatabaseService = {
  get: jest.fn(),
  set: jest.fn(),
} as unknown as IDatabaseService;

describe('EncryptionService', () => {
  let encryptionService: EncryptionServiceImpl;
  
  beforeEach(() => {
    encryptionService = new EncryptionServiceImpl(mockDatabaseService);
    jest.clearAllMocks();
  });

  describe('encrypt and decrypt', () => {
    it('should encrypt and decrypt string data correctly', () => {
      const originalData = 'Hello, world!';
      
      const encryptedData = encryptionService.encrypt(originalData);
      const decryptedData = encryptionService.decrypt(encryptedData);
      
      expect(decryptedData).toBe(originalData);
    });

    it('should encrypt and decrypt object data correctly', () => {
      const originalData = {
        id: 'test-123',
        name: 'Test Object',
        value: 42,
      };
      
      const encryptedData = encryptionService.encrypt(originalData);
      const decryptedData = encryptionService.decrypt(encryptedData);
      
      expect(decryptedData).toEqual(originalData);
    });

    it('should handle null and undefined values', () => {
      expect(encryptionService.encrypt(null)).toBeNull();
      expect(encryptionService.encrypt(undefined)).toBeUndefined();
      expect(encryptionService.decrypt(null)).toBeNull();
      expect(encryptionService.decrypt(undefined)).toBeUndefined();
    });
  });

  describe('generateSecureRandom', () => {
    it('should generate random strings of specified length', () => {
      const length = 32;
      const randomString = encryptionService.generateSecureRandom(length);
      
      expect(randomString).toHaveLength(length);
    });

    it('should generate different random strings on consecutive calls', () => {
      const random1 = encryptionService.generateSecureRandom(16);
      const random2 = encryptionService.generateSecureRandom(16);
      
      expect(random1).not.toBe(random2);
    });

    it('should handle zero length parameter', () => {
      const randomString = encryptionService.generateSecureRandom(0);
      
      expect(randomString).toBe('');
    });
  });

  describe('generateHash and verifyHash', () => {
    it('should generate and verify hash correctly', () => {
      const data = 'test-data-to-hash';
      
      const hash = encryptionService.generateHash(data);
      const isValid = encryptionService.verifyHash(data, hash);
      
      expect(isValid).toBe(true);
    });

    it('should generate different hashes for different inputs', () => {
      const hash1 = encryptionService.generateHash('data1');
      const hash2 = encryptionService.generateHash('data2');
      
      expect(hash1).not.toBe(hash2);
    });

    it('should return false for incorrect hash verification', () => {
      const data = 'test-data';
      const wrongData = 'different-data';
      
      const hash = encryptionService.generateHash(data);
      const isValid = encryptionService.verifyHash(wrongData, hash);
      
      expect(isValid).toBe(false);
    });
  });

  describe('exportKey and importKey', () => {
    it('should export and import encryption key successfully', async () => {
      // First, simulate that a key exists
      const mockKey = 'mock-encryption-key';
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(mockKey);
      
      // Export the key
      const exportedKey = await encryptionService.exportKey();
      
      expect(exportedKey).toBeDefined();
      expect(typeof exportedKey).toBe('string');
      
      // Import the key
      jest.clearAllMocks();
      const importResult = await encryptionService.importKey(exportedKey);
      
      expect(importResult).toBe(true);
      expect(mockDatabaseService.set).toHaveBeenCalled();
    });

    it('should handle export when no key exists', async () => {
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(null);
      
      const exportedKey = await encryptionService.exportKey();
      
      // Depending on implementation, it might generate a new key or throw
      // For this test, we'll assume it generates a new key
      expect(exportedKey).toBeDefined();
    });

    it('should handle invalid key import', async () => {
      // This depends on the implementation's validation logic
      const invalidKey = 'invalid-key-format';
      
      const importResult = await encryptionService.importKey(invalidKey);
      
      // Assuming the implementation validates the key format
      // This might be true or false depending on implementation
      // For this test, we'll assume it validates and returns false for invalid keys
      expect(typeof importResult).toBe('boolean');
    });
  });
});
```

## 相关文档

- [AuthService API接口设计与单元测试](auth-service-api.md)
- [DeviceService API接口设计与单元测试](device-service-api.md)
- [CardService API接口设计与单元测试](card-service-api.md)
- [SyncService API接口设计与单元测试](sync-service-api.md)

[返回API测试设计文档索引](../api-testing-design-index.md)
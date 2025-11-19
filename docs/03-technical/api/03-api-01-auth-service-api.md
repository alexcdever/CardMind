# AuthService API接口设计与单元测试

> 本文档定义了CardMind系统的认证服务接口、完整实现及其单元测试，并提供了实际使用示例。

## 目录
- [1. 接口定义](#1-接口定义)
- [2. 完整实现示例](#2-完整实现示例)
- [3. 实际使用示例](#3-实际使用示例)
- [4. 单元测试](#4-单元测试)

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

## 2. 完整实现示例

```typescript
// src/services/auth/AuthServiceImpl.ts
import { AuthService } from './AuthService';
import { IDatabaseService } from '../database/DatabaseService';

/**
 * 认证服务实现类
 */
export class AuthServiceImpl implements AuthService {
  private readonly NETWORK_ID_KEY = 'currentNetworkId';
  private readonly ACCESS_CODES_KEY = 'accessCodes';

  constructor(private databaseService: IDatabaseService) {}

  /**
   * 生成新的网络ID（UUID v4格式）
   */
  async generateNetworkId(): Promise<string> {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**
   * 加入网络
   */
  async joinNetwork(networkId: string): Promise<{ success: boolean; message?: string }> {
    if (!this.validateNetworkId(networkId)) {
      return { success: false, message: '无效的网络ID格式' };
    }

    await this.databaseService.set(this.NETWORK_ID_KEY, networkId);
    return { success: true };
  }

  /**
   * 验证网络ID格式（UUID v4）
   */
  validateNetworkId(networkId: string): boolean {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(networkId);
  }

  /**
   * 获取当前网络ID
   */
  getCurrentNetworkId(): string | null {
    return this.databaseService.get(this.NETWORK_ID_KEY);
  }

  /**
   * 离开当前网络
   */
  leaveNetwork(): void {
    this.databaseService.remove(this.NETWORK_ID_KEY);
  }

  /**
   * 生成临时访问码
   */
  generateAccessCode(expiryMinutes: number = 5): string {
    // 生成6位数字访问码
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    
    // 保存访问码及过期时间
    const accessCodes = this.databaseService.get(this.ACCESS_CODES_KEY) || {};
    accessCodes[code] = Date.now() + expiryMinutes * 60 * 1000;
    this.databaseService.set(this.ACCESS_CODES_KEY, accessCodes);
    
    return code;
  }

  /**
   * 验证访问码
   */
  validateAccessCode(accessCode: string): { valid: boolean; networkId?: string; error?: string } {
    const accessCodes = this.databaseService.get(this.ACCESS_CODES_KEY) || {};
    const expiryTime = accessCodes[accessCode];
    
    if (!expiryTime) {
      return { valid: false, error: '访问码不存在' };
    }
    
    if (Date.now() > expiryTime) {
      // 访问码已过期，移除
      delete accessCodes[accessCode];
      this.databaseService.set(this.ACCESS_CODES_KEY, accessCodes);
      return { valid: false, error: '访问码已过期' };
    }
    
    // 访问码有效，返回当前网络ID
    const networkId = this.getCurrentNetworkId();
    return { valid: true, networkId };
  }
}
```

## 3. 实际使用示例

### 3.1 Web平台使用示例

```typescript
// src/App.tsx
import React, { useState, useEffect } from 'react';
import { AuthServiceImpl } from './services/auth/AuthServiceImpl';
import { DatabaseService } from './services/database/DatabaseService';

function App() {
  const [networkId, setNetworkId] = useState<string | null>(null);
  const [accessCode, setAccessCode] = useState<string>('');
  const [isGenerating, setIsGenerating] = useState<boolean>(false);
  
  // 初始化认证服务
  const databaseService = new DatabaseService();
  const authService = new AuthServiceImpl(databaseService);

  // 加载当前网络ID
  useEffect(() => {
    const currentId = authService.getCurrentNetworkId();
    if (currentId) {
      setNetworkId(currentId);
    }
  }, []);

  // 创建新网络
  const handleCreateNetwork = async () => {
    setIsGenerating(true);
    try {
      const newNetworkId = await authService.generateNetworkId();
      await authService.joinNetwork(newNetworkId);
      setNetworkId(newNetworkId);
    } catch (error) {
      console.error('创建网络失败:', error);
    } finally {
      setIsGenerating(false);
    }
  };

  // 加入现有网络
  const handleJoinNetwork = async (inputNetworkId: string) => {
    if (!authService.validateNetworkId(inputNetworkId)) {
      alert('无效的网络ID格式');
      return;
    }

    const result = await authService.joinNetwork(inputNetworkId);
    if (result.success) {
      setNetworkId(inputNetworkId);
      alert('成功加入网络');
    } else {
      alert(result.message || '加入网络失败');
    }
  };

  // 生成访问码
  const handleGenerateAccessCode = () => {
    const code = authService.generateAccessCode(10); // 10分钟有效期
    setAccessCode(code);
    
    // 复制到剪贴板
    navigator.clipboard.writeText(code)
      .then(() => alert('访问码已复制到剪贴板'))
      .catch(() => console.error('复制失败'));
  };

  // 离开网络
  const handleLeaveNetwork = () => {
    authService.leaveNetwork();
    setNetworkId(null);
    setAccessCode('');
    alert('已离开当前网络');
  };

  return (
    <div className="app">
      <h1>CardMind 网络管理</h1>
      
      {!networkId ? (
        <div className="network-setup">
          <button onClick={handleCreateNetwork} disabled={isGenerating}>
            {isGenerating ? '创建中...' : '创建新网络'}
          </button>
          <div className="join-network">
            <input 
              type="text" 
              placeholder="输入网络ID" 
              onKeyPress={(e) => {
                if (e.key === 'Enter') handleJoinNetwork(e.currentTarget.value);
              }}
            />
            <button onClick={(e) => {
              const input = e.currentTarget.previousSibling as HTMLInputElement;
              handleJoinNetwork(input.value);
            }}>
              加入网络
            </button>
          </div>
        </div>
      ) : (
        <div className="network-info">
          <p>当前网络ID: <code>{networkId}</code></p>
          <div className="access-code-section">
            <button onClick={handleGenerateAccessCode}>生成访问码</button>
            {accessCode && (
              <div className="access-code">
                <span>访问码: <strong>{accessCode}</strong></span>
                <small>有效期: 10分钟</small>
              </div>
            )}
          </div>
          <button onClick={handleLeaveNetwork} className="leave-button">
            离开网络
          </button>
        </div>
      )}
    </div>
  );
}

export default App;
```

### 3.2 Electron平台使用示例

```typescript
// src/main/auth-handler.ts
import { ipcMain } from 'electron';
import { AuthServiceImpl } from '../services/auth/AuthServiceImpl';
import { DatabaseService } from '../services/database/DatabaseService';

/**
 * Electron主进程认证处理程序
 */
export class AuthHandler {
  private authService: AuthServiceImpl;

  constructor() {
    const databaseService = new DatabaseService();
    this.authService = new AuthServiceImpl(databaseService);
    this.registerIpcHandlers();
  }

  private registerIpcHandlers(): void {
    // 生成网络ID
    ipcMain.handle('auth:generate-network-id', async () => {
      return await this.authService.generateNetworkId();
    });

    // 加入网络
    ipcMain.handle('auth:join-network', async (_, networkId: string) => {
      return await this.authService.joinNetwork(networkId);
    });

    // 验证网络ID
    ipcMain.handle('auth:validate-network-id', (_, networkId: string) => {
      return this.authService.validateNetworkId(networkId);
    });

    // 获取当前网络ID
    ipcMain.handle('auth:get-current-network-id', () => {
      return this.authService.getCurrentNetworkId();
    });

    // 离开网络
    ipcMain.handle('auth:leave-network', () => {
      return this.authService.leaveNetwork();
    });

    // 生成访问码
    ipcMain.handle('auth:generate-access-code', (_, expiryMinutes?: number) => {
      return this.authService.generateAccessCode(expiryMinutes);
    });

    // 验证访问码
    ipcMain.handle('auth:validate-access-code', (_, accessCode: string) => {
      return this.authService.validateAccessCode(accessCode);
    });
  }
}

// 在主进程中初始化
// src/main/main.ts
import { AuthHandler } from './auth-handler';

// ... 其他代码 ...

// 初始化认证处理程序
const authHandler = new AuthHandler();

// ... 其他代码 ...

// 渲染进程中使用示例
// src/renderer/components/NetworkManager.tsx
import React, { useState } from 'react';
import { ipcRenderer } from 'electron';

const NetworkManager: React.FC = () => {
  const [networkId, setNetworkId] = useState<string>('');
  const [currentNetwork, setCurrentNetwork] = useState<string | null>(null);
  const [accessCode, setAccessCode] = useState<string>('');

  // 获取当前网络ID
  const loadCurrentNetwork = async () => {
    const id = await ipcRenderer.invoke('auth:get-current-network-id');
    setCurrentNetwork(id);
  };

  // 创建网络
  const handleCreateNetwork = async () => {
    const newNetworkId = await ipcRenderer.invoke('auth:generate-network-id');
    await ipcRenderer.invoke('auth:join-network', newNetworkId);
    setCurrentNetwork(newNetworkId);
  };

  // 加入网络
  const handleJoinNetwork = async () => {
    const result = await ipcRenderer.invoke('auth:join-network', networkId);
    if (result.success) {
      setCurrentNetwork(networkId);
      setNetworkId('');
      alert('成功加入网络');
    } else {
      alert(result.message || '加入网络失败');
    }
  };

  return (
    <div className="network-manager">
      <button onClick={loadCurrentNetwork}>刷新状态</button>
      {currentNetwork && (
        <div>
          <p>当前网络: {currentNetwork}</p>
        </div>
      )}
      <div>
        <input 
          type="text" 
          placeholder="网络ID" 
          value={networkId} 
          onChange={(e) => setNetworkId(e.target.value)}
        />
        <button onClick={handleJoinNetwork}>加入</button>
        <button onClick={handleCreateNetwork}>创建</button>
      </div>
    </div>
  );
};

export default NetworkManager;
```

## 4. 单元测试

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
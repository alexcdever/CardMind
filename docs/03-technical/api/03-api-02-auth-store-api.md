# authStore API

## 1. 接口定义

```typescript
// src/stores/authStore.ts
import { create } from 'zustand';
import { AuthService } from '../services/auth/AuthService';

/**
 * 认证状态接口
 */
export interface AuthState {
  /**
   * 当前网络ID
   */
  currentNetworkId: string | null;
  
  /**
   * 是否已加入网络
   */
  isJoinedNetwork: boolean;
  
  /**
   * 是否正在处理网络操作
   */
  isLoading: boolean;
  
  /**
   * 错误信息
   */
  error: string | null;
  
  /**
   * 生成新网络
   * @returns 生成的网络ID
   */
  generateNewNetwork: () => Promise<string>;
  
  /**
   * 加入网络
   * @param networkId 网络ID
   */
  joinNetwork: (networkId: string) => Promise<void>;
  
  /**
   * 离开网络
   */
  leaveNetwork: () => void;
  
  /**
   * 生成访问码
   * @param expiryMinutes 有效期（分钟）
   * @returns 访问码
   */
  generateAccessCode: (expiryMinutes?: number) => string;
  
  /**
   * 使用访问码加入网络
   * @param accessCode 访问码
   */
  joinWithAccessCode: (accessCode: string) => Promise<void>;
  
  /**
   * 清除错误信息
   */
  clearError: () => void;
}

/**
 * 创建认证状态存储
 * @param authService 认证服务实例
 * @returns 认证状态存储
 */
export const createAuthStore = (authService: AuthService) => 
  create<AuthState>((set, get) => ({
    currentNetworkId: null,
    isJoinedNetwork: false,
    isLoading: false,
    error: null,
    
    generateNewNetwork: async () => {
      set({ isLoading: true, error: null });
      try {
        const networkId = await authService.generateNetworkId();
        await authService.joinNetwork(networkId);
        set({ 
          currentNetworkId: networkId, 
          isJoinedNetwork: true,
          isLoading: false 
        });
        return networkId;
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '生成网络失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    joinNetwork: async (networkId: string) => {
      set({ isLoading: true, error: null });
      try {
        const result = await authService.joinNetwork(networkId);
        if (result.success) {
          set({ 
            currentNetworkId: networkId, 
            isJoinedNetwork: true,
            isLoading: false 
          });
        } else {
          throw new Error(result.message || '加入网络失败');
        }
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '加入网络失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    leaveNetwork: () => {
      authService.leaveNetwork();
      set({ 
        currentNetworkId: null, 
        isJoinedNetwork: false,
        error: null 
      });
    },
    
    generateAccessCode: (expiryMinutes?: number) => {
      const currentNetworkId = get().currentNetworkId;
      if (!currentNetworkId) {
        throw new Error('未加入任何网络');
      }
      return authService.generateAccessCode(expiryMinutes);
    },
    
    joinWithAccessCode: async (accessCode: string) => {
      set({ isLoading: true, error: null });
      try {
        const validationResult = authService.validateAccessCode(accessCode);
        if (validationResult.valid && validationResult.networkId) {
          await get().joinNetwork(validationResult.networkId);
        } else {
          throw new Error(validationResult.error || '无效的访问码');
        }
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '使用访问码加入失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    clearError: () => set({ error: null }),
  }));

/**
 * 认证状态存储类型
 */
export type AuthStore = ReturnType<typeof createAuthStore>;
```

## 2. 单元测试

```typescript
// src/stores/authStore.test.ts
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { createAuthStore, AuthState } from './authStore';
import { AuthService } from '../services/auth/AuthService';

// Mock the AuthService
const mockAuthService = {
  generateNetworkId: jest.fn(),
  joinNetwork: jest.fn(),
  leaveNetwork: jest.fn(),
  generateAccessCode: jest.fn(),
  validateAccessCode: jest.fn(),
} as unknown as AuthService;

describe('authStore', () => {
  let authStore: any;
  
  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();
    
    // Create a new store instance for each test
    authStore = createAuthStore(mockAuthService);
  });

  describe('initial state', () => {
    it('should initialize with correct default values', () => {
      const state = authStore.getState();
      
      expect(state.currentNetworkId).toBeNull();
      expect(state.isJoinedNetwork).toBe(false);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
    });
  });

  describe('generateNewNetwork', () => {
    it('should generate and join a new network successfully', async () => {
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      
      // Setup mocks
      (mockAuthService.generateNetworkId as jest.Mock).mockResolvedValue(mockNetworkId);
      (mockAuthService.joinNetwork as jest.Mock).mockResolvedValue({ success: true });
      
      // Call the method
      const result = await authStore.getState().generateNewNetwork();
      
      // Verify the result
      expect(result).toBe(mockNetworkId);
      
      // Verify state was updated
      const state = authStore.getState();
      expect(state.currentNetworkId).toBe(mockNetworkId);
      expect(state.isJoinedNetwork).toBe(true);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service methods were called
      expect(mockAuthService.generateNetworkId).toHaveBeenCalled();
      expect(mockAuthService.joinNetwork).toHaveBeenCalledWith(mockNetworkId);
    });

    it('should handle errors during network generation', async () => {
      const errorMessage = 'Network generation failed';
      
      // Setup mock to throw error
      (mockAuthService.generateNetworkId as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(authStore.getState().generateNewNetwork()).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = authStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });

    it('should handle failed network join', async () => {
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      const errorMessage = 'Join network failed';
      
      // Setup mocks
      (mockAuthService.generateNetworkId as jest.Mock).mockResolvedValue(mockNetworkId);
      (mockAuthService.joinNetwork as jest.Mock).mockResolvedValue({ 
        success: false, 
        message: errorMessage 
      });
      
      // Call the method and expect it to throw
      await expect(authStore.getState().generateNewNetwork()).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = authStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('joinNetwork', () => {
    it('should join a network successfully', async () => {
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      
      // Setup mock
      (mockAuthService.joinNetwork as jest.Mock).mockResolvedValue({ success: true });
      
      // Call the method
      await authStore.getState().joinNetwork(mockNetworkId);
      
      // Verify state was updated
      const state = authStore.getState();
      expect(state.currentNetworkId).toBe(mockNetworkId);
      expect(state.isJoinedNetwork).toBe(true);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockAuthService.joinNetwork).toHaveBeenCalledWith(mockNetworkId);
    });

    it('should handle failed network join', async () => {
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      const errorMessage = 'Invalid network ID';
      
      // Setup mock to return failure
      (mockAuthService.joinNetwork as jest.Mock).mockResolvedValue({ 
        success: false, 
        message: errorMessage 
      });
      
      // Call the method and expect it to throw
      await expect(authStore.getState().joinNetwork(mockNetworkId)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = authStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
      expect(state.isJoinedNetwork).toBe(false);
    });

    it('should handle errors during network join', async () => {
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      const errorMessage = 'Network join error';
      
      // Setup mock to throw error
      (mockAuthService.joinNetwork as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(authStore.getState().joinNetwork(mockNetworkId)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = authStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('leaveNetwork', () => {
    it('should leave the current network', () => {
      // First join a network to set state
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      authStore.setState({
        currentNetworkId: mockNetworkId,
        isJoinedNetwork: true
      });
      
      // Call the method
      authStore.getState().leaveNetwork();
      
      // Verify state was updated
      const state = authStore.getState();
      expect(state.currentNetworkId).toBeNull();
      expect(state.isJoinedNetwork).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockAuthService.leaveNetwork).toHaveBeenCalled();
    });

    it('should handle leaving when not in a network', () => {
      // Ensure we're not in a network
      authStore.setState({
        currentNetworkId: null,
        isJoinedNetwork: false
      });
      
      // Call the method (should not throw)
      expect(() => authStore.getState().leaveNetwork()).not.toThrow();
      
      // Verify service method was still called
      expect(mockAuthService.leaveNetwork).toHaveBeenCalled();
    });
  });

  describe('generateAccessCode', () => {
    it('should generate an access code when in a network', () => {
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      const mockAccessCode = 'mock-access-code-123';
      const expiryMinutes = 10;
      
      // Set state to be in a network
      authStore.setState({
        currentNetworkId: mockNetworkId,
        isJoinedNetwork: true
      });
      
      // Setup mock
      (mockAuthService.generateAccessCode as jest.Mock).mockReturnValue(mockAccessCode);
      
      // Call the method
      const result = authStore.getState().generateAccessCode(expiryMinutes);
      
      // Verify result
      expect(result).toBe(mockAccessCode);
      
      // Verify service method was called with correct params
      expect(mockAuthService.generateAccessCode).toHaveBeenCalledWith(expiryMinutes);
    });

    it('should throw an error when not in a network', () => {
      // Ensure we're not in a network
      authStore.setState({
        currentNetworkId: null,
        isJoinedNetwork: false
      });
      
      // Call the method and expect it to throw
      expect(() => authStore.getState().generateAccessCode()).toThrow('未加入任何网络');
    });
  });

  describe('joinWithAccessCode', () => {
    it('should join a network using a valid access code', async () => {
      const mockNetworkId = '123e4567-e89b-12d3-a456-426614174000';
      const mockAccessCode = 'valid-access-code';
      
      // Setup mocks
      (mockAuthService.validateAccessCode as jest.Mock).mockReturnValue({
        valid: true,
        networkId: mockNetworkId
      });
      (mockAuthService.joinNetwork as jest.Mock).mockResolvedValue({ success: true });
      
      // Mock the joinNetwork method in the store to avoid circular calls
      authStore.setState({
        joinNetwork: jest.fn().mockImplementation(async (networkId: string) => {
          authStore.setState({
            currentNetworkId: networkId,
            isJoinedNetwork: true,
            isLoading: false
          });
        })
      });
      
      // Call the method
      await authStore.getState().joinWithAccessCode(mockAccessCode);
      
      // Verify state was updated
      const state = authStore.getState();
      expect(state.currentNetworkId).toBe(mockNetworkId);
      expect(state.isJoinedNetwork).toBe(true);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockAuthService.validateAccessCode).toHaveBeenCalledWith(mockAccessCode);
    });

    it('should handle invalid access code', async () => {
      const mockAccessCode = 'invalid-access-code';
      const errorMessage = 'Invalid access code';
      
      // Setup mock to return invalid
      (mockAuthService.validateAccessCode as jest.Mock).mockReturnValue({
        valid: false,
        error: errorMessage
      });
      
      // Call the method and expect it to throw
      await expect(authStore.getState().joinWithAccessCode(mockAccessCode)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = authStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });

    it('should handle errors during access code validation', async () => {
      const mockAccessCode = 'error-access-code';
      const errorMessage = 'Validation error';
      
      // Setup mock to throw error
      (mockAuthService.validateAccessCode as jest.Mock).mockReturnValue({
        valid: false,
        error: errorMessage
      });
      
      // Call the method and expect it to throw
      await expect(authStore.getState().joinWithAccessCode(mockAccessCode)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = authStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('clearError', () => {
    it('should clear any existing error', () => {
      // Set an error state
      const errorMessage = 'Test error';
      authStore.setState({ error: errorMessage });
      
      // Call the method
      authStore.getState().clearError();
      
      // Verify error was cleared
      const state = authStore.getState();
      expect(state.error).toBeNull();
    });

    it('should have no effect if no error exists', () => {
      // Ensure no error exists
      authStore.setState({ error: null });
      
      // Call the method
      authStore.getState().clearError();
      
      // Verify state remains the same
      const state = authStore.getState();
      expect(state.error).toBeNull();
    });
  });
});
```

## 导航与引用

- [API测试设计文档索引](../api-testing-design-index.md)
- [设备管理Store API](device-store-api.md)
- [卡片管理Store API](card-store-api.md)
- [同步管理Store API](sync-store-api.md)
- [系统测试计划](../testing/system-testing-plan.md)
- [回归测试计划](../testing/regression-testing-plan.md)
- [用户界面测试](../testing/ui-testing.md)
- [测试工具与技术](../testing/testing-tools.md)
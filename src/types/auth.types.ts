/**
 * 认证相关类型定义
 */
export interface User {
  id: string;
  username: string;
  email?: string;
}

/**
 * 认证状态类型定义
 */
export interface AuthState {
  isAuthenticated: boolean;
  networkId: string | null;
  isLoading: boolean;
  error: string | null;
  lastSyncTimestamp: number;
}

/**
 * 网络认证组件状态类型定义
 */
export interface NetworkAuthState {
  networkId: string;
  isGenerating: boolean;
  isJoining: boolean;
  error: string | null;
  showAdvanced: boolean;
  autoJoinMode: boolean;
}

/**
 * 网络信息类型定义
 */
export interface NetworkInfo {
  id: string;
  createdAt: number;
  lastActive: number;
  deviceCount: number;
}
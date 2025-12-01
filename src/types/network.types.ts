/**
 * 网络实体类型定义
 */
export interface Network {
  networkId: string;
  accessCode: string;
  createdAt: number;
  expiresAt?: number;
  createdByDeviceId: string;
}

/**
 * 同步状态类型定义
 */
export interface SyncState {
  isOnline: boolean;
  isSyncing: boolean;
  lastSyncTime: number | null;
  syncError: string | null;
  connectedDevices: number;
  networkId: string | null;
  webrtcStatus: 'disconnected' | 'connecting' | 'connected';
  broadcastStatus: 'inactive' | 'active';
  syncStatus: 'idle' | 'syncing' | 'error' | 'completed';
}

/**
 * 同步操作类型定义
 */
export interface SyncActions {
  setOnlineStatus: (status: boolean) => void;
  setSyncingStatus: (status: boolean) => void;
  setSyncError: (error: string | null) => void;
  updateLastSyncTime: () => void;
  updateConnectedDevices: (count: number) => void;
  setNetworkId: (networkId: string | null) => void;
  setWebrtcStatus: (status: 'disconnected' | 'connecting' | 'connected') => void;
  setBroadcastStatus: (status: 'inactive' | 'active') => void;
  setSyncStatus: (status: 'idle' | 'syncing' | 'error' | 'completed') => void;
  resetSyncState: () => void;
}

/**
 * 认证状态类型定义
 */
export interface AuthState {
  isAuthenticated: boolean;
  networkId: string | null;
  accessCode: string | null;
  accessCodeExpiresAt: number | null;
  deviceId: string | null;
}

/**
 * 认证操作类型定义
 */
export interface AuthActions {
  joinNetwork: (networkId: string, accessCode?: string) => Promise<boolean>;
  leaveNetwork: () => Promise<void>;
  generateAccessCode: () => string;
  validateAccessCode: (accessCode: string) => boolean;
  getNetworkInfo: () => { networkId: string | null; accessCode: string | null };
}

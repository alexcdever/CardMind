/**
 * 设备实体类型定义
 */
export interface Device {
  deviceId: string;
  nickname: string;
  deviceType: string;
  platform: string;
  lastSeen: number;
  isOnline: boolean;
}

/**
 * 设备状态类型定义
 */
export interface DeviceState {
  deviceId: string;
  nickname: string;
  deviceType: string;
  lastSeen: number;
  onlineDevices: Device[];
  isLoading: boolean;
  error: string | null;
  syncStatus: {
    lastSyncTime: Date | null;
    pendingChanges: number;
    isSyncing: boolean;
  };
}

/**
 * 设备操作类型定义
 */
export interface DeviceActions {
  initializeDevice: () => Promise<void>;
  updateNickname: (nickname: string) => void;
  updateLastSeen: () => void;
  updateOnlineDevices: (devices: Device[]) => void;
  getDeviceInfo: () => { id: string; nickname: string; deviceType: string };
  updateSyncStatus?: (status: Partial<DeviceState['syncStatus']>) => void;
}

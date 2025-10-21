/**
 * 设备信息类型定义
 */
export interface Device {
  id: string;
  nickname: string;
  deviceType: string;
  type: 'desktop' | 'mobile' | 'tablet' | 'other';
  isOnline: boolean;
  createdAt: number;
  lastSeen: number;
}

/**
 * 设备存储状态类型定义
 */
export interface DeviceState {
  deviceId: string;
  nickname: string;
  deviceType: string;
  lastSeen: number;
  onlineDevices: Device[];
  isLoading: boolean;
  error: string | null;
}
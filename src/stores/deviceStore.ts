import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'

// 添加SyncStatus接口来替代any类型
export interface SyncStatus {
  lastSyncTime: Date | null;
  pendingChanges: number;
  isSyncing: boolean;
}

// 重新定义DeviceState接口以避免使用any类型
export interface DeviceState {
  deviceId: string;
  nickname: string;
  deviceType: string;
  lastSeen: number;
  onlineDevices: Array<{id: string; nickname: string; deviceType: string}>;
  isLoading: boolean;
  error: string | null;
  syncStatus: SyncStatus; // 使用具体类型替代any
}

interface DeviceActions {
  initializeDevice: () => Promise<void>;
  updateNickname: (nickname: string) => void;
  updateLastSeen: () => void;
  updateOnlineDevices: (devices: Array<{id: string; nickname: string; deviceType: string}>) => void;
  getDeviceInfo: () => { id: string; nickname: string; deviceType: string };
  updateSyncStatus?: (status: Partial<SyncStatus>) => void; // 可选：添加更新同步状态的方法
}

type DeviceStore = DeviceState & DeviceActions

// 获取设备类型
const getDeviceType = (): string => {
  const ua = navigator.userAgent
  if (ua.match(/iPad/i) || ua.match(/iPhone/i) || ua.match(/Android/i)) {
    return 'mobile'
  }
  if (ua.match(/Win/i) || ua.match(/Mac/i) || ua.match(/Linux/i)) {
    return 'desktop'
  }
  return 'unknown'
}

// 生成默认设备昵称
const generateDefaultNickname = (): string => {
  const deviceType = getDeviceType()
  const typeName = deviceType === 'mobile' ? '移动设备' : '桌面设备'
  return `${typeName}-${Math.floor(Math.random() * 10000)}`
}

const useDeviceStore = create<DeviceStore>((set, get) => ({
  // 初始状态
  deviceId: '',
  nickname: '',
  deviceType: '',
  lastSeen: Date.now(),
  onlineDevices: [],
  isLoading: false,
  error: null,
  syncStatus: {
    lastSyncTime: null,
    pendingChanges: 0,
    isSyncing: false
  },
  
  // 初始化设备信息
  initializeDevice: async () => {
    set({ isLoading: true })
    
    try {
      // 尝试从本地存储获取设备信息
      let deviceId = localStorage.getItem('deviceId')
      let nickname = localStorage.getItem('deviceNickname')
      
      // 如果不存在，生成新的设备ID和默认昵称
      if (!deviceId) {
        deviceId = uuidv4()
        localStorage.setItem('deviceId', deviceId)
      }
      
      if (!nickname) {
        nickname = generateDefaultNickname()
        localStorage.setItem('deviceNickname', nickname)
      }
      
      const deviceType = getDeviceType()
      const lastSeen = Date.now()
      
      set({
        deviceId,
        nickname,
        deviceType,
        lastSeen,
        isLoading: false
      })
    } catch (error) {
      set({ error: '初始化设备信息失败', isLoading: false })
    }
  },
  
  // 更新设备昵称
  updateNickname: (nickname: string) => {
    // 保存到本地存储
    localStorage.setItem('deviceNickname', nickname)
    
    set({ nickname })
  },
  
  // 更新最后在线时间
  updateLastSeen: () => {
    const lastSeen = Date.now()
    set({ lastSeen })
  },
  
  // 更新在线设备列表
  updateOnlineDevices: (devices: Array<{id: string; nickname: string; deviceType: string}>) => {
    set({ onlineDevices: devices })
  },
  
  // 获取当前设备信息
  getDeviceInfo: () => {
    const { deviceId, nickname, deviceType } = get()
    return { id: deviceId, nickname, deviceType }
  }
}))

export default useDeviceStore
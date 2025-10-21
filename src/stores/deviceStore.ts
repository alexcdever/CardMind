import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'
import { DeviceState } from '@/types/device.types'

interface DeviceActions {
  initializeDevice: () => Promise<void>;
  updateNickname: (nickname: string) => void;
  updateLastSeen: () => void;
  updateOnlineDevices: (devices: any[]) => void;
  getDeviceInfo: () => { id: string; nickname: string; deviceType: string };
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
  updateOnlineDevices: (devices) => {
    set({ onlineDevices: devices })
  },
  
  // 获取当前设备信息
  getDeviceInfo: () => {
    const { deviceId, nickname, deviceType } = get()
    return { id: deviceId, nickname, deviceType }
  }
}))

export default useDeviceStore
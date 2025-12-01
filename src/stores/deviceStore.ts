import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'
import { DeviceState, DeviceActions } from '../types/device.types'

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

type DeviceStore = DeviceState & DeviceActions

const useDeviceStore = create<DeviceStore>((set, get) => ({
  // 初始状态
  deviceId: localStorage.getItem('deviceId') || uuidv4(),
  nickname: localStorage.getItem('deviceNickname') || generateDefaultNickname(),
  deviceType: getDeviceType(),
  lastSeen: Date.now(),
  onlineDevices: [],
  isLoading: false,
  error: null,
  syncStatus: {
    lastSyncTime: null,
    pendingChanges: 0,
    isSyncing: false
  },

  // 初始化设备
  initializeDevice: async () => {
    try {
      set({ isLoading: true, error: null })
      
      // 保存设备信息到本地存储
      const deviceId = get().deviceId
      const nickname = get().nickname
      localStorage.setItem('deviceId', deviceId)
      localStorage.setItem('deviceNickname', nickname)
      
      set({ isLoading: false })
    } catch (error) {
      set({ 
        error: error instanceof Error ? error.message : '设备初始化失败',
        isLoading: false 
      })
    }
  },

  // 更新设备昵称
  updateNickname: (nickname: string) => {
    localStorage.setItem('deviceNickname', nickname)
    set({ nickname })
  },

  // 更新设备最后在线时间
  updateLastSeen: () => {
    set({ lastSeen: Date.now() })
  },

  // 更新在线设备列表
  updateOnlineDevices: (devices) => {
    set({ onlineDevices: devices })
  },

  // 获取设备信息
  getDeviceInfo: () => {
    const { deviceId, nickname, deviceType } = get()
    return { id: deviceId, nickname, deviceType }
  },

  // 更新同步状态
  updateSyncStatus: (status) => {
    set((state) => ({
      syncStatus: { ...state.syncStatus, ...status }
    }))
  }
}))

export default useDeviceStore

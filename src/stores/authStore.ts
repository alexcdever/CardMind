import { create } from 'zustand'
import { AuthState, AuthActions } from '../types/network.types'
import useDeviceStore from './deviceStore'
import useSyncStore from './syncStore'

type AuthStore = AuthState & AuthActions

const useAuthStore = create<AuthStore>((set, get) => ({
  // 初始状态
  isAuthenticated: false,
  networkId: null,
  accessCode: null,
  accessCodeExpiresAt: null,
  deviceId: useDeviceStore.getState().deviceId,

  // 加入网络
  joinNetwork: async (networkId: string, accessCode?: string) => {
    try {
      // 验证访问码（如果提供）
      if (accessCode && !get().validateAccessCode(accessCode)) {
        return false
      }

      // 设置网络ID和认证状态
      set({
        isAuthenticated: true,
        networkId,
        deviceId: useDeviceStore.getState().deviceId
      })

      // 更新同步状态
      useSyncStore.getState().setNetworkId(networkId)
      useSyncStore.getState().setOnlineStatus(true)
      useSyncStore.getState().setSyncStatus('syncing')

      return true
    } catch (error) {
      console.error('加入网络失败:', error)
      return false
    }
  },

  // 离开网络
  leaveNetwork: async () => {
    try {
      // 重置认证状态
      set({
        isAuthenticated: false,
        networkId: null,
        accessCode: null,
        accessCodeExpiresAt: null
      })

      // 重置同步状态
      useSyncStore.getState().resetSyncState()
    } catch (error) {
      console.error('离开网络失败:', error)
      throw error
    }
  },

  // 生成访问码
  generateAccessCode: () => {
    // 生成6位数字访问码
    const accessCode = Math.floor(100000 + Math.random() * 900000).toString()
    // 设置5分钟过期时间
    const accessCodeExpiresAt = Date.now() + 5 * 60 * 1000

    set({
      accessCode,
      accessCodeExpiresAt
    })

    return accessCode
  },

  // 验证访问码
  validateAccessCode: (accessCode: string) => {
    const { accessCode: currentAccessCode, accessCodeExpiresAt } = get()
    
    // 检查访问码是否匹配且未过期
    if (currentAccessCode === accessCode && 
        accessCodeExpiresAt && 
        Date.now() < accessCodeExpiresAt) {
      return true
    }
    
    return false
  },

  // 获取网络信息
  getNetworkInfo: () => {
    const { networkId, accessCode } = get()
    return { networkId, accessCode }
  }
}))

export default useAuthStore

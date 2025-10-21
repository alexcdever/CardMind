import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'
import { AuthState } from '@/types/auth.types'
import { networkRegex } from '@/utils/validation'

interface AuthActions {
  generateNetworkId: () => string;
  validateNetworkId: (networkId: string) => boolean;
  joinNetwork: (networkId: string) => Promise<boolean>;
  leaveNetwork: () => void;
  getCurrentNetworkId: () => string | null;
  clearError: () => void;
}

type AuthStore = AuthState & AuthActions

const useAuthStore = create<AuthStore>((set, get) => ({
  // 初始状态
  isAuthenticated: false,
  networkId: null,
  isLoading: false,
  error: null,
  lastSyncTimestamp: 0,
  
  // 生成新的网络ID
  generateNetworkId: () => {
    return uuidv4()
  },
  
  // 验证网络ID格式
  validateNetworkId: (networkId: string) => {
    return networkRegex.test(networkId)
  },
  
  // 加入网络
  joinNetwork: async (networkId: string) => {
    const { validateNetworkId } = get()
    
    // 验证网络ID格式
    if (!validateNetworkId(networkId)) {
      set({ error: '网络ID格式不正确' })
      return false
    }
    
    set({ isLoading: true, error: null })
    
    try {
      // 保存网络ID到本地存储
      localStorage.setItem('currentNetworkId', networkId)
      
      set({
        isAuthenticated: true,
        networkId,
        isLoading: false,
        error: null
      })
      
      return true
    } catch (error) {
      set({ error: '加入网络失败', isLoading: false })
      return false
    }
  },
  
  // 离开网络
  leaveNetwork: () => {
    // 清除本地存储的网络ID
    localStorage.removeItem('currentNetworkId')
    
    set({
      isAuthenticated: false,
      networkId: null,
      error: null
    })
  },
  
  // 获取当前网络ID
  getCurrentNetworkId: () => {
    const { networkId } = get()
    return networkId
  },
  
  // 清除错误信息
  clearError: () => {
    set({ error: null })
  }
}))

export default useAuthStore
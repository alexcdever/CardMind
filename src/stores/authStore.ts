import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'
import { AuthState } from '@/types/auth.types'
import { networkRegex } from '@/utils/validation'
import syncService from '@/services/syncService'

export interface AuthActions {
  generateNetworkId: () => string;
  validateNetworkId: (networkId: string) => boolean;
  joinNetwork: (networkId: string) => Promise<void>;
  leaveNetwork: () => void;
  getCurrentNetworkId: () => string | null;
  getDefaultNetworkId: () => string;
  clearError: () => void;
}

type AuthStore = AuthState & AuthActions

// 辅助函数：Base64编码（URL安全）
const encodeBase64 = (text: string): string => {
  return btoa(encodeURIComponent(text))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

// 辅助函数：Base64解码
const decodeBase64 = (encoded: string): string => {
  try {
    const padded = encoded + '='.repeat((4 - encoded.length % 4) % 4)
    return decodeURIComponent(atob(padded.replace(/-/g, '+').replace(/_/g, '/')))
  } catch {
    return ''
  }
}

// 获取当前设备的IP/域名和端口
const getDeviceAddress = (): string => {
  const { protocol, hostname, port } = window.location
  // 如果没有指定端口，使用默认端口
  const effectivePort = port || (protocol === 'https:' ? '443' : '80')
  return `${hostname}:${effectivePort}`
}

const useAuthStore = create<AuthStore>((set, get) => ({
  // 初始状态
  isAuthenticated: false,
  networkId: null,
  isLoading: false,
  error: null,
  lastSyncTimestamp: 0,
  
  // 生成新的网络ID - 基于IP/域名+端口+随机码
  generateNetworkId: () => {
    const deviceAddress = getDeviceAddress()
    const randomCode = uuidv4().replace(/-/g, '') // 移除UUID中的连字符
    const timestamp = Date.now()
    
    // 组合数据：设备地址 + 时间戳 + 随机码
    const rawData = JSON.stringify({
      address: deviceAddress,
      timestamp,
      randomCode
    })
    
    // 使用Base64编码生成最终网络ID
    return encodeBase64(rawData)
  },
  
  // 验证网络ID格式 - 验证Base64编码的网络ID
  validateNetworkId: (networkId: string) => {
    try {
      // 尝试解码网络ID
      const decoded = decodeBase64(networkId)
      const data = JSON.parse(decoded)
      
      // 验证解码后的数据结构
      return (
        data.address && typeof data.address === 'string' &&
        data.timestamp && typeof data.timestamp === 'number' &&
        data.randomCode && typeof data.randomCode === 'string' &&
        data.randomCode.length === 32 // UUID去掉连字符后的长度
      )
    } catch {
      // 解码失败或数据结构不正确
      return false
    }
  },
  
  // 加入网络
  joinNetwork: async (networkId: string) => {
    const { validateNetworkId } = get()
    
    console.log('[AuthStore] 尝试加入网络，网络ID:', networkId)

    // 验证网络ID格式
    if (!validateNetworkId(networkId)) {
      console.error('[AuthStore] 网络ID格式验证失败:', networkId)
      set({ error: '网络ID格式不正确' })
      return
    }

    console.log('[AuthStore] 访问码格式验证通过')
    set({ isLoading: true, error: null })
    
    try {
      // 保存网络ID到本地存储
      localStorage.setItem('currentNetworkId', networkId)
      console.log('[AuthStore] 网络ID已保存到本地存储')
      
      set({
        isAuthenticated: true,
        networkId: networkId,
        isLoading: false,
        error: null
      })
      
      console.log('[AuthStore] 认证状态已更新，当前网络ID:', networkId)
      
      // 认证成功后加入协同网络
      console.log('[AuthStore] 清理之前的网络连接')
      console.log('[AuthStore] 开始加入协同网络')
      syncService.joinNetwork(networkId)
      console.log('[AuthStore] 已请求加入协同网络')
      
      // 实现渐进式同步策略
      const syncAttempts = [
        { delay: 2000, label: '首次' },    // 2秒后首次尝试
        { delay: 5000, label: '第二次' },  // 累计7秒后第二次尝试
        { delay: 8000, label: '第三次' },  // 累计15秒后第三次尝试
        { delay: 15000, label: '第四次' }  // 累计30秒后第四次尝试
      ];
      
      let currentDelay = 0;
      syncAttempts.forEach((attempt) => {
        currentDelay += attempt.delay;
        setTimeout(() => {
          console.log(`[AuthStore] ${attempt.label}同步请求已发送，当前延迟: ${currentDelay}ms`);
          syncService.requestSync();
          
          // 每次同步后立即检查连接状态
          setTimeout(() => {
            try {
              const status = syncService.getConnectionStatus?.() || { peersCount: 0 };
              console.log(`[AuthStore] 同步后连接状态检查: ${status.peersCount}个对等节点`);
              
              // 如果检测到对等节点，额外触发一次数据同步
              if (status.peersCount > 0) {
                console.log(`[AuthStore] 检测到对等节点，触发额外数据同步`);
                // 使用更小的延迟再次请求同步
                setTimeout(() => {
                  syncService.requestSync();
                }, 1000);
              }
            } catch (err) {
              console.warn('[AuthStore] 检查连接状态时出错:', err);
            }
          }, 500);
        }, currentDelay);
      });
      
      // 添加定期验证机制，每30秒检查一次连接状态
      setInterval(() => {
        if (get().networkId === networkId) { // 确保仍然在同一个网络中
          try {
            const status = syncService.getConnectionStatus?.() || { peersCount: 0 };
            console.log(`[AuthStore] 定期连接状态检查: ${status.peersCount}个对等节点`);
            
            // 如果应该有连接但没有检测到，尝试重新同步
            if (status.peersCount === 0) {
              console.log('[AuthStore] 未检测到对等节点，尝试重新同步');
              syncService.requestSync();
            }
          } catch (err) {
            console.warn('[AuthStore] 定期检查连接状态时出错:', err);
          }
        }
      }, 30000);
      
      console.log('[AuthStore] 成功加入网络:', networkId)
    } catch (error) {
      console.error('[AuthStore] 加入网络时出错:', error)
      set({ error: '加入网络失败', isLoading: false })
    }
  },
  
  // 离开网络
  leaveNetwork: () => {
    // 清除本地存储的访问码
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
  
  // 生成或获取默认网络ID（用于测试和演示）
  getDefaultNetworkId: () => {
    // 尝试从localStorage获取默认网络ID
    let defaultNetworkId = localStorage.getItem('defaultNetworkId')
    
    // 如果不存在，生成一个新的默认网络ID
    if (!defaultNetworkId) {
      defaultNetworkId = get().generateNetworkId()
      localStorage.setItem('defaultNetworkId', defaultNetworkId)
    }
    
    return defaultNetworkId
  },
  
  // 清除错误信息
  clearError: () => {
    set({ error: null })
  }
}))

export default useAuthStore
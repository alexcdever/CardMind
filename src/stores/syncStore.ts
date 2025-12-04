import { create } from 'zustand'
import { SyncState, SyncActions } from '../types/network.types'

type SyncStore = SyncState & SyncActions

const useSyncStore = create<SyncStore>((set) => ({
  // 初始状态
  isOnline: navigator.onLine,
  isSyncing: false,
  lastSyncTime: null,
  syncError: null,
  connectedDevices: 0,
  networkId: null,
  webrtcStatus: 'disconnected',
  broadcastStatus: 'inactive',
  syncStatus: 'idle',
  
  // 设置在线状态
  setOnlineStatus: (status: boolean) => {
    set({ isOnline: status })
  },
  
  // 设置同步状态
  setSyncingStatus: (status: boolean) => {
    set({ isSyncing: status })
  },
  
  // 设置同步错误
  setSyncError: (error: string | null) => {
    set({ syncError: error })
  },
  
  // 更新最后同步时间
  updateLastSyncTime: () => {
    set({ lastSyncTime: Date.now() })
  },
  
  // 更新连接设备数量
  updateConnectedDevices: (count: number) => {
    set({ connectedDevices: count })
  },
  
  // 设置网络ID
  setNetworkId: (networkId: string | null) => {
    set({ networkId })
  },
  
  // 设置WebRTC状态
  setWebrtcStatus: (status: 'disconnected' | 'connecting' | 'connected') => {
    set({ webrtcStatus: status })
  },
  
  // 设置广播通道状态
  setBroadcastStatus: (status: 'inactive' | 'active') => {
    set({ broadcastStatus: status })
  },
  
  // 设置同步状态
  setSyncStatus: (status: 'idle' | 'syncing' | 'error' | 'completed') => {
    set({ syncStatus: status })
  },
  
  // 重置同步状态
  resetSyncState: () => {
    set({
      isSyncing: false,
      lastSyncTime: null,
      syncError: null,
      connectedDevices: 0,
      networkId: null,
      webrtcStatus: 'disconnected',
      broadcastStatus: 'inactive',
      syncStatus: 'idle'
    })
  }
}))

export default useSyncStore

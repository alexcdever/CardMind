import { create } from 'zustand'

interface SyncState {
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

interface SyncActions {
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
      syncError: null,
      lastSyncTime: null,
      connectedDevices: 0,
      networkId: null,
      webrtcStatus: 'disconnected',
      broadcastStatus: 'inactive',
      syncStatus: 'idle'
    })
  }
}))

// 监听网络状态变化
window.addEventListener('online', () => {
  useSyncStore.getState().setOnlineStatus(true)
})

window.addEventListener('offline', () => {
  useSyncStore.getState().setOnlineStatus(false)
})

export default useSyncStore
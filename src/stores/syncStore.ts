import { create } from 'zustand'

interface SyncState {
  isOnline: boolean;
  isSyncing: boolean;
  lastSyncTime: number | null;
  syncError: string | null;
  connectedDevices: number;
}

interface SyncActions {
  setOnlineStatus: (status: boolean) => void;
  setSyncingStatus: (status: boolean) => void;
  setSyncError: (error: string | null) => void;
  updateLastSyncTime: () => void;
  updateConnectedDevices: (count: number) => void;
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
  
  // 重置同步状态
  resetSyncState: () => {
    set({
      isSyncing: false,
      syncError: null,
      lastSyncTime: null,
      connectedDevices: 0
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
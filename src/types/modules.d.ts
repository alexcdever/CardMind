// 模块声明文件，帮助IDE识别@/路径别名

declare module '@/services/syncService' {
  const syncService: {
    initialize(): void;
    joinNetwork(accessCode: string): Promise<boolean>;
    leaveNetwork(): void;
    broadcastCardUpdate(card: any): void;
    requestSync(): void;
    getConnectionStatus(): { isConnected: boolean; peersCount: number; isSyncing: boolean };
    cleanup(): void;
  };
  export default syncService;
}

declare module '@/stores/syncStore' {
  export { default } from '../stores/syncStore';
}

declare module '@/stores/deviceStore' {
  export { default } from '../stores/deviceStore';
}

declare module '@/stores/authStore' {
  const useAuthStore: import('../stores/authStore').default;
  export default useAuthStore;
}

declare module '@/services/localStorageService' {
  export const saveToStorage: <T>(key: string, data: T) => void;
  export const getFromStorage: <T>(key: string, defaultValue: T) => T;
  export const removeFromStorage: (key: string) => void;
  export const clearAllStorage: () => void;
  export const saveCards: <T>(cards: T[]) => void;
  export const getCards: <T>() => T[];
  export const saveAuthData: <T>(authData: T) => void;
  export const getAuthData: <T>(defaultValue: T) => T;
  export const clearAuthData: () => void;
  export const saveDeviceData: <T>(deviceData: T) => void;
  export const getDeviceData: <T>(defaultValue: T) => T;
  export const saveSyncData: <T>(syncData: T) => void;
  export const getSyncData: <T>(defaultValue: T) => T;
}

declare module '@/services/cardService' {
  export * from '../services/cardService';
}

declare module '@/services/authService' {
  export * from '../services/authService';
}

declare module '@/services/deviceService' {
  export * from '../services/deviceService';
}
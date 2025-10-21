/**
 * 本地存储服务
 * 处理应用数据的本地持久化存储
 */

// 存储键常量
const STORAGE_KEYS = {
  CARDS: 'cardmind_cards',
  AUTH: 'cardmind_auth',
  DEVICE: 'cardmind_device',
  SYNC: 'cardmind_sync'
}

/**
 * 保存数据到本地存储
 * @param key 存储键
 * @param data 要保存的数据
 */
export const saveToStorage = <T>(key: string, data: T): void => {
  try {
    const serializedData = JSON.stringify(data)
    localStorage.setItem(key, serializedData)
  } catch (error) {
    console.error('Error saving to localStorage:', error)
    throw new Error('Failed to save data to local storage')
  }
}

/**
 * 从本地存储获取数据
 * @param key 存储键
 * @param defaultValue 默认值，如果存储中没有数据
 * @returns 解析后的数据或默认值
 */
export const getFromStorage = <T>(key: string, defaultValue: T): T => {
  try {
    const serializedData = localStorage.getItem(key)
    if (serializedData === null) {
      return defaultValue
    }
    return JSON.parse(serializedData) as T
  } catch (error) {
    console.error('Error reading from localStorage:', error)
    return defaultValue
  }
}

/**
 * 从本地存储移除数据
 * @param key 存储键
 */
export const removeFromStorage = (key: string): void => {
  try {
    localStorage.removeItem(key)
  } catch (error) {
    console.error('Error removing from localStorage:', error)
    throw new Error('Failed to remove data from local storage')
  }
}

/**
 * 清除所有应用相关的本地存储数据
 */
export const clearAllStorage = (): void => {
  try {
    Object.values(STORAGE_KEYS).forEach(key => {
      localStorage.removeItem(key)
    })
  } catch (error) {
    console.error('Error clearing localStorage:', error)
    throw new Error('Failed to clear local storage')
  }
}

// 特定数据类型的存储操作

/**
 * 保存卡片数据
 * @param cards 卡片数组
 */
export const saveCards = <T>(cards: T[]): void => {
  saveToStorage(STORAGE_KEYS.CARDS, cards)
}

/**
 * 获取卡片数据
 * @returns 卡片数组或空数组
 */
export const getCards = <T>(): T[] => {
  return getFromStorage<T[]>(STORAGE_KEYS.CARDS, [])
}

/**
 * 保存认证数据
 * @param authData 认证数据
 */
export const saveAuthData = <T>(authData: T): void => {
  saveToStorage(STORAGE_KEYS.AUTH, authData)
}

/**
 * 获取认证数据
 * @param defaultValue 默认值
 * @returns 认证数据或默认值
 */
export const getAuthData = <T>(defaultValue: T): T => {
  return getFromStorage<T>(STORAGE_KEYS.AUTH, defaultValue)
}

/**
 * 清除认证数据
 */
export const clearAuthData = (): void => {
  removeFromStorage(STORAGE_KEYS.AUTH)
}

/**
 * 保存设备数据
 * @param deviceData 设备数据
 */
export const saveDeviceData = <T>(deviceData: T): void => {
  saveToStorage(STORAGE_KEYS.DEVICE, deviceData)
}

/**
 * 获取设备数据
 * @param defaultValue 默认值
 * @returns 设备数据或默认值
 */
export const getDeviceData = <T>(defaultValue: T): T => {
  return getFromStorage<T>(STORAGE_KEYS.DEVICE, defaultValue)
}

/**
 * 保存同步状态数据
 * @param syncData 同步状态数据
 */
export const saveSyncData = <T>(syncData: T): void => {
  saveToStorage(STORAGE_KEYS.SYNC, syncData)
}

/**
 * 获取同步状态数据
 * @param defaultValue 默认值
 * @returns 同步状态数据或默认值
 */
export const getSyncData = <T>(defaultValue: T): T => {
  return getFromStorage<T>(STORAGE_KEYS.SYNC, defaultValue)
}

export default {
  saveToStorage,
  getFromStorage,
  removeFromStorage,
  clearAllStorage,
  saveCards,
  getCards,
  saveAuthData,
  getAuthData,
  clearAuthData,
  saveDeviceData,
  getDeviceData,
  saveSyncData,
  getSyncData
}
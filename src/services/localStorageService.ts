/**
 * 本地存储服务
 * 用于管理卡片数据的本地持久化
 */

import { Card } from '../types/card.types'

/**
 * 保存卡片数据到本地存储
 * @param cards 卡片数组
 */
export const saveCards = <T extends Card>(cards: T[]): void => {
  try {
    localStorage.setItem('cards', JSON.stringify(cards))
  } catch (error) {
    console.error('保存卡片数据失败:', error)
    throw new Error('保存卡片数据失败')
  }
}

/**
 * 从本地存储获取卡片数据
 * @returns 卡片数组
 */
export const getCards = <T extends Card>(): T[] => {
  try {
    const cardsJson = localStorage.getItem('cards')
    return cardsJson ? JSON.parse(cardsJson) : []
  } catch (error) {
    console.error('获取卡片数据失败:', error)
    return []
  }
}

/**
 * 清除本地存储中的卡片数据
 */
export const clearCards = (): void => {
  try {
    localStorage.removeItem('cards')
  } catch (error) {
    console.error('清除卡片数据失败:', error)
    throw new Error('清除卡片数据失败')
  }
}

/**
 * 保存设备信息到本地存储
 * @param deviceInfo 设备信息对象
 */
export const saveDeviceInfo = (deviceInfo: {
  deviceId: string
  nickname: string
  deviceType: string
}): void => {
  try {
    localStorage.setItem('deviceId', deviceInfo.deviceId)
    localStorage.setItem('deviceNickname', deviceInfo.nickname)
    localStorage.setItem('deviceType', deviceInfo.deviceType)
  } catch (error) {
    console.error('保存设备信息失败:', error)
    throw new Error('保存设备信息失败')
  }
}

/**
 * 从本地存储获取设备信息
 * @returns 设备信息对象
 */
export const getDeviceInfo = (): {
  deviceId: string
  nickname: string
  deviceType: string
} => {
  try {
    const deviceId = localStorage.getItem('deviceId') || ''
    const nickname = localStorage.getItem('deviceNickname') || ''
    const deviceType = localStorage.getItem('deviceType') || ''
    
    return {
      deviceId,
      nickname,
      deviceType
    }
  } catch (error) {
    console.error('获取设备信息失败:', error)
    return {
      deviceId: '',
      nickname: '',
      deviceType: ''
    }
  }
}

/**
 * 保存网络信息到本地存储
 * @param networkInfo 网络信息对象
 */
export const saveNetworkInfo = (networkInfo: {
  networkId: string
  accessCode?: string
  accessCodeExpiresAt?: number
}): void => {
  try {
    localStorage.setItem('networkId', networkInfo.networkId)
    
    if (networkInfo.accessCode) {
      localStorage.setItem('accessCode', networkInfo.accessCode)
    }
    
    if (networkInfo.accessCodeExpiresAt) {
      localStorage.setItem('accessCodeExpiresAt', networkInfo.accessCodeExpiresAt.toString())
    }
  } catch (error) {
    console.error('保存网络信息失败:', error)
    throw new Error('保存网络信息失败')
  }
}

/**
 * 从本地存储获取网络信息
 * @returns 网络信息对象
 */
export const getNetworkInfo = (): {
  networkId: string
  accessCode: string | null
  accessCodeExpiresAt: number | null
} => {
  try {
    const networkId = localStorage.getItem('networkId') || ''
    const accessCode = localStorage.getItem('accessCode') || null
    const accessCodeExpiresAtStr = localStorage.getItem('accessCodeExpiresAt')
    const accessCodeExpiresAt = accessCodeExpiresAtStr ? parseInt(accessCodeExpiresAtStr, 10) : null
    
    return {
      networkId,
      accessCode,
      accessCodeExpiresAt
    }
  } catch (error) {
    console.error('获取网络信息失败:', error)
    return {
      networkId: '',
      accessCode: null,
      accessCodeExpiresAt: null
    }
  }
}

/**
 * 清除本地存储中的网络信息
 */
export const clearNetworkInfo = (): void => {
  try {
    localStorage.removeItem('networkId')
    localStorage.removeItem('accessCode')
    localStorage.removeItem('accessCodeExpiresAt')
  } catch (error) {
    console.error('清除网络信息失败:', error)
    throw new Error('清除网络信息失败')
  }
}

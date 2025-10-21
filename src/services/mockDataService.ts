/**
 * 模拟数据服务
 * 在开发环境下模拟API请求和数据操作
 */

import { Card } from '@/types/card.types'
import { AuthState } from '@/types/auth.types'
import { Device } from '@/types/device.types'

// 模拟延迟
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

// 模拟卡片数据
const mockCards: Card[] = [
  {
    id: '1',
    title: '项目计划',
    content: '这是一个项目计划示例卡片，用于记录项目的关键信息和任务安排。可以在这里添加更多的细节和进度跟踪。',
    createdAt: Date.now() - 86400000 * 2, // 2天前
    updatedAt: Date.now() - 3600000,
    lastModifiedDeviceId: 'device-1',
    isDeleted: false
  },
  {
    id: '2',
    title: '会议笔记',
    content: '会议要点：\n1. 讨论了项目进展\n2. 分配了新任务\n3. 确定了下次会议时间',
    createdAt: Date.now() - 86400000,
    updatedAt: Date.now() - 7200000,
    lastModifiedDeviceId: 'device-2',
    isDeleted: false
  },
  {
    id: '3',
    title: '创意灵感',
    content: '突发奇想：可以为应用添加一个新功能，让用户能够更方便地组织和管理他们的卡片。',
    createdAt: Date.now() - 43200000,
    updatedAt: Date.now() - 43200000,
    lastModifiedDeviceId: 'device-1',
    isDeleted: false
  }
]

// 模拟网络ID集合
const mockNetworks: Record<string, AuthState> = {
  'demo-network-123': {
    isAuthenticated: true,
    networkId: 'demo-network-123',
    isLoading: false,
    error: null,
    lastSyncTimestamp: Date.now()
  }
}

// 模拟设备列表
const mockDevices: Device[] = [
  {
    id: 'device-1',
    nickname: '我的笔记本',
    deviceType: 'desktop',
    type: 'desktop',
    isOnline: true,
    createdAt: Date.now() - 3000000,
    lastSeen: Date.now()
  },
  {
    id: 'device-2',
    nickname: '我的手机',
    deviceType: 'mobile',
    type: 'mobile',
    isOnline: true,
    createdAt: Date.now() - 6000000,
    lastSeen: Date.now() - 300000
  }
]

/**
 * 模拟获取所有卡片
 */
export const fetchCards = async (): Promise<Card[]> => {
  await delay(300) // 模拟网络延迟
  return [...mockCards]
}

/**
 * 模拟创建卡片
 */
export const createMockCard = async (cardData: Omit<Card, 'id'>): Promise<Card> => {
  await delay(300)
  const newCard: Card = {
    ...cardData,
    id: Date.now().toString()
  }
  mockCards.push(newCard)
  return newCard
}

/**
 * 模拟更新卡片
 */
export const updateMockCard = async (cardData: Card): Promise<Card> => {
  await delay(300)
  const index = mockCards.findIndex(c => c.id === cardData.id)
  if (index !== -1) {
    mockCards[index] = { ...cardData, updatedAt: Date.now() }
    return mockCards[index]
  }
  throw new Error('Card not found')
}

/**
 * 模拟删除卡片
 */
export const deleteMockCard = async (cardId: string): Promise<void> => {
  await delay(300)
  const index = mockCards.findIndex(c => c.id === cardId)
  if (index !== -1) {
    mockCards.splice(index, 1)
  } else {
    throw new Error('Card not found')
  }
}

/**
 * 模拟验证网络ID
 */
export const validateNetworkId = async (networkId: string): Promise<boolean> => {
  await delay(200)
  return Object.keys(mockNetworks).includes(networkId)
}

/**
 * 模拟加入网络
 */
export const joinMockNetwork = async (networkId: string): Promise<AuthState> => {
  await delay(400)
  
  if (mockNetworks[networkId]) {
    return mockNetworks[networkId]
  }
  
  // 创建新网络
  const newAuthState: AuthState = {
    isAuthenticated: true,
    networkId,
    isLoading: false,
    error: null,
    lastSyncTimestamp: Date.now()
  };
  
  mockNetworks[networkId] = newAuthState
  return newAuthState
}

/**
 * 模拟获取在线设备列表
 */
export const getOnlineDevices = async (): Promise<Device[]> => {
  await delay(200)
  return mockDevices.filter(device => device.isOnline)
}

/**
 * 模拟注册设备到网络
 */
export const registerDeviceToNetwork = async (device: Device): Promise<void> => {
  await delay(300)
  const existingIndex = mockDevices.findIndex(d => d.id === device.id)
  if (existingIndex !== -1) {
    mockDevices[existingIndex] = { ...device, lastSeen: Date.now() }
  } else {
    mockDevices.push({ ...device, lastSeen: Date.now() })
  }
}

export default {
  fetchCards,
  createMockCard,
  updateMockCard,
  deleteMockCard,
  validateNetworkId,
  joinMockNetwork,
  getOnlineDevices,
  registerDeviceToNetwork
}
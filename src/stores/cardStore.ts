import { create } from 'zustand'
import { Card } from '@/types/card.types'
import { v4 as uuidv4 } from 'uuid'
import useDeviceStore from './deviceStore'
import { saveCards, getCards } from '@/services/localStorageService'
import syncService from '@/services/syncService'

interface CardState {
  cards: Card[];
  deletedCards: Card[];
  isLoading: boolean;
  error: string | null;
}

interface CardActions {
  fetchAllCards: () => Promise<void>;
  fetchDeletedCards: () => Promise<void>;
  createCard: (cardData: Partial<Card>) => Promise<Card>;
  updateCard: (cardData: Card) => Promise<Card>;
  deleteCard: (cardId: string) => Promise<void>;
  restoreCard: (cardId: string) => Promise<void>;
  clearError: () => void;
}

type CardStore = CardState & CardActions

const useCardStore = create<CardStore>((set, get) => ({
  // 初始状态
  cards: [],
  deletedCards: [],
  isLoading: false,
  error: null,
  
  // 获取所有非删除状态的卡片
  fetchAllCards: async () => {
    set({ isLoading: true, error: null })
    
    try {
      // 从本地存储加载卡片数据
      const cardsFromStorage = getCards<Card>()
      // 只返回未删除的卡片
      const activeCards = cardsFromStorage.filter(card => !card.isDeleted)
      set({ cards: activeCards, isLoading: false })
    } catch (error) {
      set({ error: '获取卡片失败', isLoading: false })
    }
  },
  
  // 获取已删除的卡片
  fetchDeletedCards: async () => {
    set({ isLoading: true, error: null })
    
    try {
      // 从本地存储加载并过滤已删除的卡片
      const cardsFromStorage = getCards<Card>()
      const deletedCards = cardsFromStorage.filter(card => card.isDeleted)
      set({ deletedCards, isLoading: false })
    } catch (error) {
      set({ error: '获取已删除卡片失败', isLoading: false })
    }
  },
  
  // 创建新卡片
  createCard: async (cardData: Partial<Card>) => {
    set({ isLoading: true, error: null })
    
    try {
      const now = Date.now()
      const deviceId = useDeviceStore.getState().deviceId
      
      const newCard: Card = {
        id: uuidv4(),
        title: cardData.title || '',
        content: cardData.content || '',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
        lastModifiedDeviceId: deviceId
      }
      
      // 保存到状态和本地存储
      const { cards } = get()
      const updatedCards = [...cards, newCard]
      set({ cards: updatedCards, isLoading: false })
      
      // 保存到本地存储
      const allCards = getCards<Card>()
      saveCards<Card>([...allCards.filter(card => card.id !== newCard.id), newCard])
      
      // 广播卡片创建事件
      syncService.broadcastCardUpdate(newCard)
      
      return newCard
    } catch (error) {
      set({ error: '创建卡片失败', isLoading: false })
      throw error
    }
  },
  
  // 更新卡片
  updateCard: async (cardData: Card) => {
    set({ isLoading: true, error: null })
    
    try {
      const { cards } = get()
      const cardIndex = cards.findIndex(card => card.id === cardData.id)
      
      if (cardIndex === -1) {
        throw new Error('卡片不存在')
      }
      
      const deviceId = useDeviceStore.getState().deviceId
      const updatedCard: Card = {
        ...cardData,
        updatedAt: Date.now(),
        lastModifiedDeviceId: deviceId
      }
      
      // 保存到状态和本地存储
      const updatedCards = [...cards]
      updatedCards[cardIndex] = updatedCard
      set({ cards: updatedCards, isLoading: false })
      
      // 更新本地存储中的卡片
      const allCards = getCards<Card>()
      const storageIndex = allCards.findIndex(card => card.id === updatedCard.id)
      if (storageIndex !== -1) {
        allCards[storageIndex] = updatedCard
      }
      saveCards<Card>(allCards)
      
      // 广播卡片更新事件
      syncService.broadcastCardUpdate(updatedCard)
      
      return updatedCard
    } catch (error) {
      set({ error: '更新卡片失败', isLoading: false })
      throw error
    }
  },
  
  // 删除卡片（软删除）
  deleteCard: async (cardId: string) => {
    set({ isLoading: true, error: null })
    
    try {
      const { cards, deletedCards } = get()
      const cardIndex = cards.findIndex(card => card.id === cardId)
      
      if (cardIndex === -1) {
        throw new Error('卡片不存在')
      }
      
      const deviceId = useDeviceStore.getState().deviceId
      const deletedCard: Card = {
        ...cards[cardIndex],
        isDeleted: true,
        deletedAt: Date.now(),
        updatedAt: Date.now(),
        lastModifiedDeviceId: deviceId
      }
      
      // 保存到状态和本地存储
      const updatedCards = cards.filter(card => card.id !== cardId)
      set({ 
        cards: updatedCards, 
        deletedCards: [...deletedCards, deletedCard],
        isLoading: false 
      })
      
      // 更新本地存储中的卡片（标记为已删除）
      const allCards = getCards<Card>()
      const storageIndex = allCards.findIndex(card => card.id === cardId)
      if (storageIndex !== -1) {
        allCards[storageIndex] = deletedCard
      }
      saveCards<Card>(allCards)
      
      // 广播卡片删除事件
      syncService.broadcastCardUpdate(deletedCard)
    } catch (error) {
      set({ error: '删除卡片失败', isLoading: false })
      throw error
    }
  },
  
  // 恢复已删除的卡片
  restoreCard: async (cardId: string) => {
    set({ isLoading: true, error: null })
    
    try {
      const { cards, deletedCards } = get()
      const cardIndex = deletedCards.findIndex(card => card.id === cardId)
      
      if (cardIndex === -1) {
        throw new Error('已删除卡片不存在')
      }
      
      const deviceId = useDeviceStore.getState().deviceId
      const restoredCard: Card = {
        ...deletedCards[cardIndex],
        isDeleted: false,
        deletedAt: undefined,
        updatedAt: Date.now(),
        lastModifiedDeviceId: deviceId
      }
      
      // 保存到状态和本地存储
      const updatedDeletedCards = deletedCards.filter(card => card.id !== cardId)
      set({ 
        cards: [...cards, restoredCard],
        deletedCards: updatedDeletedCards,
        isLoading: false 
      })
      
      // 更新本地存储中的卡片（标记为已恢复）
      const allCards = getCards<Card>()
      const storageIndex = allCards.findIndex(card => card.id === cardId)
      if (storageIndex !== -1) {
        allCards[storageIndex] = restoredCard
      }
      saveCards<Card>(allCards)
      
      // 广播卡片恢复事件
      syncService.broadcastCardUpdate(restoredCard)
    } catch (error) {
      set({ error: '恢复卡片失败', isLoading: false })
      throw error
    }
  },
  
  // 清除错误信息
  clearError: () => {
    set({ error: null })
  }
}))

export default useCardStore
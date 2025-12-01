import { create } from 'zustand'
import { Card } from '../types/card.types'
import { v4 as uuidv4 } from 'uuid'
import useDeviceStore from './deviceStore'

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
  setCards: (cards: Card[]) => void;
}

type CardStore = CardState & CardActions

const useCardStore = create<CardStore>((set, get) => ({
  // 初始状态
  cards: [],
  deletedCards: [],
  isLoading: false,
  error: null,

  // 获取所有卡片
  fetchAllCards: async () => {
    set({ isLoading: true, error: null })
    try {
      // 从本地存储获取卡片数据
      const cardsJson = localStorage.getItem('cards')
      const cards: Card[] = cardsJson ? JSON.parse(cardsJson) : []
      
      // 过滤出未删除的卡片
      const activeCards = cards.filter(card => !card.isDeleted)
      
      set({ cards: activeCards, isLoading: false })
    } catch (error) {
      set({ 
        error: error instanceof Error ? error.message : '获取卡片失败',
        isLoading: false 
      })
    }
  },

  // 获取已删除的卡片
  fetchDeletedCards: async () => {
    set({ isLoading: true, error: null })
    try {
      // 从本地存储获取卡片数据
      const cardsJson = localStorage.getItem('cards')
      const cards: Card[] = cardsJson ? JSON.parse(cardsJson) : []
      
      // 过滤出已删除的卡片
      const deletedCards = cards.filter(card => card.isDeleted)
      
      set({ deletedCards, isLoading: false })
    } catch (error) {
      set({ 
        error: error instanceof Error ? error.message : '获取已删除卡片失败',
        isLoading: false 
      })
    }
  },

  // 创建卡片
  createCard: async (cardData: Partial<Card>) => {
    try {
      const now = Date.now()
      const deviceId = useDeviceStore.getState().deviceId
      
      // 创建新卡片
      const newCard: Card = {
        id: uuidv4(),
        title: cardData.title || '新卡片',
        content: cardData.content || '',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
        lastModifiedDeviceId: deviceId
      }
      
      // 更新卡片列表
      const cards = [...get().cards, newCard]
      set({ cards })
      
      // 保存到本地存储
      const allCardsJson = localStorage.getItem('cards')
      const allCards: Card[] = allCardsJson ? JSON.parse(allCardsJson) : []
      localStorage.setItem('cards', JSON.stringify([...allCards, newCard]))
      
      return newCard
    } catch (error) {
      set({ error: error instanceof Error ? error.message : '创建卡片失败' })
      throw error
    }
  },

  // 更新卡片
  updateCard: async (cardData: Card) => {
    try {
      const now = Date.now()
      const deviceId = useDeviceStore.getState().deviceId
      
      // 更新卡片
      const updatedCard: Card = {
        ...cardData,
        updatedAt: now,
        lastModifiedDeviceId: deviceId
      }
      
      // 更新卡片列表
      const cards = get().cards.map(card => 
        card.id === updatedCard.id ? updatedCard : card
      )
      set({ cards })
      
      // 保存到本地存储
      const allCardsJson = localStorage.getItem('cards')
      const allCards: Card[] = allCardsJson ? JSON.parse(allCardsJson) : []
      const updatedAllCards = allCards.map(card => 
        card.id === updatedCard.id ? updatedCard : card
      )
      localStorage.setItem('cards', JSON.stringify(updatedAllCards))
      
      return updatedCard
    } catch (error) {
      set({ error: error instanceof Error ? error.message : '更新卡片失败' })
      throw error
    }
  },

  // 删除卡片（软删除）
  deleteCard: async (cardId: string) => {
    try {
      const now = Date.now()
      
      // 软删除卡片
      const cards = get().cards.map(card => 
        card.id === cardId ? { ...card, isDeleted: true, deletedAt: now } : card
      )
      set({ cards })
      
      // 保存到本地存储
      const allCardsJson = localStorage.getItem('cards')
      const allCards: Card[] = allCardsJson ? JSON.parse(allCardsJson) : []
      const updatedAllCards = allCards.map(card => 
        card.id === cardId ? { ...card, isDeleted: true, deletedAt: now } : card
      )
      localStorage.setItem('cards', JSON.stringify(updatedAllCards))
      
      // 更新已删除卡片列表
      get().fetchDeletedCards()
    } catch (error) {
      set({ error: error instanceof Error ? error.message : '删除卡片失败' })
      throw error
    }
  },

  // 恢复卡片
  restoreCard: async (cardId: string) => {
    try {
      // 恢复卡片
      const deletedCards = get().deletedCards.map(card => 
        card.id === cardId ? { ...card, isDeleted: false, deletedAt: undefined } : card
      )
      set({ deletedCards })
      
      // 保存到本地存储
      const allCardsJson = localStorage.getItem('cards')
      const allCards: Card[] = allCardsJson ? JSON.parse(allCardsJson) : []
      const updatedAllCards = allCards.map(card => 
        card.id === cardId ? { ...card, isDeleted: false, deletedAt: undefined } : card
      )
      localStorage.setItem('cards', JSON.stringify(updatedAllCards))
      
      // 更新卡片列表
      get().fetchAllCards()
    } catch (error) {
      set({ error: error instanceof Error ? error.message : '恢复卡片失败' })
      throw error
    }
  },

  // 清除错误
  clearError: () => {
    set({ error: null })
  },

  // 设置卡片列表
  setCards: (cards: Card[]) => {
    set({ cards })
  }
}))

export default useCardStore

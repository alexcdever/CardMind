// 导入状态管理库和类型定义
import { create } from 'zustand';
import { Card, CreateCardPayload, UpdateCardPayload } from '../types/card';

// API基础URL，从环境变量获取，如果未设置则使用默认值
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:9000/api/v1';

// 卡片状态管理接口定义
interface CardStore {
  cards: Card[];              // 卡片列表
  loading: boolean;           // 加载状态
  setCards: (cards: Card[]) => void;  // 设置卡片列表
  addCard: (card: CreateCardPayload) => Promise<Card>;  // 添加新卡片
  updateCard: (id: number, card: UpdateCardPayload) => Promise<Card>;  // 更新卡片
  deleteCard: (id: number) => Promise<void>;  // 删除卡片
  loadCards: () => Promise<void>;  // 加载所有卡片
}

// 创建卡片状态管理store
export const useCardStore = create<CardStore>((set, get) => ({
  cards: [],
  loading: false,
  setCards: (cards: Card[]) => set({ cards }),
  
  // 加载所有卡片
  loadCards: async () => {
    try {
      set({ loading: true });  // 设置加载状态
      const response = await fetch(`${API_BASE_URL}/cards`);
      if (!response.ok) {
        throw new Error(`Failed to load cards: ${response.status} ${response.statusText}`);
      }
      const cards = await response.json();
      set({ cards });  // 更新卡片列表
    } catch (error) {
      console.error('加载卡片失败:', error);
      throw error;
    } finally {
      set({ loading: false });  // 重置加载状态
    }
  },

  // 添加新卡片
  addCard: async (card: CreateCardPayload) => {
    try {
      set({ loading: true });
      const response = await fetch(`${API_BASE_URL}/cards`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(card),
      });
      if (!response.ok) {
        throw new Error(`添加卡片失败: ${response.status} ${response.statusText}`);
      }
      const newCard = await response.json();
      set(state => ({ cards: [...state.cards, newCard] }));  // 将新卡片添加到列表中
      return newCard;
    } catch (error) {
      console.error('添加卡片失败:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  // 更新卡片
  updateCard: async (id: number, card: UpdateCardPayload) => {
    try {
      set({ loading: true });
      const response = await fetch(`${API_BASE_URL}/cards/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(card),
      });
      if (!response.ok) {
        throw new Error(`更新卡片失败: ${response.status} ${response.statusText}`);
      }
      const updatedCard = await response.json();
      // 更新卡片列表中的对应卡片
      set(state => ({
        cards: state.cards.map(c => c.id === id ? updatedCard : c),
      }));
      return updatedCard;
    } catch (error) {
      console.error('更新卡片失败:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  // 删除卡片
  deleteCard: async (id: number) => {
    try {
      set({ loading: true });
      const response = await fetch(`${API_BASE_URL}/cards/${id}`, {
        method: 'DELETE',
      });
      if (!response.ok) {
        throw new Error(`删除卡片失败: ${response.status} ${response.statusText}`);
      }
      // 从列表中移除被删除的卡片
      set(state => ({
        cards: state.cards.filter(card => card.id !== id),
      }));
    } catch (error) {
      console.error('删除卡片失败:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },
}));
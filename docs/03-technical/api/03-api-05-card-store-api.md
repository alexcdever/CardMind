# cardStore API

## 1. 接口定义

```typescript
// src/stores/cardStore.ts
import { create } from 'zustand';
import { CardService, Card, CardCreateParams, CardUpdateParams } from '../services/card/CardService';

/**
 * 卡片状态接口
 */
export interface CardState {
  /**
   * 所有卡片列表
   */
  cards: Card[];
  
  /**
   * 收藏卡片列表
   */
  starredCards: Card[];
  
  /**
   * 当前选中的卡片
   */
  selectedCard: Card | null;
  
  /**
   * 搜索关键词
   */
  searchQuery: string;
  
  /**
   * 过滤标签
   */
  filterTag: string | null;
  
  /**
   * 是否正在加载
   */
  isLoading: boolean;
  
  /**
   * 错误信息
   */
  error: string | null;
  
  /**
   * 初始化卡片列表
   */
  initialize: () => Promise<void>;
  
  /**
   * 创建新卡片
   * @param params 卡片创建参数
   * @returns 创建的卡片
   */
  createCard: (params: CardCreateParams) => Promise<Card>;
  
  /**
   * 更新卡片
   * @param id 卡片ID
   * @param params 卡片更新参数
   * @returns 更新后的卡片
   */
  updateCard: (id: string, params: CardUpdateParams) => Promise<Card | null>;
  
  /**
   * 删除卡片
   * @param id 卡片ID
   * @returns 删除结果
   */
  deleteCard: (id: string) => Promise<boolean>;
  
  /**
   * 选择卡片
   * @param id 卡片ID
   */
  selectCard: (id: string | null) => void;
  
  /**
   * 设置搜索查询
   * @param query 搜索关键词
   */
  setSearchQuery: (query: string) => void;
  
  /**
   * 设置过滤标签
   * @param tag 标签名称
   */
  setFilterTag: (tag: string | null) => void;
  
  /**
   * 获取搜索和过滤后的卡片
   * @returns 过滤后的卡片列表
   */
  getFilteredCards: () => Card[];
  
  /**
   * 刷新卡片列表
   */
  refreshCards: () => Promise<void>;
  
  /**
   * 清除错误信息
   */
  clearError: () => void;
}

/**
 * 创建卡片状态存储
 * @param cardService 卡片服务实例
 * @returns 卡片状态存储
 */
export const createCardStore = (cardService: CardService) => 
  create<CardState>((set, get) => ({
    cards: [],
    starredCards: [],
    selectedCard: null,
    searchQuery: '',
    filterTag: null,
    isLoading: false,
    error: null,
    
    initialize: async () => {
      set({ isLoading: true, error: null });
      try {
        await get().refreshCards();
        set({ isLoading: false });
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '卡片初始化失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    createCard: async (params: CardCreateParams) => {
      set({ isLoading: true, error: null });
      try {
        const newCard = await cardService.createCard(params);
        
        set((state) => {
          const updatedCards = [...state.cards, newCard];
          const updatedStarredCards = newCard.isStarred 
            ? [...state.starredCards, newCard]
            : state.starredCards;
          
          return {
            cards: updatedCards,
            starredCards: updatedStarredCards,
            selectedCard: newCard,
            isLoading: false
          };
        });
        
        return newCard;
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '创建卡片失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    updateCard: async (id: string, params: CardUpdateParams) => {
      set({ isLoading: true, error: null });
      try {
        const updatedCard = await cardService.updateCard(id, params);
        
        if (updatedCard) {
          set((state) => {
            const updatedCards = state.cards.map(card => 
              card.id === id ? updatedCard : card
            );
            
            // Update starred cards list
            const wasStarred = state.starredCards.some(card => card.id === id);
            let updatedStarredCards = [...state.starredCards];
            
            if (updatedCard.isStarred && !wasStarred) {
              // Add to starred if newly starred
              updatedStarredCards.push(updatedCard);
            } else if (!updatedCard.isStarred && wasStarred) {
              // Remove from starred if unstarred
              updatedStarredCards = updatedStarredCards.filter(card => card.id !== id);
            } else if (updatedCard.isStarred && wasStarred) {
              // Update in starred if already starred
              updatedStarredCards = updatedStarredCards.map(card => 
                card.id === id ? updatedCard : card
              );
            }
            
            // Update selected card if it's the one being updated
            const updatedSelectedCard = state.selectedCard?.id === id 
              ? updatedCard 
              : state.selectedCard;
            
            return {
              cards: updatedCards,
              starredCards: updatedStarredCards,
              selectedCard: updatedSelectedCard,
              isLoading: false
            };
          });
        }
        
        return updatedCard;
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '更新卡片失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    deleteCard: async (id: string) => {
      set({ isLoading: true, error: null });
      try {
        const success = await cardService.deleteCard(id);
        
        if (success) {
          set((state) => {
            // Remove from cards list
            const updatedCards = state.cards.filter(card => card.id !== id);
            
            // Remove from starred cards list
            const updatedStarredCards = state.starredCards.filter(card => card.id !== id);
            
            // Clear selected card if it's the one being deleted
            const updatedSelectedCard = state.selectedCard?.id === id 
              ? null 
              : state.selectedCard;
            
            return {
              cards: updatedCards,
              starredCards: updatedStarredCards,
              selectedCard: updatedSelectedCard,
              isLoading: false
            };
          });
        }
        
        return success;
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '删除卡片失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    selectCard: (id: string | null) => {
      if (id === null) {
        set({ selectedCard: null });
        return;
      }
      
      const card = get().cards.find(card => card.id === id);
      set({ selectedCard: card || null });
    },
    
    setSearchQuery: (query: string) => {
      set({ searchQuery: query });
    },
    
    setFilterTag: (tag: string | null) => {
      set({ filterTag: tag });
    },
    
    getFilteredCards: () => {
      const { cards, searchQuery, filterTag } = get();
      
      return cards.filter(card => {
        // Apply tag filter
        if (filterTag && !card.tags.includes(filterTag)) {
          return false;
        }
        
        // Apply search query
        if (searchQuery) {
          const query = searchQuery.toLowerCase();
          return (
            card.title.toLowerCase().includes(query) ||
            card.content.toLowerCase().includes(query) ||
            card.tags.some(tag => tag.toLowerCase().includes(query))
          );
        }
        
        return true;
      }).sort((a, b) => b.updatedAt - a.updatedAt); // Sort by most recently updated
    },
    
    refreshCards: async () => {
      try {
        const allCards = await cardService.getAllCards();
        const starredCards = allCards.filter(card => card.isStarred);
        
        set({
          cards: allCards,
          starredCards,
          // Don't change selectedCard if it still exists in the new list
          selectedCard: (state: CardState) => {
            if (!state.selectedCard) return null;
            return allCards.find(card => card.id === state.selectedCard?.id) || null;
          }
        });
      } catch (error) {
        set({ 
          error: error instanceof Error ? error.message : '刷新卡片列表失败',
          isLoading: false 
        });
        throw error;
      }
    },
    
    clearError: () => set({ error: null }),
  }));

/**
 * 卡片状态存储类型
 */
export type CardStore = ReturnType<typeof createCardStore>;
```

## 2. 单元测试

```typescript
// src/stores/cardStore.test.ts
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { createCardStore, CardState } from './cardStore';
import { CardService, Card, CardCreateParams, CardUpdateParams } from '../services/card/CardService';

// Mock the CardService
const mockCardService = {
  createCard: jest.fn(),
  getAllCards: jest.fn(),
  getCard: jest.fn(),
  updateCard: jest.fn(),
  deleteCard: jest.fn(),
  searchCards: jest.fn(),
  getStarredCards: jest.fn(),
  getCardsByTag: jest.fn(),
} as unknown as CardService;

// Mock card data
const mockCards: Card[] = [
  {
    id: 'card-1',
    title: 'First Card',
    content: 'This is the first card content',
    createdAt: Date.now() - 86400000, // 1 day ago
    updatedAt: Date.now() - 3600000,  // 1 hour ago
    createdBy: 'device-1',
    lastUpdatedBy: 'device-1',
    tags: ['work', 'important'],
    isStarred: true,
  },
  {
    id: 'card-2',
    title: 'Second Card',
    content: 'This is the second card content',
    createdAt: Date.now() - 172800000, // 2 days ago
    updatedAt: Date.now() - 7200000,   // 2 hours ago
    createdBy: 'device-2',
    lastUpdatedBy: 'device-2',
    tags: ['personal'],
    isStarred: false,
  },
  {
    id: 'card-3',
    title: 'Third Card',
    content: 'This is the third card content',
    createdAt: Date.now() - 259200000, // 3 days ago
    updatedAt: Date.now() - 10800000,  // 3 hours ago
    createdBy: 'device-1',
    lastUpdatedBy: 'device-2',
    tags: ['work', 'meeting'],
    isStarred: true,
  },
];

describe('cardStore', () => {
  let cardStore: any;
  
  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();
    
    // Setup default mock return values
    (mockCardService.getAllCards as jest.Mock).mockResolvedValue(mockCards);
    
    // Create a new store instance for each test
    cardStore = createCardStore(mockCardService);
  });

  describe('initial state', () => {
    it('should initialize with correct default values', () => {
      const state = cardStore.getState();
      
      expect(state.cards).toEqual([]);
      expect(state.starredCards).toEqual([]);
      expect(state.selectedCard).toBeNull();
      expect(state.searchQuery).toBe('');
      expect(state.filterTag).toBeNull();
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
    });
  });

  describe('initialize', () => {
    it('should initialize card data successfully', async () => {
      // Call the method
      await cardStore.getState().initialize();
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.cards).toEqual(mockCards);
      expect(state.starredCards.length).toBe(2); // Two cards are starred in mock data
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockCardService.getAllCards).toHaveBeenCalled();
    });

    it('should handle errors during initialization', async () => {
      const errorMessage = 'Initialization error';
      
      // Setup mock to throw error
      (mockCardService.getAllCards as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(cardStore.getState().initialize()).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = cardStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('createCard', () => {
    it('should create a new card successfully', async () => {
      const createParams: CardCreateParams = {
        title: 'New Card',
        content: 'New card content',
        tags: ['new', 'important'],
      };
      
      const newCard: Card = {
        id: 'card-4',
        ...createParams,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'current-device',
        lastUpdatedBy: 'current-device',
        isStarred: false,
      };
      
      // Setup mock
      (mockCardService.createCard as jest.Mock).mockResolvedValue(newCard);
      
      // Call the method
      const result = await cardStore.getState().createCard(createParams);
      
      // Verify result
      expect(result).toEqual(newCard);
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.cards.length).toBe(1);
      expect(state.cards[0]).toEqual(newCard);
      expect(state.selectedCard).toEqual(newCard);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockCardService.createCard).toHaveBeenCalledWith(createParams);
    });

    it('should handle errors during card creation', async () => {
      const createParams: CardCreateParams = {
        title: 'New Card',
        content: 'Content',
      };
      
      const errorMessage = 'Creation error';
      
      // Setup mock to throw error
      (mockCardService.createCard as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(cardStore.getState().createCard(createParams)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = cardStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('updateCard', () => {
    beforeEach(async () => {
      // Initialize with mock data first
      await cardStore.getState().initialize();
    });

    it('should update an existing card successfully', async () => {
      const cardId = 'card-1';
      const updateParams: CardUpdateParams = {
        title: 'Updated First Card',
        isStarred: false, // Was true before
      };
      
      const originalCard = mockCards.find(card => card.id === cardId) as Card;
      const updatedCard: Card = {
        ...originalCard,
        ...updateParams,
        updatedAt: Date.now(),
        lastUpdatedBy: 'current-device',
      };
      
      // Setup mock
      (mockCardService.updateCard as jest.Mock).mockResolvedValue(updatedCard);
      
      // Select the card first
      cardStore.getState().selectCard(cardId);
      
      // Call the method
      const result = await cardStore.getState().updateCard(cardId, updateParams);
      
      // Verify result
      expect(result).toEqual(updatedCard);
      
      // Verify state was updated
      const state = cardStore.getState();
      const cardInStore = state.cards.find((card: Card) => card.id === cardId);
      
      expect(cardInStore).toEqual(updatedCard);
      expect(state.selectedCard).toEqual(updatedCard);
      
      // Should be removed from starred cards since isStarred changed to false
      expect(state.starredCards.some((card: Card) => card.id === cardId)).toBe(false);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockCardService.updateCard).toHaveBeenCalledWith(cardId, updateParams);
    });

    it('should handle updates to non-existent cards', async () => {
      const nonExistentCardId = 'non-existent-card';
      const updateParams: CardUpdateParams = {
        title: 'Updated Title',
      };
      
      // Setup mock to return null (card not found)
      (mockCardService.updateCard as jest.Mock).mockResolvedValue(null);
      
      // Call the method
      const result = await cardStore.getState().updateCard(nonExistentCardId, updateParams);
      
      // Verify result
      expect(result).toBeNull();
      
      // Verify state wasn't changed
      const state = cardStore.getState();
      expect(state.cards.length).toBe(3); // Original number of mock cards
      expect(state.isLoading).toBe(false);
    });

    it('should handle errors during card update', async () => {
      const cardId = 'card-1';
      const updateParams: CardUpdateParams = {
        title: 'New Title',
      };
      
      const errorMessage = 'Update error';
      
      // Setup mock to throw error
      (mockCardService.updateCard as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(cardStore.getState().updateCard(cardId, updateParams)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = cardStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('deleteCard', () => {
    beforeEach(async () => {
      // Initialize with mock data first
      await cardStore.getState().initialize();
    });

    it('should delete an existing card successfully', async () => {
      const cardId = 'card-1';
      
      // Setup mock
      (mockCardService.deleteCard as jest.Mock).mockResolvedValue(true);
      
      // Select the card first
      cardStore.getState().selectCard(cardId);
      
      // Call the method
      const result = await cardStore.getState().deleteCard(cardId);
      
      // Verify result
      expect(result).toBe(true);
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.cards.length).toBe(2); // Original 3 minus 1 deleted
      expect(state.cards.some((card: Card) => card.id === cardId)).toBe(false);
      expect(state.starredCards.some((card: Card) => card.id === cardId)).toBe(false);
      expect(state.selectedCard).toBeNull(); // Selected card should be cleared
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
      
      // Verify service method was called
      expect(mockCardService.deleteCard).toHaveBeenCalledWith(cardId);
    });

    it('should handle deletion of non-existent cards', async () => {
      const nonExistentCardId = 'non-existent-card';
      
      // Setup mock to return false (deletion failed/not found)
      (mockCardService.deleteCard as jest.Mock).mockResolvedValue(false);
      
      // Call the method
      const result = await cardStore.getState().deleteCard(nonExistentCardId);
      
      // Verify result
      expect(result).toBe(false);
      
      // Verify state wasn't changed
      const state = cardStore.getState();
      expect(state.cards.length).toBe(3); // Original number of mock cards
      expect(state.isLoading).toBe(false);
    });

    it('should handle errors during card deletion', async () => {
      const cardId = 'card-1';
      const errorMessage = 'Deletion error';
      
      // Setup mock to throw error
      (mockCardService.deleteCard as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(cardStore.getState().deleteCard(cardId)).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = cardStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('selectCard', () => {
    beforeEach(async () => {
      // Initialize with mock data first
      await cardStore.getState().initialize();
    });

    it('should select an existing card', () => {
      const cardId = 'card-1';
      
      // Call the method
      cardStore.getState().selectCard(cardId);
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.selectedCard?.id).toBe(cardId);
    });

    it('should clear selection when passing null', () => {
      // First select a card
      cardStore.getState().selectCard('card-1');
      
      // Then clear selection
      cardStore.getState().selectCard(null);
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.selectedCard).toBeNull();
    });

    it('should handle selection of non-existent cards', () => {
      const nonExistentCardId = 'non-existent-card';
      
      // Call the method
      cardStore.getState().selectCard(nonExistentCardId);
      
      // Verify selection is null
      const state = cardStore.getState();
      expect(state.selectedCard).toBeNull();
    });
  });

  describe('search and filter functionality', () => {
    beforeEach(async () => {
      // Initialize with mock data first
      await cardStore.getState().initialize();
    });

    it('should set search query correctly', () => {
      const query = 'search term';
      
      // Call the method
      cardStore.getState().setSearchQuery(query);
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.searchQuery).toBe(query);
    });

    it('should set filter tag correctly', () => {
      const tag = 'work';
      
      // Call the method
      cardStore.getState().setFilterTag(tag);
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.filterTag).toBe(tag);
    });

    it('should clear filter tag when passing null', () => {
      // First set a filter tag
      cardStore.getState().setFilterTag('work');
      
      // Then clear it
      cardStore.getState().setFilterTag(null);
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.filterTag).toBeNull();
    });

    it('should filter cards by search query', () => {
      // Set a search query that matches one card
      cardStore.getState().setSearchQuery('second');
      
      // Get filtered cards
      const filteredCards = cardStore.getState().getFilteredCards();
      
      // Should return only the card with 'second' in title
      expect(filteredCards.length).toBe(1);
      expect(filteredCards[0].id).toBe('card-2');
    });

    it('should filter cards by tag', () => {
      // Set a filter tag
      cardStore.getState().setFilterTag('work');
      
      // Get filtered cards
      const filteredCards = cardStore.getState().getFilteredCards();
      
      // Should return only cards with 'work' tag
      expect(filteredCards.length).toBe(2);
      expect(filteredCards.every((card: Card) => card.tags.includes('work'))).toBe(true);
    });

    it('should apply both search and tag filters together', () => {
      // Set both search and tag filters
      cardStore.getState().setSearchQuery('first');
      cardStore.getState().setFilterTag('work');
      
      // Get filtered cards
      const filteredCards = cardStore.getState().getFilteredCards();
      
      // Should return only the card that matches both filters
      expect(filteredCards.length).toBe(1);
      expect(filteredCards[0].id).toBe('card-1');
    });

    it('should sort filtered cards by updated time (newest first)', () => {
      // Clear any filters first
      cardStore.getState().setSearchQuery('');
      cardStore.getState().setFilterTag(null);
      
      // Get filtered cards
      const filteredCards = cardStore.getState().getFilteredCards();
      
      // Check that they're sorted by updatedAt in descending order
      for (let i = 0; i < filteredCards.length - 1; i++) {
        expect(filteredCards[i].updatedAt).toBeGreaterThanOrEqual(filteredCards[i + 1].updatedAt);
      }
    });
  });

  describe('refreshCards', () => {
    it('should refresh the card list successfully', async () => {
      // Add a new card to the mock data
      const newMockCards = [
        ...mockCards,
        {
          id: 'card-4',
          title: 'Fourth Card',
          content: 'New card added',
          createdAt: Date.now(),
          updatedAt: Date.now(),
          createdBy: 'current-device',
          lastUpdatedBy: 'current-device',
          tags: ['new'],
          isStarred: false,
        },
      ];
      
      // Update mock to return new data
      (mockCardService.getAllCards as jest.Mock).mockResolvedValue(newMockCards);
      
      // Call the method
      await cardStore.getState().refreshCards();
      
      // Verify state was updated
      const state = cardStore.getState();
      expect(state.cards.length).toBe(4);
      expect(state.cards.some((card: Card) => card.id === 'card-4')).toBe(true);
    });

    it('should handle errors during card refresh', async () => {
      const errorMessage = 'Refresh error';
      
      // Setup mock to throw error
      (mockCardService.getAllCards as jest.Mock).mockRejectedValue(new Error(errorMessage));
      
      // Call the method and expect it to throw
      await expect(cardStore.getState().refreshCards()).rejects.toThrow(errorMessage);
      
      // Verify error state was set
      const state = cardStore.getState();
      expect(state.error).toBe(errorMessage);
      expect(state.isLoading).toBe(false);
    });
  });

  describe('clearError', () => {
    it('should clear any existing error', () => {
      // Set an error state
      const errorMessage = 'Test error';
      cardStore.setState({ error: errorMessage });
      
      // Call the method
      cardStore.getState().clearError();
      
      // Verify error was cleared
      const state = cardStore.getState();
      expect(state.error).toBeNull();
    });
  });
});
```

## 导航与引用

- [API测试设计文档索引](../api-testing-design-index.md)
- [认证Store API](auth-store-api.md)
- [设备Store API](device-store-api.md)
- [同步Store API](sync-store-api.md)
- [系统测试计划](../testing/system-testing-plan.md)
- [回归测试计划](../testing/regression-testing-plan.md)
- [用户界面测试](../testing/ui-testing.md)
- [测试工具与技术](../testing/testing-tools.md)
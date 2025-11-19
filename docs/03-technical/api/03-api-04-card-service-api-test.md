# CardService API单元测试

> 本文档包含CardMind系统卡片服务接口的单元测试实现。

## 目录
- [1. 单元测试](#1-单元测试)

## 1. 单元测试

```typescript
// src/services/card/CardService.test.ts
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { CardServiceImpl } from './CardServiceImpl';
import { IDatabaseService } from '../database/DatabaseService';
import { DeviceServiceImpl } from '../device/DeviceServiceImpl';
import { SyncServiceImpl } from '../sync/SyncServiceImpl';
import { EncryptionServiceImpl } from '../encryption/EncryptionServiceImpl';

// Mock dependencies
jest.mock('../database/DatabaseService');
jest.mock('../device/DeviceServiceImpl');
jest.mock('../sync/SyncServiceImpl');
jest.mock('../encryption/EncryptionServiceImpl');

const mockDatabaseService = {
  get: jest.fn(),
  set: jest.fn(),
  remove: jest.fn(),
  getAll: jest.fn(),
  query: jest.fn(),
} as unknown as IDatabaseService;

const mockDeviceService = {
  getCurrentDeviceInfo: jest.fn().mockReturnValue({
    id: 'current-device-id',
    name: 'Test Device',
    type: 'desktop',
    platform: 'windows',
    appVersion: '1.0.0',
    joinedAt: Date.now(),
    lastActiveAt: Date.now(),
    isOnline: true,
  }),
} as unknown as DeviceServiceImpl;

const mockSyncService = {
  syncCardUpdate: jest.fn(),
} as unknown as SyncServiceImpl;

const mockEncryptionService = {
  encrypt: jest.fn((data) => data), // Identity function for testing
  decrypt: jest.fn((data) => data), // Identity function for testing
} as unknown as EncryptionServiceImpl;

describe('CardService', () => {
  let cardService: CardServiceImpl;
  
  beforeEach(() => {
    cardService = new CardServiceImpl(
      mockDatabaseService,
      mockDeviceService,
      mockSyncService,
      mockEncryptionService
    );
    jest.clearAllMocks();
  });

  describe('createCard', () => {
    it('should create a new card successfully', async () => {
      const cardParams = {
        title: 'Test Card',
        content: 'Test Content',
        tags: ['test', 'sample'],
      };
      
      const createdCard = await cardService.createCard(cardParams);
      
      // Verify the returned card has all required properties
      expect(createdCard).toHaveProperty('id');
      expect(createdCard.title).toBe(cardParams.title);
      expect(createdCard.content).toBe(cardParams.content);
      expect(createdCard.tags).toEqual(cardParams.tags);
      expect(createdCard.createdBy).toBe('current-device-id');
      expect(createdCard.lastUpdatedBy).toBe('current-device-id');
      expect(createdCard.isStarred).toBe(false);
      
      // Verify database operation and sync were called
      expect(mockDatabaseService.set).toHaveBeenCalled();
      expect(mockSyncService.syncCardUpdate).toHaveBeenCalled();
    });

    it('should create a card with default values for optional fields', async () => {
      const cardParams = {
        title: 'Minimal Card',
        content: 'Minimal Content',
      };
      
      const createdCard = await cardService.createCard(cardParams);
      
      // Default tags should be empty array
      expect(createdCard.tags).toEqual([]);
    });

    it('should reject creating a card with empty title', async () => {
      const cardParams = {
        title: '',
        content: 'Content with no title',
      };
      
      await expect(cardService.createCard(cardParams)).rejects.toThrow();
    });
  });

  describe('getAllCards', () => {
    it('should return all cards from the database', async () => {
      const mockCards = [
        {
          id: 'card-1',
          title: 'Card 1',
          content: 'Content 1',
          createdAt: Date.now() - 3600000,
          updatedAt: Date.now() - 3600000,
          createdBy: 'device-1',
          lastUpdatedBy: 'device-1',
          tags: ['tag1'],
          isStarred: false,
        },
        {
          id: 'card-2',
          title: 'Card 2',
          content: 'Content 2',
          createdAt: Date.now() - 7200000,
          updatedAt: Date.now() - 7200000,
          createdBy: 'device-2',
          lastUpdatedBy: 'device-2',
          tags: ['tag2'],
          isStarred: true,
        },
      ];
      
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue(mockCards);
      
      const cards = await cardService.getAllCards();
      
      expect(cards.length).toBe(2);
      expect(cards[0].id).toBe('card-1');
      expect(cards[1].id).toBe('card-2');
    });

    it('should return empty array when no cards exist', async () => {
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue([]);
      
      const cards = await cardService.getAllCards();
      
      expect(Array.isArray(cards)).toBe(true);
      expect(cards.length).toBe(0);
    });
  });

  describe('getCard', () => {
    it('should return a card by its ID', async () => {
      const mockCard = {
        id: 'test-card-id',
        title: 'Test Card',
        content: 'Test Content',
        createdAt: Date.now() - 3600000,
        updatedAt: Date.now() - 3600000,
        createdBy: 'device-1',
        lastUpdatedBy: 'device-1',
        tags: ['test'],
        isStarred: false,
      };
      
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(mockCard);
      
      const card = await cardService.getCard('test-card-id');
      
      expect(card).not.toBeNull();
      expect(card?.id).toBe('test-card-id');
      expect(card?.title).toBe('Test Card');
    });

    it('should return null when card does not exist', async () => {
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(null);
      
      const card = await cardService.getCard('non-existent-id');
      
      expect(card).toBeNull();
    });
  });

  describe('updateCard', () => {
    it('should update an existing card successfully', async () => {
      const existingCard = {
        id: 'test-card-id',
        title: 'Original Title',
        content: 'Original Content',
        createdAt: Date.now() - 3600000,
        updatedAt: Date.now() - 3600000,
        createdBy: 'device-1',
        lastUpdatedBy: 'device-1',
        tags: ['tag1'],
        isStarred: false,
      };
      
      const updateParams = {
        title: 'Updated Title',
        isStarred: true,
      };
      
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(existingCard);
      
      const updatedCard = await cardService.updateCard('test-card-id', updateParams);
      
      expect(updatedCard).not.toBeNull();
      expect(updatedCard?.title).toBe('Updated Title');
      expect(updatedCard?.isStarred).toBe(true);
      expect(updatedCard?.content).toBe('Original Content'); // Unchanged property
      expect(updatedCard?.lastUpdatedBy).toBe('current-device-id');
      expect(updatedCard?.updatedAt).toBeGreaterThan(existingCard.updatedAt);
      
      // Verify database operation and sync were called
      expect(mockDatabaseService.set).toHaveBeenCalled();
      expect(mockSyncService.syncCardUpdate).toHaveBeenCalled();
    });

    it('should return null when updating a non-existent card', async () => {
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(null);
      
      const updateParams = {
        title: 'New Title',
      };
      
      const updatedCard = await cardService.updateCard('non-existent-id', updateParams);
      
      expect(updatedCard).toBeNull();
      expect(mockDatabaseService.set).not.toHaveBeenCalled();
    });
  });

  describe('deleteCard', () => {
    it('should delete an existing card successfully', async () => {
      const existingCard = {
        id: 'test-card-id',
        title: 'Test Card',
        content: 'Test Content',
        createdAt: Date.now() - 3600000,
        updatedAt: Date.now() - 3600000,
        createdBy: 'device-1',
        lastUpdatedBy: 'device-1',
        tags: ['test'],
        isStarred: false,
      };
      
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(existingCard);
      
      const result = await cardService.deleteCard('test-card-id');
      
      expect(result).toBe(true);
      expect(mockDatabaseService.remove).toHaveBeenCalledWith('card-test-card-id');
      expect(mockSyncService.syncCardUpdate).toHaveBeenCalled();
    });

    it('should return false when deleting a non-existent card', async () => {
      (mockDatabaseService.get as jest.Mock).mockResolvedValue(null);
      
      const result = await cardService.deleteCard('non-existent-id');
      
      expect(result).toBe(false);
      expect(mockDatabaseService.remove).not.toHaveBeenCalled();
    });
  });

  describe('searchCards', () => {
    it('should return cards matching the search query', async () => {
      const mockCards = [
        {
          id: 'card-1',
          title: 'Search Test',
          content: 'This contains the search term',
          createdAt: Date.now() - 3600000,
          updatedAt: Date.now() - 3600000,
          createdBy: 'device-1',
          lastUpdatedBy: 'device-1',
          tags: ['search'],
          isStarred: false,
        },
      ];
      
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue(mockCards);
      
      const results = await cardService.searchCards('search');
      
      expect(results.length).toBe(1);
      expect(results[0].id).toBe('card-1');
    });

    it('should return empty array when no cards match the query', async () => {
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue([]);
      
      const results = await cardService.searchCards('nonexistent');
      
      expect(results.length).toBe(0);
    });
  });

  describe('getStarredCards', () => {
    it('should return only starred cards', async () => {
      const mockCards = [
        {
          id: 'card-1',
          title: 'Starred Card',
          content: 'Content 1',
          createdAt: Date.now() - 3600000,
          updatedAt: Date.now() - 3600000,
          createdBy: 'device-1',
          lastUpdatedBy: 'device-1',
          tags: ['tag1'],
          isStarred: true,
        },
        {
          id: 'card-2',
          title: 'Non-starred Card',
          content: 'Content 2',
          createdAt: Date.now() - 7200000,
          updatedAt: Date.now() - 7200000,
          createdBy: 'device-2',
          lastUpdatedBy: 'device-2',
          tags: ['tag2'],
          isStarred: false,
        },
      ];
      
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue(mockCards);
      
      const starredCards = await cardService.getStarredCards();
      
      expect(starredCards.length).toBe(1);
      expect(starredCards[0].isStarred).toBe(true);
    });
  });

  describe('getCardsByTag', () => {
    it('should return cards with the specified tag', async () => {
      const mockCards = [
        {
          id: 'card-1',
          title: 'Card with tag',
          content: 'Content 1',
          createdAt: Date.now() - 3600000,
          updatedAt: Date.now() - 3600000,
          createdBy: 'device-1',
          lastUpdatedBy: 'device-1',
          tags: ['test', 'important'],
          isStarred: false,
        },
        {
          id: 'card-2',
          title: 'Another card with tag',
          content: 'Content 2',
          createdAt: Date.now() - 7200000,
          updatedAt: Date.now() - 7200000,
          createdBy: 'device-2',
          lastUpdatedBy: 'device-2',
          tags: ['test', 'secondary'],
          isStarred: true,
        },
      ];
      
      (mockDatabaseService.getAll as jest.Mock).mockResolvedValue(mockCards);
      
      const taggedCards = await cardService.getCardsByTag('test');
      
      expect(taggedCards.length).toBe(2);
      expect(taggedCards.every(card => card.tags.includes('test'))).toBe(true);
    });
  });
});
```

## 相关文档

- [CardService API接口设计](card-service-api.md)
- [AuthService API接口设计与单元测试](auth-service-api.md)
- [DeviceService API接口设计与单元测试](device-service-api.md)
- [EncryptionService API接口设计与单元测试](encryption-service-api.md)
- [SyncService API接口设计与单元测试](sync-service-api.md)

[返回API测试设计文档索引](../api-testing-design-index.md)
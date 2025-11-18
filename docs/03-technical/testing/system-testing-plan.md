# 系统测试计划

本文档详细描述了CardMind应用的系统测试计划，包括数据存储测试和同步功能测试。

## 目录

- [1. 数据存储测试](#1-数据存储测试)
  - [1.1 测试目标](#11-测试目标)
  - [1.2 测试场景](#12-测试场景)
  - [1.3 测试脚本示例](#13-测试脚本示例)
- [2. 同步功能测试](#2-同步功能测试)
  - [2.1 测试目标](#21-测试目标)
  - [2.2 测试场景](#22-测试场景)
  - [2.3 测试脚本示例](#23-测试脚本示例)

## 1. 数据存储测试

### 1.1 测试目标

- 验证应用能够正确存储和检索卡片数据
- 确保数据持久化在各种场景下可靠工作
- 测试存储限制和边界条件
- 验证数据一致性和完整性

### 1.2 测试场景

1. **基本存储操作**
   - 创建新卡片并验证存储
   - 读取已有卡片数据
   - 更新卡片数据并验证更改
   - 删除卡片并验证移除

2. **批量操作测试**
   - 批量创建多张卡片
   - 批量更新多张卡片
   - 批量删除多张卡片

3. **存储边界测试**
   - 存储大量卡片数据
   - 存储大尺寸卡片内容
   - 测试空数据和特殊字符处理

4. **异常场景测试**
   - 存储空间不足时的处理
   - 存储操作中断时的恢复
   - 存储数据损坏场景恢复

### 1.3 测试脚本示例

```typescript
// src/tests/system/storage.test.ts
import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import { CardRepository } from '../../repositories/card/CardRepository';
import { IndexedDbStorage } from '../../storage/IndexedDbStorage';
import { Card, CardContent, CardType } from '../../models/card/Card';

describe('数据存储系统测试', () => {
  let storage: IndexedDbStorage;
  let cardRepository: CardRepository;
  
  beforeEach(async () => {
    // 初始化存储和仓库
    storage = new IndexedDbStorage('CardMindTest');
    await storage.initialize();
    cardRepository = new CardRepository(storage);
    
    // 清除测试数据
    await cardRepository.clearAllCards();
  });
  
  afterEach(async () => {
    // 清理资源
    await storage.close();
  });
  
  describe('基本存储操作', () => {
    it('应该正确创建和检索单张卡片', async () => {
      // 创建测试卡片
      const testCard: Card = {
        id: 'test-card-1',
        title: '测试卡片1',
        type: CardType.TEXT,
        content: {
          text: '这是测试卡片内容',
          format: 'plain'
        } as CardContent,
        tags: ['测试', '示例'],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'test-user',
        lastModifiedBy: 'test-user'
      };
      
      // 存储卡片
      await cardRepository.saveCard(testCard);
      
      // 检索卡片
      const retrievedCard = await cardRepository.getCardById('test-card-1');
      
      // 验证结果
      expect(retrievedCard).not.toBeNull();
      expect(retrievedCard?.id).toBe('test-card-1');
      expect(retrievedCard?.title).toBe('测试卡片1');
      expect(retrievedCard?.content.text).toBe('这是测试卡片内容');
      expect(retrievedCard?.tags).toEqual(['测试', '示例']);
    });
    
    it('应该正确更新已存在的卡片', async () => {
      // 先创建卡片
      const initialCard: Card = {
        id: 'test-card-update',
        title: '更新前的标题',
        type: CardType.TEXT,
        content: { text: '更新前的内容' } as CardContent,
        tags: [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'test-user',
        lastModifiedBy: 'test-user'
      };
      
      await cardRepository.saveCard(initialCard);
      
      // 更新卡片
      const updatedCard: Card = {
        ...initialCard,
        title: '更新后的标题',
        content: { text: '更新后的内容' } as CardContent,
        tags: ['已更新'],
        updatedAt: Date.now()
      };
      
      await cardRepository.saveCard(updatedCard);
      
      // 检索并验证更新
      const retrievedCard = await cardRepository.getCardById('test-card-update');
      
      expect(retrievedCard).not.toBeNull();
      expect(retrievedCard?.title).toBe('更新后的标题');
      expect(retrievedCard?.content.text).toBe('更新后的内容');
      expect(retrievedCard?.tags).toEqual(['已更新']);
      expect(retrievedCard?.updatedAt).toBeGreaterThan(initialCard.updatedAt);
    });
    
    it('应该正确删除卡片', async () => {
      // 创建要删除的卡片
      const deleteCard: Card = {
        id: 'test-card-delete',
        title: '将要被删除的卡片',
        type: CardType.TEXT,
        content: { text: '删除测试' } as CardContent,
        tags: ['删除'],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'test-user',
        lastModifiedBy: 'test-user'
      };
      
      await cardRepository.saveCard(deleteCard);
      
      // 验证创建成功
      let retrievedCard = await cardRepository.getCardById('test-card-delete');
      expect(retrievedCard).not.toBeNull();
      
      // 删除卡片
      await cardRepository.deleteCard('test-card-delete');
      
      // 验证删除成功
      retrievedCard = await cardRepository.getCardById('test-card-delete');
      expect(retrievedCard).toBeNull();
    });
  });
  
  describe('批量操作测试', () => {
    it('应该正确批量创建多张卡片', async () => {
      // 创建5张测试卡片
      const testCards: Card[] = Array.from({ length: 5 }, (_, index) => ({
        id: `batch-card-${index + 1}`,
        title: `批量测试卡片${index + 1}`,
        type: CardType.TEXT,
        content: { text: `批量测试内容${index + 1}` } as CardContent,
        tags: ['批量测试'],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'test-user',
        lastModifiedBy: 'test-user'
      }));
      
      // 批量保存
      for (const card of testCards) {
        await cardRepository.saveCard(card);
      }
      
      // 获取所有卡片
      const allCards = await cardRepository.getAllCards();
      
      // 验证结果
      expect(allCards.length).toBe(5);
      
      // 验证每张卡片都正确保存
      for (let i = 0; i < 5; i++) {
        const cardId = `batch-card-${i + 1}`;
        const savedCard = allCards.find(card => card.id === cardId);
        expect(savedCard).not.toBeUndefined();
        expect(savedCard?.title).toBe(`批量测试卡片${i + 1}`);
      }
    });
  });
  
  describe('存储边界测试', () => {
    it('应该能够存储大量卡片数据', async () => {
      // 创建100张卡片 - 在实际测试中可能需要调整数量
      const cardCount = 100;
      const testCards: Card[] = Array.from({ length: cardCount }, (_, index) => ({
        id: `boundary-card-${index + 1}`,
        title: `边界测试卡片${index + 1}`,
        type: CardType.TEXT,
        content: { text: `边界测试内容${index + 1}` } as CardContent,
        tags: ['边界测试'],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'test-user',
        lastModifiedBy: 'test-user'
      }));
      
      // 批量保存
      for (const card of testCards) {
        await cardRepository.saveCard(card);
      }
      
      // 获取所有卡片并验证数量
      const allCards = await cardRepository.getAllCards();
      expect(allCards.length).toBe(cardCount);
    });
    
    it('应该能够存储包含大量内容的卡片', async () => {
      // 创建一个包含大量文本的卡片
      const largeText = 'x'.repeat(100000); // 100KB的文本内容
      
      const largeCard: Card = {
        id: 'large-content-card',
        title: '大内容测试卡片',
        type: CardType.TEXT,
        content: { text: largeText } as CardContent,
        tags: ['大内容'],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'test-user',
        lastModifiedBy: 'test-user'
      };
      
      // 存储卡片
      await cardRepository.saveCard(largeCard);
      
      // 检索并验证
      const retrievedCard = await cardRepository.getCardById('large-content-card');
      
      expect(retrievedCard).not.toBeNull();
      expect(retrievedCard?.content.text).toBe(largeText);
      expect(retrievedCard?.content.text.length).toBe(largeText.length);
    });
  });
  
  describe('异常场景测试', () => {
    it('应该处理空数据和特殊字符', async () => {
      // 创建包含空值和特殊字符的卡片
      const specialCard: Card = {
        id: 'special-characters',
        title: '特殊字符测试 🚀!@#$%^&*()',
        type: CardType.TEXT,
        content: { text: '' } as CardContent, // 空内容
        tags: [], // 空标签
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'test-user',
        lastModifiedBy: 'test-user'
      };
      
      // 存储卡片
      await cardRepository.saveCard(specialCard);
      
      // 检索并验证
      const retrievedCard = await cardRepository.getCardById('special-characters');
      
      expect(retrievedCard).not.toBeNull();
      expect(retrievedCard?.title).toBe('特殊字符测试 🚀!@#$%^&*()');
      expect(retrievedCard?.content.text).toBe(''); // 空内容应被正确保存
      expect(retrievedCard?.tags).toEqual([]); // 空标签数组应被正确保存
    });
  });
});
```

## 2. 同步功能测试

### 2.1 测试目标

- 验证应用能够在多设备间正确同步卡片数据
- 确保在线/离线模式切换时的数据一致性
- 测试冲突解决机制的有效性
- 验证自动同步和手动同步功能

### 2.2 测试场景

1. **基本同步测试**
   - 设备A创建卡片，验证设备B能否同步获取
   - 设备B修改卡片，验证设备A能否同步更新
   - 设备A删除卡片，验证设备B能否同步删除

2. **离线操作同步**
   - 设备离线状态下创建/修改/删除卡片
   - 设备恢复在线状态后验证自动同步
   - 验证离线期间多个操作的合并同步

3. **冲突处理测试**
   - 模拟多设备同时修改同一张卡片
   - 验证冲突自动解决机制
   - 测试用户手动解决冲突的流程

4. **批量同步测试**
   - 大量卡片数据的同步性能
   - 网络不稳定条件下的同步可靠性

### 2.3 测试脚本示例

```typescript
// src/tests/system/sync.test.ts
import { describe, it, expect, beforeEach, afterEach, jest, fakeTimers } from '@jest/globals';
import { SyncService } from '../../services/sync/SyncService';
import { SyncStore } from '../../stores/syncStore';
import { CardRepository } from '../../repositories/card/CardRepository';
import { Card, CardType, CardContent } from '../../models/card/Card';
import { NetworkService } from '../../services/network/NetworkService';
import { MockNetworkService } from '../../services/network/MockNetworkService';

describe('同步功能系统测试', () => {
  let syncServiceA: SyncService;
  let syncServiceB: SyncService;
  let syncStoreA: SyncStore;
  let syncStoreB: SyncStore;
  let cardRepositoryA: CardRepository;
  let cardRepositoryB: CardRepository;
  let networkServiceA: MockNetworkService;
  let networkServiceB: MockNetworkService;
  
  beforeEach(async () => {
    // 模拟网络服务，用于控制在线/离线状态
    networkServiceA = new MockNetworkService();
    networkServiceB = new MockNetworkService();
    
    // 模拟同步服务 - 在实际测试中会更复杂，这里简化处理
    syncServiceA = new SyncService(networkServiceA);
    syncServiceB = new SyncService(networkServiceB);
    
    // 创建存储和仓库 - 模拟设备A和设备B
    cardRepositoryA = new CardRepository(new IndexedDbStorage('DeviceA'));
    cardRepositoryB = new CardRepository(new IndexedDbStorage('DeviceB'));
    
    // 创建同步状态存储
    syncStoreA = createSyncStore(syncServiceA);
    syncStoreB = createSyncStore(syncServiceB);
    
    // 初始化同步服务
    syncStoreA.getState().initializeSync();
    syncStoreB.getState().initializeSync();
    
    // 清除测试数据
    await cardRepositoryA.clearAllCards();
    await cardRepositoryB.clearAllCards();
  });
  
  afterEach(async () => {
    // 清理资源
    await cardRepositoryA.clearAllCards();
    await cardRepositoryB.clearAllCards();
    syncStoreA.getState().pauseAutoSync();
    syncStoreB.getState().pauseAutoSync();
  });
  
  describe('基本同步测试', () => {
    it('应该正确同步在一个设备上创建的卡片到另一个设备', async () => {
      // 确保两个设备都在线
      networkServiceA.setOnline(true);
      networkServiceB.setOnline(true);
      
      // 在设备A上创建卡片
      const testCard: Card = {
        id: 'sync-test-card-1',
        title: '设备A创建的测试卡片',
        type: CardType.TEXT,
        content: { text: '这是测试同步内容' } as CardContent,
        tags: ['同步测试'],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'user-1',
        lastModifiedBy: 'user-1'
      };
      
      await cardRepositoryA.saveCard(testCard);
      
      // 触发设备A的同步
      await syncStoreA.getState().triggerSync();
      
      // 触发设备B的同步
      await syncStoreB.getState().triggerSync();
      
      // 验证设备B上是否同步到该卡片
      const syncedCard = await cardRepositoryB.getCardById('sync-test-card-1');
      
      expect(syncedCard).not.toBeNull();
      expect(syncedCard?.title).toBe('设备A创建的测试卡片');
      expect(syncedCard?.content.text).toBe('这是测试同步内容');
    });
    
    it('应该正确同步在一个设备上修改的卡片到另一个设备', async () => {
      // 准备：在两个设备上都创建相同的卡片
      const initialCard: Card = {
        id: 'sync-update-test',
        title: '同步更新测试',
        type: CardType.TEXT,
        content: { text: '初始内容' } as CardContent,
        tags: [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'user-1',
        lastModifiedBy: 'user-1'
      };
      
      await cardRepositoryA.saveCard(initialCard);
      await cardRepositoryB.saveCard(initialCard);
      
      // 确保设备在线
      networkServiceA.setOnline(true);
      networkServiceB.setOnline(true);
      
      // 在设备A上修改卡片
      const updatedCard: Card = {
        ...initialCard,
        title: '已更新的标题',
        content: { text: '已更新的内容' } as CardContent,
        tags: ['已更新'],
        updatedAt: Date.now()
      };
      
      await cardRepositoryA.saveCard(updatedCard);
      
      // 触发设备A的同步
      await syncStoreA.getState().triggerSync();
      
      // 触发设备B的同步
      await syncStoreB.getState().triggerSync();
      
      // 验证设备B上的卡片已更新
      const syncedCard = await cardRepositoryB.getCardById('sync-update-test');
      
      expect(syncedCard).not.toBeNull();
      expect(syncedCard?.title).toBe('已更新的标题');
      expect(syncedCard?.content.text).toBe('已更新的内容');
      expect(syncedCard?.tags).toEqual(['已更新']);
      expect(syncedCard?.updatedAt).toBeGreaterThan(initialCard.updatedAt);
    });
    
    it('应该正确同步在一个设备上删除的卡片到另一个设备', async () => {
      // 准备：在两个设备上都创建相同的卡片
      const cardToDelete: Card = {
        id: 'sync-delete-test',
        title: '将要删除的测试卡片',
        type: CardType.TEXT,
        content: { text: '将被删除的内容' } as CardContent,
        tags: ['将被删除'],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'user-1',
        lastModifiedBy: 'user-1'
      };
      
      await cardRepositoryA.saveCard(cardToDelete);
      await cardRepositoryB.saveCard(cardToDelete);
      
      // 确保设备在线
      networkServiceA.setOnline(true);
      networkServiceB.setOnline(true);
      
      // 在设备A上删除卡片
      await cardRepositoryA.deleteCard('sync-delete-test');
      
      // 触发设备A的同步
      await syncStoreA.getState().triggerSync();
      
      // 触发设备B的同步
      await syncStoreB.getState().triggerSync();
      
      // 验证设备B上的卡片已被删除
      const deletedCard = await cardRepositoryB.getCardById('sync-delete-test');
      expect(deletedCard).toBeNull();
    });
  });
  
  describe('离线操作同步', () => {
    it('应该在设备恢复在线后自动同步离线期间的修改', async () => {
      // 准备：在两个设备上都有相同的初始数据
      const initialCard: Card = {
        id: 'offline-sync-test',
        title: '离线同步测试',
        type: CardType.TEXT,
        content: { text: '初始内容' } as CardContent,
        tags: [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'user-1',
        lastModifiedBy: 'user-1'
      };
      
      await cardRepositoryA.saveCard(initialCard);
      await cardRepositoryB.saveCard(initialCard);
      
      // 设置设备A为离线状态
      networkServiceA.setOnline(false);
      
      // 在设备A离线时修改卡片
      const offlineUpdateCard: Card = {
        ...initialCard,
        title: '离线修改后的标题',
        content: { text: '离线修改后的内容' } as CardContent,
        tags: ['离线修改'],
        updatedAt: Date.now()
      };
      
      await cardRepositoryA.saveCard(offlineUpdateCard);
      
      // 尝试同步（应该失败）
      const syncResult = await syncStoreA.getState().triggerSync();
      expect(syncResult).toBe(false);
      
      // 恢复设备A在线状态
      networkServiceA.setOnline(true);
      networkServiceB.setOnline(true);
      
      // 自动同步应该触发，或者手动触发同步
      await syncStoreA.getState().triggerSync();
      
      // 设备B同步更新
      await syncStoreB.getState().triggerSync();
      
      // 验证设备B上的卡片已更新为离线修改后的内容
      const syncedCard = await cardRepositoryB.getCardById('offline-sync-test');
      
      expect(syncedCard).not.toBeNull();
      expect(syncedCard?.title).toBe('离线修改后的标题');
      expect(syncedCard?.content.text).toBe('离线修改后的内容');
      expect(syncedCard?.tags).toEqual(['离线修改']);
    });
    
    it('应该正确合并离线期间的多个操作', async () => {
      // 设置设备A为离线状态
      networkServiceA.setOnline(false);
      
      // 在设备A离线时创建多张卡片
      const offlineCards: Card[] = [
        {
          id: 'offline-card-1',
          title: '离线卡片1',
          type: CardType.TEXT,
          content: { text: '离线内容1' } as CardContent,
          tags: ['离线'],
          createdAt: Date.now(),
          updatedAt: Date.now(),
          createdBy: 'user-1',
          lastModifiedBy: 'user-1'
        },
        {
          id: 'offline-card-2',
          title: '离线卡片2',
          type: CardType.TEXT,
          content: { text: '离线内容2' } as CardContent,
          tags: ['离线'],
          createdAt: Date.now() + 1000,
          updatedAt: Date.now() + 1000,
          createdBy: 'user-1',
          lastModifiedBy: 'user-1'
        }
      ];
      
      for (const card of offlineCards) {
        await cardRepositoryA.saveCard(card);
      }
      
      // 恢复设备A在线状态
      networkServiceA.setOnline(true);
      networkServiceB.setOnline(true);
      
      // 触发同步
      await syncStoreA.getState().triggerSync();
      await syncStoreB.getState().triggerSync();
      
      // 验证设备B上是否同步了所有离线创建的卡片
      const syncedCard1 = await cardRepositoryB.getCardById('offline-card-1');
      const syncedCard2 = await cardRepositoryB.getCardById('offline-card-2');
      
      expect(syncedCard1).not.toBeNull();
      expect(syncedCard2).not.toBeNull();
      expect(syncedCard1?.title).toBe('离线卡片1');
      expect(syncedCard2?.title).toBe('离线卡片2');
    });
  });
  
  describe('冲突处理测试', () => {
    it('应该能够自动解决卡片冲突（基于时间戳）', async () => {
      // 准备：在两个设备上都创建相同的卡片
      const initialCard: Card = {
        id: 'conflict-test-card',
        title: '冲突测试卡片',
        type: CardType.TEXT,
        content: { text: '初始内容' } as CardContent,
        tags: [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'user-1',
        lastModifiedBy: 'user-1'
      };
      
      await cardRepositoryA.saveCard(initialCard);
      await cardRepositoryB.saveCard(initialCard);
      
      // 设置设备为离线状态，模拟冲突场景
      networkServiceA.setOnline(false);
      networkServiceB.setOnline(false);
      
      // 在设备A上修改卡片
      const updateA: Card = {
        ...initialCard,
        title: '设备A的修改',
        content: { text: '设备A的内容' } as CardContent,
        updatedAt: Date.now() + 1000 // 较早的更新时间
      };
      
      // 在设备B上修改同一张卡片
      const updateB: Card = {
        ...initialCard,
        title: '设备B的修改',
        content: { text: '设备B的内容' } as CardContent,
        updatedAt: Date.now() + 2000 // 较晚的更新时间，应该获胜
      };
      
      await cardRepositoryA.saveCard(updateA);
      await cardRepositoryB.saveCard(updateB);
      
      // 恢复在线状态并同步
      networkServiceA.setOnline(true);
      networkServiceB.setOnline(true);
      
      // 触发同步
      await syncStoreA.getState().triggerSync();
      await syncStoreB.getState().triggerSync();
      
      // 再次同步以确保所有更改都传播
      await syncStoreA.getState().triggerSync();
      await syncStoreB.getState().triggerSync();
      
      // 验证两个设备上最终都使用了较晚的更新（设备B的修改）
      const finalCardA = await cardRepositoryA.getCardById('conflict-test-card');
      const finalCardB = await cardRepositoryB.getCardById('conflict-test-card');
      
      expect(finalCardA?.title).toBe('设备B的修改');
      expect(finalCardA?.content.text).toBe('设备B的内容');
      expect(finalCardB?.title).toBe('设备B的修改');
      expect(finalCardB?.content.text).toBe('设备B的内容');
    });
    
    it('应该在无法自动解决冲突时提供冲突信息', async () => {
      // 模拟同步服务的冲突解决
      const conflictSpy = jest.spyOn(syncServiceA, 'sync').mockImplementation(async () => {
        // 触发冲突事件
        syncServiceA.emit('syncEvent', {
          type: 'CONFLICT_DETECTED',
          details: {
            cardId: 'conflict-manual-card',
            serverVersion: { title: '服务器版本', updatedAt: Date.now() },
            localVersion: { title: '本地版本', updatedAt: Date.now() - 1000 }
          }
        });
        return false; // 同步失败
      });
      
      // 在设备A上创建卡片
      const conflictCard: Card = {
        id: 'conflict-manual-card',
        title: '需要手动解决的冲突卡片',
        type: CardType.TEXT,
        content: { text: '冲突内容' } as CardContent,
        tags: [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        createdBy: 'user-1',
        lastModifiedBy: 'user-1'
      };
      
      await cardRepositoryA.saveCard(conflictCard);
      
      // 监听冲突事件
      let conflictDetected = false;
      let conflictDetails: any = null;
      
      syncServiceA.on('syncEvent', (event: any) => {
        if (event.type === 'CONFLICT_DETECTED') {
          conflictDetected = true;
          conflictDetails = event.details;
        }
      });
      
      // 触发同步
      await syncStoreA.getState().triggerSync();
      
      // 验证冲突被正确检测
      expect(conflictDetected).toBe(true);
      expect(conflictDetails).not.toBeNull();
      expect(conflictDetails.cardId).toBe('conflict-manual-card');
      
      // 恢复原始实现
      conflictSpy.mockRestore();
    });
  });
  
  describe('批量同步测试', () => {
    it('应该能够同步大量卡片数据', async () => {
      // 确保设备在线
      networkServiceA.setOnline(true);
      networkServiceB.setOnline(true);
      
      // 在设备A上创建多张卡片
      const batchCount = 50;
      const batchCards: Card[] = Array.from({ length: batchCount }, (_, index) => ({
        id: `batch-sync-card-${index + 1}`,
        title: `批量同步卡片${index + 1}`,
        type: CardType.TEXT,
        content: { text: `批量同步内容${index + 1}` } as CardContent,
        tags: ['批量同步'],
        createdAt: Date.now() + index,
        updatedAt: Date.now() + index,
        createdBy: 'user-1',
        lastModifiedBy: 'user-1'
      }));
      
      for (const card of batchCards) {
        await cardRepositoryA.saveCard(card);
      }
      
      // 触发同步
      await syncStoreA.getState().triggerSync();
      await syncStoreB.getState().triggerSync();
      
      // 验证设备B上同步了所有卡片
      const allCardsB = await cardRepositoryB.getAllCards();
      expect(allCardsB.length).toBe(batchCount);
      
      // 验证随机选择的几张卡片
      for (let i = 0; i < 5; i++) {
        const randomIndex = Math.floor(Math.random() * batchCount);
        const cardId = `batch-sync-card-${randomIndex + 1}`;
        const syncedCard = allCardsB.find(card => card.id === cardId);
        
        expect(syncedCard).not.toBeUndefined();
        expect(syncedCard?.title).toBe(`批量同步卡片${randomIndex + 1}`);
      }
    });
  });
});
```

## 相关文档

- [API接口设计与单元测试](../api/api-interfaces-testing.md)
- [状态管理Store API](../api/store-apis-testing.md)
- [回归测试计划](./regression-testing-plan.md)
- [用户界面测试](./ui-testing.md)
- [测试工具与技术](./testing-tools.md)

[返回技术文档索引](../api-testing-design-index.md)
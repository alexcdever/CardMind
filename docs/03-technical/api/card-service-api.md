# CardService API接口设计与单元测试

> 本文档定义了CardMind系统的卡片服务接口及其单元测试实现。

## 目录
- [1. 接口定义](#1-接口定义)
- [2. 单元测试](#2-单元测试)

## 1. 接口定义

```typescript
// src/services/card/CardService.ts

/**
 * 卡片数据接口
 */
export interface Card {
  /**
   * 卡片唯一标识符
   */
  id: string;
  
  /**
   * 卡片标题
   */
  title: string;
  
  /**
   * 卡片内容
   */
  content: string;
  
  /**
   * 创建时间
   */
  createdAt: number; // Timestamp
  
  /**
   * 更新时间
   */
  updatedAt: number; // Timestamp
  
  /**
   * 创建者设备ID
   */
  createdBy: string;
  
  /**
   * 最后更新者设备ID
   */
  lastUpdatedBy: string;
  
  /**
   * 标签列表
   */
  tags: string[];
  
  /**
   * 是否为收藏卡片
   */
  isStarred: boolean;
}

/**
 * 卡片创建参数接口
 */
export interface CardCreateParams {
  /**
   * 卡片标题
   */
  title: string;
  
  /**
   * 卡片内容
   */
  content: string;
  
  /**
   * 标签列表
   */
  tags?: string[];
}

/**
 * 卡片更新参数接口
 */
export interface CardUpdateParams {
  /**
   * 卡片标题
   */
  title?: string;
  
  /**
   * 卡片内容
   */
  content?: string;
  
  /**
   * 标签列表
   */
  tags?: string[];
  
  /**
   * 是否为收藏卡片
   */
  isStarred?: boolean;
}

/**
 * 卡片服务接口
 */
export interface CardService {
  /**
   * 创建新卡片
   * @param params 卡片创建参数
   * @returns 创建的卡片
   */
  createCard(params: CardCreateParams): Promise<Card>;
  
  /**
   * 获取卡片列表
   * @returns 卡片列表
   */
  getAllCards(): Promise<Card[]>;
  
  /**
   * 根据ID获取卡片
   * @param id 卡片ID
   * @returns 卡片，如果不存在则返回null
   */
  getCard(id: string): Promise<Card | null>;
  
  /**
   * 更新卡片
   * @param id 卡片ID
   * @param params 卡片更新参数
   * @returns 更新后的卡片，如果不存在则返回null
   */
  updateCard(id: string, params: CardUpdateParams): Promise<Card | null>;
  
  /**
   * 删除卡片
   * @param id 卡片ID
   * @returns 删除结果
   */
  deleteCard(id: string): Promise<boolean>;
  
  /**
   * 搜索卡片
   * @param query 搜索关键词
   * @returns 匹配的卡片列表
   */
  searchCards(query: string): Promise<Card[]>;
  
  /**
   * 获取收藏卡片
   * @returns 收藏卡片列表
   */
  getStarredCards(): Promise<Card[]>;
  
  /**
   * 根据标签获取卡片
   * @param tag 标签
   * @returns 匹配的卡片列表
   */
  getCardsByTag(tag: string): Promise<Card[]>;
}
```

## 2. 单元测试

CardService的单元测试已单独拆分为：
- [CardService API单元测试](card-service-api-test.md)

## 相关文档

- [AuthService API接口设计与单元测试](auth-service-api.md)
- [DeviceService API接口设计与单元测试](device-service-api.md)
- [EncryptionService API接口设计与单元测试](encryption-service-api.md)
- [SyncService API接口设计与单元测试](sync-service-api.md)

[返回API测试设计文档索引](../api-testing-design-index.md)
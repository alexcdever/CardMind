
// 卡片接口定义
export interface Card {
  id: number;          // 卡片ID
  title: string;       // 卡片标题
  content: string;     // 卡片内容
  created_at: string;  // 创建时间
  updated_at: string;  // 更新时间
}

// 创建卡片的请求负载
export interface CreateCardPayload {
  title: string;     // 卡片标题
  content: string;   // 卡片内容
}

// 更新卡片的请求负载
export interface UpdateCardPayload {
  title?: string;     // 卡片标题（可选）
  content?: string;   // 卡片内容（可选）
}

// 添加一些辅助类型，以便在其他地方复用
export type PartialCard = Partial<Card>;
export type NewCard = Omit<Card, 'id' | 'nextReview' | 'reviewCount' | 'difficulty'>;
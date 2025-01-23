export interface Category {
  id: number;
  name: string;
  color: string;
}

export interface Card {
  id: number;
  title: string;
  content: string;
  created_at: string;
  categoryId?: number;
  category?: Category;
  nextReview?: Date;
  reviewCount: number;
  difficulty: number;
}

export interface CreateCardPayload {
  title: string;
  content: string;
}

export interface UpdateCardPayload {
  title?: string;
  content?: string;
}

// 添加一些辅助类型，以便在其他地方复用
export type PartialCard = Partial<Card>;
export type NewCard = Omit<Card, 'id' | 'nextReview' | 'reviewCount' | 'difficulty'>;
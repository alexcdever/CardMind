export interface Category {
  id: number;
  name: string;
  color: string;
}

export interface Card {
  id: number;
  front: string;
  back: string;
  categoryId?: number;
  category?: Category;
  nextReview?: Date;
  reviewCount: number;
  difficulty: number;
}

// 添加一些辅助类型，以便在其他地方复用
export type PartialCard = Partial<Card>;
export type NewCard = Omit<Card, 'id' | 'nextReview' | 'reviewCount' | 'difficulty'>;
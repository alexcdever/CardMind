// 定义 Card 接口
export interface Card {
  id: number;
  title: string;
  content: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

// 定义 Electron API 接口
export interface IDatabase {
  getAllCards: () => Promise<Card[]>;
  addCard: (cardData: Omit<Card, 'id' | 'createdAt' | 'updatedAt'>) => Promise<Card>;
  updateCard: (id: number, data: Partial<Omit<Card, 'id' | 'createdAt' | 'updatedAt'>>) => Promise<Card>;
  deleteCard: (id: number) => Promise<boolean>;
  getCardById: (id: number) => Promise<Card | null>;
  searchCards: (query: string) => Promise<Card[]>;
}

// 扩展全局 Window 接口
declare global {
  interface Window {
    electron: {
      database: IDatabase;
    };
  }
}

export {};
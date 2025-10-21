/**
 * 卡片实体类型定义
 */
export interface Card {
  id: string;
  title: string;
  content: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: boolean;
  deletedAt?: number;
  lastModifiedDeviceId?: string;
}

/**
 * 卡片列表状态类型定义
 */
export interface CardListState {
  cards: Card[];
  loading: boolean;
  error: string | null;
  refreshing: boolean;
  searchQuery: string;
  filterOptions: {
    showDeleted: boolean;
    sortBy: 'createdAt' | 'updatedAt';
    sortOrder: 'asc' | 'desc';
  };
}

/**
 * 卡片编辑器状态类型定义
 */
export interface CardEditorState {
  id: string | null;
  title: string;
  content: string;
  saving: boolean;
  error: string | null;
  isNewCard: boolean;
  maxTitleLength: number;
  maxContentLength: number;
}
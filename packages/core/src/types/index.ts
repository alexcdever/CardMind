export interface Card {
  id: number;
  title: string;
  content: string;
  description?: string;
  tags?: Tag[];
  createdAt?: string;
  updatedAt?: string;
}

export interface Tag {
  id: number;
  name: string;
}

export interface DatabaseResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

const { contextBridge, ipcRenderer } = require('electron');

interface Card {
  id?: number;
  title: string;
  content: string;
  tags?: string[];
  createdAt?: Date;
  updatedAt?: Date;
}

// 定义要暴露给渲染进程的 API
const electronAPI = {
  database: {
    addCard: (cardData: Omit<Card, 'id' | 'createdAt' | 'updatedAt'>) => 
      ipcRenderer.invoke('database:addCard', cardData),
    getAllCards: () => 
      ipcRenderer.invoke('database:getAllCards'),
    updateCard: (id: number, cardData: Partial<Omit<Card, 'id' | 'createdAt' | 'updatedAt'>>) => 
      ipcRenderer.invoke('database:updateCard', id, cardData),
    deleteCard: (id: number) => 
      ipcRenderer.invoke('database:deleteCard', id),
    getCardById: (id: number) => 
      ipcRenderer.invoke('database:getCardById', id),
    searchCards: (query: string) => 
      ipcRenderer.invoke('database:searchCards', query),
  }
};

// 使用 contextBridge 暴露 API
contextBridge.exposeInMainWorld('electron', electronAPI);

// 防止 TypeScript 报错
export {};

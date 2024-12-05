const { contextBridge, ipcRenderer } = require('electron');

// 声明全局类型
declare global {
  interface Window {
    electron: {
      send: (channel: string, data: any) => void;
      on: (channel: string, func: (event: Electron.IpcRendererEvent, ...args: any[]) => void) => () => void;
      getAppVersion: () => Promise<string>;
      openExternal: (url: string) => void;
      saveFile: (content: string) => Promise<string>;
      readFile: (path: string) => Promise<string>;
      database: {
        getAllCards: () => Promise<any[]>;
        addCard: (cardData: any) => Promise<any>;
        updateCard: (id: number, data: any) => Promise<any>;
        deleteCard: (id: number) => Promise<void>;
        getCardById: (id: number) => Promise<any>;
        searchCards: (query: string) => Promise<any[]>;
        resetDatabase: () => Promise<void>;
      };
    };
  }
}

// 定义渲染进程可以调用的 API
contextBridge.exposeInMainWorld('electron', {
  // 发送消息到主进程
  send: (channel: string, data: any) => {
    ipcRenderer.send(channel, data);
  },

  // 监听主进程发送的消息
  on: (channel: string, func: (event: Electron.IpcRendererEvent, ...args: any[]) => void) => {
    const subscription = (_event: Electron.IpcRendererEvent, ...args: any[]) => func(_event, ...args);
    ipcRenderer.on(channel, subscription);

    // 返回一个取消订阅的方法
    return () => {
      ipcRenderer.removeListener(channel, subscription);
    };
  },

  // 获取应用程序的版本
  getAppVersion: async (): Promise<string> => {
    return ipcRenderer.invoke('get-app-version');
  },

  // 打开外部链接
  openExternal: (url: string) => {
    ipcRenderer.send('open-external', url);
  },

  // 保存文件
  saveFile: async (content: string): Promise<string> => {
    return ipcRenderer.invoke('save-file', content);
  },

  // 读取文件
  readFile: async (path: string): Promise<string> => {
    return ipcRenderer.invoke('read-file', path);
  },

  // 数据库操作
  database: {
    addCard: async (cardData: any) => {
      console.log('Preload: addCard called with:', cardData);
      const result = await ipcRenderer.invoke('card:add', cardData);
      console.log('Preload: addCard result:', result);
      return result;
    },
    updateCard: async (id: number, data: any) => {
      // 确保 id 是数字类型
      const numericId = parseInt(id as any, 10);
      console.log('Preload: updateCard called with:', { id: numericId, ...data });
      const result = await ipcRenderer.invoke('card:update', {
        id: numericId,
        ...data
      });
      console.log('Preload: updateCard result:', result);
      return result;
    },
    deleteCard: async (id: number) => {
      // 确保 id 是数字类型
      const numericId = parseInt(id as any, 10);
      return ipcRenderer.invoke('card:delete', numericId);
    },
    getAllCards: async () => {
      console.log('Preload: getAllCards called');
      const result = await ipcRenderer.invoke('card:getAll');
      console.log('Preload: getAllCards result:', result);
      return result.data;
    },
    getCardById: async (id: number) => {
      // 确保 id 是数字类型
      const numericId = parseInt(id as any, 10);
      console.log('Preload: getCardById called with:', numericId);
      const result = await ipcRenderer.invoke('card:getById', numericId);
      console.log('Preload: getCardById result:', result);
      return result;
    },
    searchCards: async (query: string) => {
      return ipcRenderer.invoke('card:search', query);
    },
    resetDatabase: async () => {
      return ipcRenderer.invoke('database:reset');
    }
  },
});

// 确保文件被视为 ES 模块
export {};
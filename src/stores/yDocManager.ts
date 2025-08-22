import * as Y from 'yjs';
import { IndexeddbPersistence } from 'y-indexeddb';
import { WebrtcProvider } from 'y-webrtc';
import { Block, DocBlock, TextBlock, MediaBlock, CodeBlock } from '../types/block-inheritance';
import { serializeBlock, deserializeBlock } from '../types/block-inheritance';

interface DocEntry {
  doc: Y.Doc;
  providers: { 
    offline: IndexeddbPersistence; 
    online: WebrtcProvider | null 
  };
}

export class yDocManager {
  // 存储已打开的文档
  private static openDocs = new Map<string, DocEntry>();

  // 获取已存在的文档
  static async get(blockId: string): Promise<DocEntry> {
    if (!this.openDocs.has(blockId)) {
      throw new Error(`文档 ${blockId} 不存在`);
    }
    return this.openDocs.get(blockId)!;
  }

  // 创建新文档
  static async create(blockId: string): Promise<DocEntry> {
    if (this.openDocs.has(blockId)) {
      throw new Error(`文档 ${blockId} 已存在`);
    }

    const doc = new Y.Doc();
    const providers = {
      offline: new IndexeddbPersistence(`doc_${blockId}`, doc),
      online: null as WebrtcProvider | null
    };

    // 等待IndexedDB初始化完成
    await new Promise<void>((resolve) => {
      providers.offline.on('synced', () => {
        console.log(`IndexedDB持久化已就绪: doc_${blockId}`);
        resolve();
      });
    });

    try {
      // providers.online = new WebrtcProvider(`doc_${blockId}`, doc, {
      //   signaling: ['wss://signaling.yjs.dev']
      // });
    } catch (e) {
      console.warn('WebRTC连接失败，将使用离线模式:', e);
    }

    const result = { doc, providers };
    this.openDocs.set(blockId, result);
    return result;
  }

  // 兼容旧版open方法
  static async open(blockId: string): Promise<DocEntry> {
    try {
      // 如果文档已存在，直接返回
      if (this.openDocs.has(blockId)) {
        return this.openDocs.get(blockId)!;
      }
      
      // 否则创建新文档
      const result = await this.create(blockId);
      
      // 添加错误处理
      result.providers.offline.on('error', (err: Error) => {
        console.error('IndexedDB持久化错误:', err);
      });
      
      return result;
    } catch (err) {
      console.error('打开文档失败:', err);
      throw err;
    }
  }

  // 关闭文档(返回Promise)
  static async close(blockId: string): Promise<void> {
    const entry = this.openDocs.get(blockId);
    if (!entry) return;

    try {
      // 并行销毁所有provider
      await Promise.all([
        new Promise<void>((resolve) => {
          entry.providers.offline.destroy();
          resolve();
        }),
        entry.providers.online 
          ? new Promise<void>((resolve) => {
              entry.providers.online!.destroy();
              resolve();
            })
          : Promise.resolve()
      ]);
      
      this.openDocs.delete(blockId);
    } catch (err) {
      console.error('关闭文档失败:', err);
      throw err;
    }
  }

  // 更新块数据到Y.Doc
  static async updateBlock(blockId: string, block: Block): Promise<void> {
    const { doc } = await this.open(blockId);
    const yMap = doc.getMap('data');
    
    doc.transact(() => {
      Object.entries(serializedBlock).forEach(([key, value]) => {
        yMap.set(key, typeof value === 'object' ? JSON.parse(JSON.stringify(value)) : value);
      });
    });
  }

  // 从Y.Doc获取块数据
  static async getBlock(blockId: string): Promise<Block | null> {
    const { doc } = await this.open(blockId);
    const yMap = doc.getMap('data');
    if (!yMap.size) return null;
    const data = Object.fromEntries(yMap.entries());
    return data as unknown as Block;
  }

  // 获取所有块ID
  static async getAllBlockIds(): Promise<string[]> {
    return new Promise((resolve) => {
      const request = indexedDB.open('y-indexeddb');
      request.onsuccess = () => {
        const db = request.result;
        const blockIds = new Set<string>();
        
        // 遍历所有对象存储
        Array.from(db.objectStoreNames).forEach((storeName: string) => {
          try {
            const transaction = db.transaction(storeName, 'readonly');
            const store = transaction.objectStore(storeName);
            const requestKeys = store.getAllKeys();
            
            requestKeys.onsuccess = () => {
              const keys = requestKeys.result as string[];
              keys.forEach((key: string) => {
                if (typeof key === 'string' && key.startsWith('doc_')) {
                  blockIds.add(key.replace('doc_', ''));
                }
              });
            };
          } catch (e) {
            console.warn(`查询对象存储${storeName}失败:`, e);
          }
        });

        // 延迟返回确保所有查询完成
        setTimeout(() => resolve(Array.from(blockIds)), 100);
      };
      request.onerror = () => resolve([]);
    });
  }
}

import * as Y from 'yjs';
import { IndexeddbPersistence } from 'y-indexeddb';
import { WebrtcProvider } from 'y-webrtc';
import { UnifiedBlock } from '../types/block';

export class yDocManager {
  // 存储已打开的文档
  private static openDocs = new Map<string, {
    doc: Y.Doc;
    providers: { offline: IndexeddbPersistence; online: WebrtcProvider | null };
  }>();

  // 获取已存在的文档
  static async get(blockId: string) {
    if (!this.openDocs.has(blockId)) {
      throw new Error(`文档 ${blockId} 不存在`);
    }
    return this.openDocs.get(blockId)!;
  }

  // 创建新文档
  static async create(blockId: string) {
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

    this.openDocs.set(blockId, { doc, providers });
    return { doc };
  }

  // 兼容旧版open方法
  static async open(blockId: string) {
    try {
      return await this.get(blockId);
    } catch {
      return await this.create(blockId);
    }
  }

  // 关闭文档
  static close(blockId: string) {
    const entry = this.openDocs.get(blockId);
    if (!entry) return;

    entry.providers.offline.destroy();
    if (entry.providers.online) {
      entry.providers.online.destroy();
    }
    this.openDocs.delete(blockId);
  }

  // 更新块数据到Y.Doc
  static async updateBlock(blockId: string, block: UnifiedBlock) {
    const { doc } = await this.open(blockId);
    const yMap = doc.getMap('data');
    
    doc.transact(() => {
      Object.entries(block).forEach(([key, value]) => {
        yMap.set(key, typeof value === 'object' ? JSON.parse(JSON.stringify(value)) : value);
      });
    });
  }

  // 从Y.Doc获取块数据
  static async getBlock(blockId: string): Promise<UnifiedBlock | null> {
    const { doc } = await this.open(blockId);
    const yMap = doc.getMap('data');
    if (!yMap.size) return null;
    const data = Object.fromEntries(yMap.entries());
    return data as unknown as UnifiedBlock;
  }

  // 获取所有块ID
  static async getAllBlockIds(): Promise<string[]> {
    return new Promise((resolve) => {
      const request = indexedDB.open('y-indexeddb');
      request.onsuccess = () => {
        const db = request.result;
        const blockIds = new Set<string>();
        
        // 遍历所有对象存储
        Array.from(db.objectStoreNames).forEach(storeName => {
          try {
            const transaction = db.transaction(storeName, 'readonly');
            const store = transaction.objectStore(storeName);
            const requestKeys = store.getAllKeys();
            
            requestKeys.onsuccess = () => {
              const keys = requestKeys.result as string[];
              keys.forEach(key => {
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

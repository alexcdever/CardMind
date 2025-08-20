// Yjs同步管理 - 处理实时协作和状态同步
import * as Y from 'yjs';
import { WebsocketProvider } from 'y-websocket';
import type { Document, Block, SyncStatus, Collaborator } from '@cardmind/types';

// Yjs文档管理器
export class YjsManager {
  private yDocs: Map<string, Y.Doc> = new Map();
  private providers: Map<string, WebsocketProvider> = new Map();
  private syncStatus: SyncStatus = { isOnline: false, pendingChanges: 0 };

  constructor(private serverUrl: string = 'ws://localhost:1234') {}

  // 创建或获取Yjs文档
  getYDoc(documentId: string): Y.Doc {
    if (!this.yDocs.has(documentId)) {
      const yDoc = new Y.Doc();
      
      // 创建文档结构
      yDoc.getArray('blocks');
      yDoc.getMap('meta');
      
      // 监听变化
      yDoc.on('update', () => {
        this.syncStatus.pendingChanges++;
      });

      this.yDocs.set(documentId, yDoc);
    }

    return this.yDocs.get(documentId)!;
  }

  // 连接到协作服务器
  connect(documentId: string, onCollaboratorsUpdate?: (collaborators: Collaborator[]) => void): void {
    const yDoc = this.getYDoc(documentId);
    
    if (!this.providers.has(documentId)) {
      const provider = new WebsocketProvider(this.serverUrl, documentId, yDoc);
      
      provider.on('status', (event: { status: string }) => {
        this.syncStatus.isOnline = event.status === 'connected';
        this.syncStatus.lastSyncTime = new Date();
      });

      provider.on('sync', () => {
        this.syncStatus.pendingChanges = 0;
      });

      // 监听协作者变化
      if (onCollaboratorsUpdate) {
        provider.awareness.on('change', () => {
          const states = provider.awareness.getStates();
          const collaborators: Collaborator[] = [];
          
          states.forEach((state: any) => {
            if (state.user) {
              collaborators.push({
                id: state.user.id,
                name: state.user.name,
                color: state.user.color,
                cursor: state.cursor,
                lastActive: new Date()
              });
            }
          });
          
          onCollaboratorsUpdate(collaborators);
        });
      }

      this.providers.set(documentId, provider);
    }
  }

  // 断开连接
  disconnect(documentId: string): void {
    const provider = this.providers.get(documentId);
    if (provider) {
      provider.destroy();
      this.providers.delete(documentId);
    }
  }

  // 将本地文档同步到Yjs
  syncDocumentToYjs(document: Document): void {
    const yDoc = this.getYDoc(document.id);
    const yBlocks = yDoc.getArray('blocks');
    const yMeta = yDoc.getMap('meta');

    // 清空现有内容
    yBlocks.delete(0, yBlocks.length);

    // 添加本地块
    document.blocks.forEach(block => {
      yBlocks.push([{
        id: block.id,
        type: block.type,
        content: block.content,
        metadata: block.metadata || {},
        position: block.position,
        createdAt: block.createdAt.toISOString(),
        updatedAt: block.updatedAt.toISOString()
      }]);
    });

    // 更新元数据
    yMeta.set('title', document.title);
    yMeta.set('tags', document.tags);
    yMeta.set('createdAt', document.createdAt.toISOString());
    yMeta.set('updatedAt', document.updatedAt.toISOString());
  }

  // 从Yjs获取文档
  getDocumentFromYjs(documentId: string): Document | null {
    const yDoc = this.yDocs.get(documentId);
    if (!yDoc) return null;

    const yBlocks = yDoc.getArray('blocks');
    const yMeta = yDoc.getMap('meta');

    const blocks: Block[] = [];
    const blockArray = yBlocks.toArray() as any[];
    
    blockArray.forEach((blockData: any) => {
      if (blockData && typeof blockData === 'object') {
        blocks.push({
          id: String(blockData.id || ''),
          type: blockData.type || 'text',
          content: String(blockData.content || ''),
          metadata: blockData.metadata || {},
          position: blockData.position || { x: 0, y: 0 },
          createdAt: new Date(blockData.createdAt || Date.now()),
          updatedAt: new Date(blockData.updatedAt || Date.now())
        });
      }
    });

    const title = yMeta.get('title') as string || 'Untitled';
    const tags = yMeta.get('tags') as string[] || [];
    const createdAt = new Date(yMeta.get('createdAt') as string || Date.now());
    const updatedAt = new Date(yMeta.get('updatedAt') as string || Date.now());

    return {
      id: documentId,
      title,
      tags,
      blocks,
      createdAt,
      updatedAt,
      version: 1
    };
  }

  // 获取同步状态
  getSyncStatus(): SyncStatus {
    return { ...this.syncStatus };
  }

  // 设置用户信息和光标位置
  setUserPresence(documentId: string, user: { id: string; name: string; color: string }, cursor?: { x: number; y: number }): void {
    const provider = this.providers.get(documentId);
    if (provider) {
      provider.awareness.setLocalStateField('user', user);
      if (cursor) {
        provider.awareness.setLocalStateField('cursor', cursor);
      }
    }
  }
}

// 导出单例
export const yjsManager = new YjsManager();
/**
 * 后端Yjs文档管理器
 * 负责管理所有网络的Yjs文档，提供持久化和同步功能
 */

const Y = require('yjs');
const { LevelDbPersistence } = require('y-leveldb');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs').promises;

class YjsDocumentManager {
    constructor(dataDir = './data') {
        this.dataDir = dataDir;
        this.documents = new Map(); // networkId -> Y.Doc
        this.persistences = new Map(); // networkId -> LevelDbPersistence
        this.syncStates = new Map(); // networkId -> sync state
        
        this.ensureDataDir();
    }

    /**
     * 确保数据目录存在
     */
    async ensureDataDir() {
        try {
            await fs.mkdir(this.dataDir, { recursive: true });
            console.log('[YjsDocumentManager] 数据目录已创建:', this.dataDir);
        } catch (error) {
            console.error('[YjsDocumentManager] 创建数据目录失败:', error);
        }
    }

    /**
     * 获取或创建Yjs文档
     */
    async getOrCreateDocument(networkId) {
        if (this.documents.has(networkId)) {
            return this.documents.get(networkId);
        }

        try {
            // 创建新的Yjs文档
            const doc = new Y.Doc();
            
            // 创建持久化适配器
            const dbPath = path.join(this.dataDir, `network-${networkId}`);
            const persistence = new LevelDbPersistence(dbPath);
            
            // 绑定持久化
            await persistence.bindState(networkId, doc);
            
            // 存储引用
            this.documents.set(networkId, doc);
            this.persistences.set(networkId, persistence);
            
            console.log(`[YjsDocumentManager] 创建新文档: ${networkId}`);
            
            // 设置文档变更监听
            this.setupDocumentListeners(networkId, doc);
            
            return doc;
        } catch (error) {
            console.error(`[YjsDocumentManager] 创建文档失败: ${networkId}`, error);
            throw error;
        }
    }

    /**
     * 设置文档变更监听
     */
    setupDocumentListeners(networkId, doc) {
        // 监听文档根变更
        doc.on('update', (update, origin) => {
            if (origin !== 'server') {
                console.log(`[YjsDocumentManager] 文档更新: ${networkId}, 来源:`, origin);
                this.handleDocumentUpdate(networkId, update, origin);
            }
        });

        // 监听网络数据变更
        const networkMap = doc.getMap('network');
        networkMap.observe((event) => {
            console.log(`[YjsDocumentManager] 网络数据变更: ${networkId}`, event);
            this.handleNetworkDataChange(networkId, event);
        });

        // 监听卡片数组变更
        const cardsArray = doc.getArray('cards');
        cardsArray.observe((event) => {
            console.log(`[YjsDocumentManager] 卡片数组变更: ${networkId}`, event);
            this.handleCardsArrayChange(networkId, event);
        });
    }

    /**
     * 处理文档更新
     */
    handleDocumentUpdate(networkId, update, origin) {
        // 广播更新给所有连接的客户端（除了来源）
        this.broadcastUpdate(networkId, update, origin);
        
        // 更新同步状态
        this.updateSyncState(networkId, {
            lastUpdate: Date.now(),
            updateSize: update.length,
            origin: origin
        });
    }

    /**
     * 处理网络数据变更
     */
    handleNetworkDataChange(networkId, event) {
        // 可以在这里添加业务逻辑处理
        console.log(`[YjsDocumentManager] 处理网络数据变更: ${networkId}`);
    }

    /**
     * 处理卡片数组变更
     */
    handleCardsArrayChange(networkId, event) {
        // 可以在这里添加卡片相关的业务逻辑
        console.log(`[YjsDocumentManager] 处理卡片数组变更: ${networkId}`);
    }

    /**
     * 广播更新给客户端
     */
    broadcastUpdate(networkId, update, origin) {
        // 这个方法会被SignalingServer调用
        if (this.broadcastCallback) {
            this.broadcastCallback(networkId, {
                type: 'yjs-update',
                data: {
                    networkId,
                    update: Array.from(update), // Uint8Array转Array便于JSON序列化
                    origin
                }
            });
        }
    }

    /**
     * 设置广播回调
     */
    setBroadcastCallback(callback) {
        this.broadcastCallback = callback;
    }

    /**
     * 应用客户端更新
     */
    async applyClientUpdate(networkId, update, clientId) {
        try {
            const doc = await this.getOrCreateDocument(networkId);
            
            // 将Array转回Uint8Array
            const uint8Update = new Uint8Array(update);
            
            // 应用更新，标记来源为server避免循环
            Y.applyUpdate(doc, uint8Update, 'server');
            
            console.log(`[YjsDocumentManager] 应用客户端更新: ${networkId}, 客户端: ${clientId}`);
            
            return true;
        } catch (error) {
            console.error(`[YjsDocumentManager] 应用客户端更新失败: ${networkId}`, error);
            return false;
        }
    }

    /**
     * 获取文档状态
     */
    getDocumentState(networkId) {
        const doc = this.documents.get(networkId);
        if (!doc) {
            return null;
        }

        const networkMap = doc.getMap('network');
        const cardsArray = doc.getArray('cards');

        return {
            networkId,
            networkData: networkMap.toJSON(),
            cards: cardsArray.toArray(),
            syncState: this.syncStates.get(networkId) || {},
            documentSize: Y.encodeStateAsUpdate(doc).length
        };
    }

    /**
     * 更新同步状态
     */
    updateSyncState(networkId, state) {
        const currentState = this.syncStates.get(networkId) || {};
        this.syncStates.set(networkId, {
            ...currentState,
            ...state,
            lastSync: Date.now()
        });
    }

    /**
     * 获取同步状态
     */
    getSyncState(networkId) {
        return this.syncStates.get(networkId) || {
            lastSync: 0,
            lastUpdate: 0,
            updateSize: 0,
            origin: 'unknown'
        };
    }

    /**
     * 清理文档
     */
    async cleanupDocument(networkId) {
        try {
            const doc = this.documents.get(networkId);
            const persistence = this.persistences.get(networkId);

            if (doc) {
                doc.destroy();
                this.documents.delete(networkId);
            }

            if (persistence) {
                await persistence.destroy();
                this.persistences.delete(networkId);
            }

            this.syncStates.delete(networkId);

            console.log(`[YjsDocumentManager] 清理文档: ${networkId}`);
        } catch (error) {
            console.error(`[YjsDocumentManager] 清理文档失败: ${networkId}`, error);
        }
    }

    /**
     * 获取所有活跃文档
     */
    getActiveDocuments() {
        return Array.from(this.documents.keys()).map(networkId => ({
            networkId,
            state: this.getDocumentState(networkId),
            syncState: this.getSyncState(networkId)
        }));
    }

    /**
     * 健康检查
     */
    getHealthStatus() {
        return {
            activeDocuments: this.documents.size,
            persistences: this.persistences.size,
            syncStates: this.syncStates.size,
            dataDir: this.dataDir,
            uptime: process.uptime()
        };
    }

    /**
     * 优雅关闭
     */
    async shutdown() {
        console.log('[YjsDocumentManager] 开始优雅关闭...');
        
        try {
            // 清理所有文档
            const networkIds = Array.from(this.documents.keys());
            
            for (const networkId of networkIds) {
                await this.cleanupDocument(networkId);
            }
            
            console.log('[YjsDocumentManager] 优雅关闭完成');
        } catch (error) {
            console.error('[YjsDocumentManager] 优雅关闭失败:', error);
        }
    }
}

module.exports = YjsDocumentManager;
/**
 * 同步服务
 * 处理设备间的数据同步
 */

import * as Y from 'yjs'
import { WebrtcProvider } from 'y-webrtc'
import { IndexeddbPersistence } from 'y-indexeddb'
import { Awareness } from 'y-protocols/awareness'
import useSyncStore from '../stores/syncStore'
import useDeviceStore from '../stores/deviceStore'
import useCardStore from '../stores/cardStore'
import { Card } from '../types/card.types'

// 定义同步消息类型
type SyncMessageType = 'CARD_UPDATE' | 'DEVICE_UPDATE' | 'SYNC_REQUEST' | 'SYNC_RESPONSE'

// 定义同步消息接口
interface SyncMessage {
  type: SyncMessageType
  networkId: string
  deviceId: string
  deviceNickname: string
  timestamp: number
  data?: any
}

class SyncService {
  private isInitialized = false
  private isNetworkJoined = false
  private isJoiningNetwork = false // 跟踪是否正在加入网络
  private ydoc: Y.Doc | null = null
  private webrtcProvider: WebrtcProvider | null = null
  private yCardsArray: Y.Array<any> | null = null
  private persistence: IndexeddbPersistence | null = null
  private networkId: string | null = null
  private periodicBroadcastTimer: ReturnType<typeof setTimeout> | null = null

  /**
   * 初始化同步服务
   */
  initialize(): void {
    if (this.isInitialized) {
      console.log('[SyncService] 同步服务已初始化，跳过初始化');
      return;
    }

    console.log('[SyncService] 初始化同步服务');

    // 初始化Yjs文档
    this.ydoc = new Y.Doc();

    // 初始化Yjs数组用于存储卡片
    this.yCardsArray = this.ydoc.getArray('cards');

    // 初始化本地存储
    this.persistence = new IndexeddbPersistence('cardmind', this.ydoc);

    // 设置本地存储事件监听
    this.persistence.on('synced', () => {
      console.log('[SyncService] 本地存储同步完成');
      // 从Yjs文档同步到卡片状态
      this.syncYjsToCardStore();
    });

    // 设置Yjs数组变化监听
    this.yCardsArray.observe(() => {
      console.log('[SyncService] Yjs卡片数组发生变化，同步到卡片状态');
      this.syncYjsToCardStore();
    });

    this.isInitialized = true;
    console.log('[SyncService] 同步服务初始化完成');
  }

  /**
   * 加入网络
   */
  async joinNetwork(networkId: string, deviceId: string): Promise<boolean> {
    if (this.isNetworkJoined || this.isJoiningNetwork) {
      console.log('[SyncService] 已加入网络或正在加入网络，跳过');
      return true;
    }

    this.isJoiningNetwork = true;
    console.log('[SyncService] 尝试加入网络，网络ID:', networkId);

    try {
      // 初始化同步服务
      if (!this.isInitialized) {
        this.initialize();
      }

      // 设置网络ID
      this.networkId = networkId;

      // 初始化Awareness
      const awareness = new Awareness(this.ydoc as Y.Doc);
      awareness.setLocalStateField('deviceInfo', {
        deviceId,
        nickname: useDeviceStore.getState().nickname,
        deviceType: useDeviceStore.getState().deviceType,
        lastSeen: Date.now()
      });

      // 初始化WebRTC提供者
      this.webrtcProvider = new WebrtcProvider(networkId, this.ydoc as Y.Doc, {
        signaling: [], // 不使用公共信令服务器
        awareness,
        filterBcConns: false, // 允许通过BroadcastChannel进行信令
        maxConns: 10,
        peerOpts: {
          iceCandidatePoolSize: 10,
          iceServers: [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' }
          ]
        }
      });

      // 设置WebRTC连接状态监听
      if (this.webrtcProvider && typeof this.webrtcProvider.on === 'function') {
        this.webrtcProvider.on('status', (event) => {
          console.log('[SyncService] WebRTC状态更新:', event);
          useSyncStore.getState().setWebrtcStatus(event.connected ? 'connected' : 'disconnected');
          useSyncStore.getState().setSyncingStatus(!event.connected);
        });

        // 监听连接数量变化
        this.webrtcProvider.on('peers', (peers) => {
          const peerCount = Object.keys(peers).length;
          console.log('[SyncService] 连接的设备数量变化:', peerCount);
          useSyncStore.getState().updateConnectedDevices(peerCount);
        });
      }

      // 从Yjs文档同步到卡片状态
      this.syncYjsToCardStore();

      // 启动定期广播
      this.startPeriodicBroadcast();

      this.isNetworkJoined = true;
      this.isJoiningNetwork = false;

      console.log('[SyncService] 加入网络成功，网络ID:', networkId);
      return true;
    } catch (error) {
      console.error('[SyncService] 加入网络失败:', error);
      this.isJoiningNetwork = false;
      return false;
    }
  }

  /**
   * 离开网络
   */
  async leaveNetwork(): Promise<void> {
    if (!this.isNetworkJoined) {
      console.log('[SyncService] 未加入网络，跳过离开网络操作');
      return;
    }

    console.log('[SyncService] 离开网络');

    // 停止定期广播
    this.stopPeriodicBroadcast();

    // 关闭WebRTC连接
    if (this.webrtcProvider) {
      this.webrtcProvider.destroy();
      this.webrtcProvider = null;
    }

    // 重置状态
    this.isNetworkJoined = false;
    this.networkId = null;

    // 重置同步状态
    useSyncStore.getState().resetSyncState();

    console.log('[SyncService] 已离开网络');
  }

  /**
   * 从Yjs文档同步到卡片状态
   */
  private syncYjsToCardStore(): void {
    if (!this.yCardsArray) {
      return;
    }

    console.log('[SyncService] 从Yjs文档同步到卡片状态');

    // 获取Yjs数组中的卡片数据
    const yCards = this.yCardsArray.toArray();

    // 更新卡片状态
    useCardStore.getState().setCards(yCards as Card[]);

    // 更新同步状态
    useSyncStore.getState().updateLastSyncTime();
    useSyncStore.getState().setSyncStatus('completed');
  }

  /**
   * 从卡片状态同步到Yjs文档
   */
  syncCardStoreToYjs(): void {
    if (!this.ydoc || !this.yCardsArray) {
      console.error('[SyncService] Yjs文档未初始化，无法同步卡片状态到Yjs');
      return;
    }

    console.log('[SyncService] 从卡片状态同步到Yjs文档');

    // 获取卡片状态中的卡片数据
    const cards = useCardStore.getState().cards;

    // 更新Yjs数组
    this.ydoc.transact(() => {
      // 清空Yjs数组
      this.yCardsArray?.delete(0, this.yCardsArray.length);
      // 添加所有卡片到Yjs数组
      this.yCardsArray?.push(cards);
    });

    // 更新同步状态
    useSyncStore.getState().updateLastSyncTime();
    useSyncStore.getState().setSyncStatus('completed');
  }

  /**
   * 开始定期广播设备状态
   */
  private startPeriodicBroadcast(): void {
    // 每30秒广播一次设备状态
    this.periodicBroadcastTimer = setInterval(() => {
      this.broadcastDeviceStatus();
    }, 30000);
  }

  /**
   * 停止定期广播设备状态
   */
  private stopPeriodicBroadcast(): void {
    if (this.periodicBroadcastTimer) {
      clearInterval(this.periodicBroadcastTimer);
      this.periodicBroadcastTimer = null;
    }
  }

  /**
   * 广播设备状态
   */
  private broadcastDeviceStatus(): void {
    if (!this.networkId) {
      return;
    }

    const deviceId = useDeviceStore.getState().deviceId;
    const deviceNickname = useDeviceStore.getState().nickname;

    // 广播设备状态消息
    const message: SyncMessage = {
      type: 'DEVICE_UPDATE',
      networkId: this.networkId,
      deviceId,
      deviceNickname,
      timestamp: Date.now(),
      data: {
        deviceType: useDeviceStore.getState().deviceType,
        lastSeen: Date.now()
      }
    };

    // 通过BroadcastChannel广播消息
    this.sendBroadcastChannelMessage(message);
  }

  /**
   * 通过BroadcastChannel发送消息
   */
  private sendBroadcastChannelMessage(message: SyncMessage): void {
    try {
      // 创建BroadcastChannel
      const bc = new BroadcastChannel(`cardmind-${this.networkId}`);
      bc.postMessage(message);
      bc.close();
    } catch (error) {
      console.error('[SyncService] 发送BroadcastChannel消息失败:', error);
    }
  }

  /**
   * 获取连接状态
   */
  getConnectionStatus(): {
    isConnected: boolean
    peersCount: number
    isSyncing: boolean
  } {
    return {
      isConnected: useSyncStore.getState().webrtcStatus === 'connected',
      peersCount: useSyncStore.getState().connectedDevices,
      isSyncing: useSyncStore.getState().isSyncing
    };
  }

  /**
   * 获取当前网络ID
   */
  getNetworkId(): string | null {
    return this.networkId;
  }

  /**
   * 销毁同步服务
   */
  destroy(): void {
    console.log('[SyncService] 销毁同步服务');

    // 离开网络
    this.leaveNetwork();

    // 关闭本地存储连接
    if (this.persistence) {
      this.persistence.destroy();
      this.persistence = null;
    }

    // 销毁Yjs文档
    if (this.ydoc) {
      this.ydoc.destroy();
      this.ydoc = null;
    }

    // 重置状态
    this.isInitialized = false;
    this.isNetworkJoined = false;
    this.yCardsArray = null;

    console.log('[SyncService] 同步服务已销毁');
  }
}

// 导出单例实例
export default new SyncService();

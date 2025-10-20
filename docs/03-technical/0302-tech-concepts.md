# CardMind 技术概念文档

## 1. 核心技术概念

### 1.1 网络认证与设备管理

#### 1.1.1 网络ID生成机制
- **UUID v4**: 使用加密安全的随机UUID生成唯一网络标识符
- **可发现性**: 网络ID设计为易分享和识别的格式（如分组显示）
- **生成权限**: 每个设备都可以生成网络ID，无主次设备之分
- **唯一性保证**: 使用加密随机数生成，确保全球唯一性

#### 1.1.2 设备ID与昵称管理
- **设备ID生成**: 结合设备指纹和随机UUID生成持久化设备标识
- **本地存储**: 设备ID使用IndexedDB本地持久化存储，无需重复生成
- **设备昵称**: 用户友好的设备名称，默认使用设备类型+随机字符组合
- **个性化设置**: 支持用户自定义设备昵称，提升识别体验
- **冲突处理**: 当多设备昵称相同时，自动添加后缀确保唯一性

#### 1.1.3 网络发现与加入
- **WebRTC信令**: 通过WebRTC信令服务器实现设备发现
- **ICE/STUN协议**: 解决NAT穿透问题，确保设备间直接通信
- **身份验证**: 基于网络ID的简化身份验证机制
- **安全考虑**: 不依赖中央服务器存储身份信息，保护用户隐私

### 1.2 Yjs CRDT 同步机制

#### 1.2.1 CRDT 基本原理
- **CRDT**（Conflict-free Replicated Data Type）：无冲突复制数据类型，是一种在分布式系统中实现最终一致性的技术
- **自动合并**：不同设备上的修改可以自动合并，无需复杂的冲突解决算法
- **强最终一致性**：所有设备最终会收敛到相同状态，无论操作顺序如何
- **无中心化**：不依赖中央服务器进行数据同步和冲突解决

#### 1.2.2 Yjs 特性
- **高性能**：即使在高延迟网络环境下也能保持良好性能
- **可扩展性**：支持任意数量的并发编辑者
- **版本历史**：维护操作历史，支持撤销/重做
- **空间效率**：使用delta压缩减少传输数据量
- **持久化**：支持多种持久化方式，包括IndexedDB

#### 1.2.3 Yjs 数据结构
- **Y.Map**：类似于JavaScript对象，存储键值对
- **Y.Array**：类似于JavaScript数组，存储有序元素
- **Y.Text**：专门用于文本编辑的共享字符串类型
- **Y.Xml**：用于复杂文档结构的树状数据类型

### 1.3 双数据源工作方式

#### 1.3.1 双数据源设计理念
- **业务数据存储**：使用IndexedDB存储业务数据，提供结构化查询能力
- **同步数据层**：使用Yjs作为同步层，负责多设备间的实时同步
- **双向同步**：维护两个数据源之间的一致性，确保数据完整性
- **本地优先**：优先使用本地数据提供快速响应，同时保持与远程同步

#### 1.3.2 数据流向
- **写操作**：用户修改 → 更新IndexedDB → 更新Yjs文档 → 同步到其他设备
- **读操作**：优先从IndexedDB读取 → 必要时从Yjs同步
- **冲突解决**：基于时间戳的冲突解决策略，总是采用最新修改

#### 1.3.3 核心实现
```typescript
// 双数据源操作示例
async createCard(title: string, content: string): Promise<Card> {
  // 定义并初始化card对象
  const cardId = crypto.randomUUID();
  const now = Date.now();
  const card: Card = {
    id: cardId,
    title,
    content,
    createdAt: now,
    updatedAt: now,
    isDeleted: false
  };
  
  // 1. 保存到IndexedDB（业务数据）
  await this.db.cards.put(card);
  
  // 2. 创建Yjs文档（同步数据）
  const yDoc = new Y.Doc();
  const yMap = yDoc.getMap('card');
  
  // 重要：将card数据保存到Yjs文档中
  yMap.set('id', card.id);
  yMap.set('title', card.title);
  yMap.set('content', card.content);
  yMap.set('createdAt', card.createdAt);
  yMap.set('updatedAt', card.updatedAt);
  yMap.set('isDeleted', card.isDeleted);
  
  // 3. 配置Yjs持久化
  const persistence = new IndexeddbPersistence(`card-${cardId}`, yDoc);
  await persistence.whenSynced; // 等待持久化就绪
  
  // 4. 启用实时同步
  const provider = new WebrtcProvider(`card-${cardId}`, yDoc);
  
  // 5. 监听Yjs变化，自动同步到IndexedDB
  yMap.observe(() => {
    this.syncFromYjsToIndexedDB(cardId);
  });
  
  return card;
}
```

### 1.4 WebRTC 点对点通信

#### 1.4.1 WebRTC 基本原理
- **点对点连接**：直接在浏览器之间建立连接，无需经过服务器中转
- **NAT穿透**：使用ICE/STUN/TURN协议解决NAT穿透问题
- **加密通信**：所有WebRTC通信默认加密，保障数据安全

#### 1.4.2 y-webrtc 适配器
- **自动连接管理**：自动管理连接的建立、维护和断开
- **房间概念**：使用命名房间组织协作用户
- **意识协议**：跟踪在线用户状态和光标位置

### 1.5 端到端加密

#### 1.5.1 加密原理
- **客户端加密**：数据在客户端加密后再存储或传输
- **密钥派生**：使用PBKDF2从用户密码派生加密密钥
- **AES-256-GCM**：使用高级加密标准保障数据安全

#### 1.5.2 加密服务设计
```typescript
class EncryptionService {
  async generateKey(password: string): Promise<CryptoKey> {
    // 使用PBKDF2生成加密密钥
  }
  
  async encrypt(data: string, key: CryptoKey): Promise<EncryptedData> {
    // AES-256-GCM加密
  }
  
  async decrypt(encryptedData: EncryptedData, key: CryptoKey): Promise<string> {
    // AES-256-GCM解密
  }
}
```

## 2. 关键流程说明

### 2.1 网络认证流程
- **检查设备ID**：首次启动时生成设备ID，否则从本地存储读取
- **网络状态检查**：检查是否已加入网络或需要创建/加入网络
- **网络认证选择**：提供生成网络ID或输入现有网络ID选项
- **设备注册**：成功加入网络后，向网络注册设备信息和昵称
- **身份验证**：基于网络ID建立信任机制

### 2.2 应用启动流程
- **初始化IndexedDB**：创建或打开本地数据库，包含网络和设备表
- **加载设备信息**：读取设备ID和昵称
- **加载网络配置**：读取已保存的网络ID
- **建立WebRTC连接**：连接到协作网络
- **同步数据**：确保本地数据与网络中的最新数据一致
- **监听变更**：设置变更监听器，处理后续修改

### 2.2 数据操作同步流程
- **本地操作**：用户在一个设备上进行操作
- **本地保存**：保存到本地IndexedDB
- **同步标记**：在Yjs中标记变更
- **实时传播**：通过WebRTC传播变更到其他设备
- **远程应用**：其他设备接收并应用变更
- **双向同步**：确保两个数据源保持一致

### 2.3 离线模式处理
- **离线检测**：检测网络连接状态
- **本地操作**：即使离线也可以进行本地操作
- **变更缓存**：缓存未同步的变更
- **重连同步**：网络恢复后自动同步缓存的变更
- **冲突检测**：检测并解决离线期间产生的冲突

## 3. 数据模型与存储

### 3.1 核心数据实体
- **Card**：卡片实体，包含以下字段：
  - `id`：唯一标识符
  - `title`：卡片标题
  - `content`：卡片内容
  - `createdAt`：创建时间
  - `updatedAt`：更新时间
  - `isDeleted`：软删除标记
  - `lastModifiedBy`：最后修改设备ID

- **Network**：协作网络实体，作为顶层数据结构，包含以下字段：
  - `id`：网络唯一标识符（UUID）
  - `createdAt`：网络创建时间
  - `devices`：已加入设备列表（层级关系：Device作为Network的子级实体）
    - 每个Device作为独立的Y.Map对象存储在Network的Y.Array中
  - `lastActivity`：最后活动时间

- **Device**：设备实体，作为Network的子级实体，包含以下字段：
  - `id`：设备唯一标识符（结合设备指纹和随机UUID）
  - `nickname`：设备昵称（默认设备类型+随机字符）
  - `deviceType`：设备类型（桌面、移动设备等）
  - `createdAt`：设备记录创建时间
  - `lastSeen`：最后在线时间
  - 注：设备数据作为Network Yjs文档的一部分进行同步，体现了单层嵌套的层级结构

### 3.2 存储策略
- **业务数据**：使用Dexie.js管理IndexedDB，提供结构化查询能力
- **同步数据**：使用Yjs管理同步状态，每个卡片对应一个Yjs文档
- **持久化**：使用y-indexeddb持久化Yjs文档，防止应用重启后数据丢失
- **索引优化**：为常用查询字段创建索引，提高查询性能

### 3.3 软删除机制
- **标记删除**：通过`isDeleted`字段标记删除，而不是物理删除
- **可恢复性**：支持恢复已删除的卡片
- **性能考虑**：查询时过滤已删除数据，不影响正常使用体验
- **存储空间**：定期清理真正需要删除的历史数据（未来功能）
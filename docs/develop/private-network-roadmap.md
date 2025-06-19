# 去中心化组网功能开发路线图

## 1. 当前实现状态分析

### 已实现组件
- [x] 节点数据模型 (<mcfile name="network_node.dart" path="app\lib\shared\domain\models\network_node.dart"></mcfile>)
- [x] 节点DAO层 (<mcfile name="network_node_dao.dart" path="app\lib\shared\data\dao\network_node_dao.dart"></mcfile>)
- [x] 数据库表结构 (<mcfile name="database_manager.dart" path="app\lib\shared\data\database\database_manager.dart"></mcfile>)
- [x] 基础路由配置 (<mcfile name="app_router.dart" path="app\lib\desktop\screens\routes\app_router.dart"></mcfile>)

### 缺失组件
- [x] mDNS服务实现 (已实现基础功能)
- [x] WebSocket连接管理 (已实现基础连接)
- [x] 节点管理服务 (已实现基础功能)
- [x] 组网请求处理逻辑 (已通过HTTP API实现)
- ⬜ 数据同步服务

## 2. 开发阶段规划

### 阶段一：核心网络服务
1. **mDNS服务实现**
   - 使用`mdns`包实现局域网设备发现
   - 设计节点广播消息格式
   - 实现设备监听和解析逻辑

2. **WebSocket服务**
   - 基于`web_socket_channel`实现连接管理
   - 设计消息协议和心跳机制
   - 实现连接重试和状态监控

3. **节点管理服务**
   - 创建`NodeManagementService`类
   - 通过`DiscoveryProtocol`接口集成多种发现方式(mDNS/蓝牙等)
   - 实现节点全生命周期管理:
     * 状态监控
     * 信任关系
     * 连接策略

### 阶段二：组网流程
1. **组网请求处理**
   - 实现组网请求/响应协议
   - 添加权限验证逻辑
   - 设计UI确认流程

2. **节点管理**
   - 实现节点信任关系管理
   - 开发节点黑名单功能
   - 添加节点连接质量监控

### 阶段三：数据同步
1. **同步服务基础**
   - 扩展`SyncService`类
   - 设计增量同步协议
   - 实现冲突解决策略

2. **CRDT集成**
   - 对接现有`sqlite_crdt`实现
   - 添加同步状态追踪
   - 实现自动合并变更集

## 3. 关键实现细节

### 节点发现流程
```dart
// 伪代码示例
class NodeDiscoveryService {
  final mdns = MDnsDiscovery();
  final List<NetworkNode> discoveredNodes = [];
  
  void startDiscovery() {
    mdns.startDiscovery('_cardmind._tcp');
    mdns.onDiscovered = (serviceInfo) {
      final node = _parseServiceInfo(serviceInfo);
      _updateNodeList(node);
    };
  }
}
```

### WebSocket消息协议
```json
{
  "type": "sync_request",
  "payload": {
    "since": "2023-01-01T00:00:00Z",
    "table": "cards"
  }
}
```

## 4. 测试计划

1. **单元测试**
   - 节点发现服务测试
   - WebSocket连接测试
   - 数据同步冲突测试

2. **集成测试**
   - 多设备组网测试
   - 网络中断恢复测试
   - 大数据量同步测试

## 5. 后续优化方向

1. NAT穿透支持
2. 分布式数据索引
3. 端到端加密通信
4. 多网络适配器支持

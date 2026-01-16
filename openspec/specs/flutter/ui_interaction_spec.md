# Flutter UI 交互规格说明书

## 📋 规格编号: SP-FLUT-003
**版本**: 1.0.0  
**状态**: 待实施  
**依赖**: SP-SPM-001（单池模型核心规格）

---

## 1. 应用启动流程

### 1.1 初始化决策逻辑

**用户旅程**: 应用启动

```dart
/// Spec-FLUT-001: 根据 DeviceConfig 状态路由到不同页面
Future<Widget> determineInitialScreen() async {
  // 1. 检查设备状态
  final isInitialized = await api.checkInitializationStatus();
  
  // 2. 路由决策
  if (isInitialized) {
    // 已加入池 → 进入主页
    return HomeScreen();
  } else {
    // 未加入池 → 启动发现 + 显示选择界面
    return const OnboardingDecisionScreen();
  }
}
```

---

## 2. 首次启动 - 初始化向导

### 2.1 发现设备界面

**UI 规格**:
```dart
/// Spec-FLUT-002: 发现设备界面
class OnboardingDecisionScreen extends StatefulWidget {
  const OnboardingDecisionScreen({Key? key}) : super(key: key);
  
  @override
  State createState() => _OnboardingDecisionScreenState();
}

class _OnboardingDecisionScreenState extends State<OnboardingDecisionScreen> {
  List<DiscoveredPeer> peers = [];
  bool isDiscovering = true;
  
  @override
  void initState() {
    super.initState();
    // Spec: 启动 mDNS 发现
    startDiscovery();
  }
  
  Future<void> startDiscovery() async {
    // 订阅发现状态
    // 30秒超时
    // 更新 peers 列表
  }
}
```

**界面布局**:
```dart
// Spec-FLUT-002A: UI 布局结构
Column(
  children: [
    // 标题
    Text('欢迎使用 CardMind'),
    SizedBox(height: 32),
    
    // 状态提示
    if (isDiscovering) 
      CircularProgressIndicator(),
    
    // 发现的对等设备
    if (peers.isNotEmpty) ...[
      Text('发现附近的设备'),
      ListView.builder(
        itemCount: peers.length,
        itemBuilder: (context, index) {
          final peer = peers[index];
          return ListTile(
            leading: Icon(Icons.devices),
            title: Text(peer.deviceName),
            subtitle: Text('空间: ${peer.poolName}'),
            trailing: ElevatedButton(
              onPressed: () => _pairWithDevice(peer),
              child: Text('配对'),
            ),
          );
        },
      ),
    ],
    
    // 或新建
    ElevatedButton(
      onPressed: () => _showCreateDialog(),
      child: Text('创建新笔记空间'),
    ),
  ],
)
```

---

### 2.2 创建新空间界面

```dart
/// Spec-FLUT-003: 创建新空间对话框
class CreateSpaceDialog extends StatefulWidget {
  @override
  State createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends State<CreateSpaceDialog> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  
  void _createSpace() async {
    if (passwordController.text != confirmController.text) {
      // Spec: 密码不匹配错误提示
      showSnackBar('密码不匹配');
      return;
    }
    
    if (passwordController.text.length < 8) {
      // Spec: 密码强度验证
      showSnackBar('密码至少需要 8 位');
      return;
    }
    
    // Spec: 调用 Rust API 创建
    try {
      await api.initializeFirstTime(passwordController.text);
      
      // Spec: 成功 → 进入主页
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } catch (e) {
      // Spec: 错误处理
      showSnackBar('创建失败: $e');
    }
  }
}
```

**界面规格**:
```dart
// Spec-FLUT-003A: 创建界面布局
AlertDialog(
  title: Text('创建笔记空间'),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('为你的笔记空间设置密码'),
      SizedBox(height: 16),
      TextField(
        controller: passwordController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: '密码',
          hintText: '至少 8 位',
        ),
      ),
      TextField(
        controller: confirmController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: '确认密码',
        ),
      ),
      SizedBox(height: 16),
      Text(
        '此密码用于：\n'
        '• 保护你的笔记隐私\n'
        '• 在其他设备上同步',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    ],
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text('取消'),
    ),
    ElevatedButton(
      onPressed: _createSpace,
      child: Text('创建'),
    ),
  ],
)
```

---

### 2.3 配对设备界面

```dart
/// Spec-FLUT-004: 配对设备流程
class PairDeviceScreen extends StatefulWidget {
  final DiscoveredPeer peer;
  
  const PairDeviceScreen({Key? key, required this.peer}) : super(key: key);
  
  @override
  State createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final passwordController = TextEditingController();
  bool isPairing = false;
  
  void _pair() async {
    setState(() => isPairing = true);
    
    try {
      await api.joinExistingPool(
        widget.peer.poolId,
        passwordController.text,
      );
      
      // Spec: 成功 → 进入主页 + 触发同步
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } catch (e) {
      showSnackBar('配对失败: $e');
    } finally {
      setState(() => isPairing = false);
    }
  }
}
```

---

## 3. 主页 - 卡片列表

### 3.1 创建卡片（极简流程）

**变更对比**:

| 旧模型（多池） | 新模型（单池） |
|-------------|-------------|
| FAB 点击 → 选择池 → 选择常驻池 → 编辑器 | FAB 点击 → 直接进入编辑器 |

```dart
/// Spec-FLUT-005: 简化创建流程
class HomeScreen extends StatelessWidget {
  void _createNewCard() {
    // Spec: 直接进入编辑器，无需选择池
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CardEditorScreen()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewCard,
        child: Icon(Icons.add),
      ),
      body: CardList(),
    );
  }
}
```

---

### 3.2 卡片自动关联

```dart
/// Spec-FLUT-006: CardEditor 保存时自动关联当前池
class CardEditorScreen extends StatefulWidget {
  @override
  State createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  void _saveCard() async {
    try {
      // Spec: 移除 pool_id 参数，自动关联
      final card = await api.createCard(
        titleController.text,
        contentController.text,
      );
      
      // Spec: 成功后返回并刷新
      Navigator.pop(context);
      Provider.of<CardProvider>(context, listen: false).refresh();
    } catch (e) {
      showSnackBar('保存失败: $e');
    }
  }
}
```

**测试规格**:
```dart
// Spec-FLUT-006A: 集成测试
void test_createCard_withoutPoolSelection() async {
  // Given: 已加入数据池
  await ensureDeviceJoinedPool();
  
  // When: 点击 FAB → 编辑器 → 保存
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  
  await tester.enterText(find.byKey(titleKey), '测试标题');
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
  
  // Then: 返回主页，卡片已创建
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.text('测试标题'), findsOneWidget);
  
  // Spec: 验证卡片自动关联到当前池
  final card = Provider.of<CardProvider>(context, listen: false)
      .cards
      .firstWhere((c) => c.title == '测试标题');
  expect(card.poolId, isNotNull);
}
```

---

## 4. 设置页面

### 4.1 移除常驻池设置

**变更内容**:
```dart
// Spec-FLUT-007: SettingsScreen - 移除常驻池配置
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 旧：Pool Management Tile（已移除）
        // ListTile(
        //   title: Text('数据池管理'),
        //   onTap: () => _showPoolManagement(),
        // ),
        
        // 新：退出笔记空间（高级设置）
        ListTile(
          title: Text('退出笔记空间'),
          subtitle: Text('清除所有本地数据'),
          leading: Icon(Icons.exit_to_app, color: Colors.red),
          onTap: () => _confirmLeavePool(context),
        ),
      ],
    );
  }
  
  void _confirmLeavePool(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认退出？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚠️ 警告：'),
            SizedBox(height: 8),
            Text('• 此设备上的所有卡片将被删除'),
            Text('• 其他设备不受影响'),
            Text('• 退出后可以加入其他笔记空间'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _leavePool(context),
            child: Text('确认退出'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _leavePool(BuildContext context) async {
    try {
      await api.leavePool();
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // 关闭对话框
      }
      // Spec: 跳转到初始化页面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingDecisionScreen()),
      );
    } catch (e) {
      showSnackBar('退出失败: $e');
    }
  }
}
```

---

## 5. UI 术语统一

### 5.1 文本替换规格

| 旧术语 | 新术语 | 位置 |
|-------|-------|-----|
| 数据池 | 笔记空间 | 所有 UI 文本 |
| 创建数据池 | 创建笔记空间 | 按钮、对话框 |
| 加入数据池 | 配对设备 | 发现界面 |
| 常驻池 | （移除）| 设置页面 |
| 池管理 | 退出笔记空间 | 设置页面 |

**实现方式**:
```dart
// Spec-FLUT-008: 统一术语
class AppStrings {
  static const createPool = '创建笔记空间'; // 旧: 创建数据池
  static const pairDevice = '配对设备';     // 旧: 加入数据池
  static const poolName = '笔记空间';       // 旧: 数据池
  static const leaveSpace = '退出笔记空间'; // 新增
}
```

---

## 6. 验证清单

### 6.1 UI 测试（Widget Test）

```bash
# 运行 Flutter 规格测试
flutter test test/specs/ui_interaction_spec.dart
```

**测试场景**:
- [ ] FLUT-001: 初始化路由决策
- [ ] FLUT-002: 发现设备界面
- [ ] FLUT-003: 创建空间流程
- [ ] FLUT-004: 配对设备流程
- [ ] FLUT-005: 简化创建流程（FAB）
- [ ] FLUT-006: 卡片自动关联到当前池
- [ ] FLUT-007: 设置页面 - 退出空间
- [ ] FLUT-008: 术语统一

### 6.2 集成测试（Integration Test）

```bash
# 完整 E2E 测试
flutter drive --target=test_driver/app.dart
```

**场景覆盖**:
1. 新用户首次启动 → 创建空间 → 创建卡片
2. 第N台设备启动 → 发现设备 → 配对 → 同步
3. 卡片创建 → 验证自动关联 → 跨设备同步
4. 移除卡片 → 验证传播 → 跨设备确认
5. 退出空间 → 验证数据清空

---

## 7. 实施优先级

### 🔴 第一阶段（阻塞）
- FLUT-002, FLUT-003, FLUT-004: 初始化向导
- FLUT-005, FLUT-006: 简化创建流程

### 🟡 第二阶段（重要）
- FLUT-007: 设置页面调整
- FLUT-008: 术语统一

### 🟢 第三阶段（可选）
- 增强发现动画
- 优化空状态提示

---

**规格编号**: SP-FLUT-003  
**实现优先级**: 🔴 高（与 Rust API 改造并行）  
**依赖**: 需要 Rust API 完成后端改造  
**状态**: 待实施

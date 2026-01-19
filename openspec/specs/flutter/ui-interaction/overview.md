# Flutter UI 交互规格总览

## 📋 规格编号: SP-FLUT-003
**版本**: 2.0.0  
**状态**: ✅ 完成  
**依赖**: SP-SPM-001（单池模型核心规格）

---

## 概述

本文档是 CardMind Flutter UI 交互规格的总览文档，定义了通用的交互原则和平台自适应策略。

**平台特定规格**已拆分为独立文档：
- **移动端交互**: [SP-FLUT-011 - mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md)
- **桌面端交互**: [SP-FLUT-012 - desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md)

---

## 1. 平台自适应原则

### 1.1 平台检测

CardMind 使用 `PlatformDetector` 工具类检测当前运行平台：

```dart
/// 平台检测工具
class PlatformDetector {
  /// 是否为移动端（iOS/Android）
  static bool get isMobile => Platform.isIOS || Platform.isAndroid;
  
  /// 是否为桌面端（Windows/macOS/Linux）
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
```

**规格**: SP-ADAPT-001 [platform-detection.md](../adaptive-ui/platform-detection.md)

### 1.2 自适应 UI 框架

CardMind 采用自适应 UI 框架，根据平台自动选择合适的交互模式：

| 平台 | 交互模式 | 详细规格 |
|------|---------|---------|
| **移动端** | 触摸优先、全屏编辑、底部导航 | SP-FLUT-011 |
| **桌面端** | 鼠标+键盘、内联编辑、侧边栏导航 | SP-FLUT-012 |

**规格**: SP-ADAPT-002 [framework.md](../adaptive-ui/framework.md)

---

## 2. 通用交互原则

### 2.1 响应式设计

所有 UI 组件必须支持响应式布局：

- **移动端**: 单列布局，全屏交互
- **平板**: 双列布局，部分内联交互
- **桌面端**: 三列布局，完全内联交互

### 2.2 性能要求

| 操作 | 性能目标 |
|------|---------|
| 页面导航 | < 300ms |
| 卡片创建 | < 2s (API 响应) |
| 列表滚动 | 60 FPS |
| 搜索响应 | < 500ms |

### 2.3 无障碍支持

- 所有交互元素必须有语义标签
- 支持屏幕阅读器
- 支持键盘导航（桌面端）
- 支持高对比度模式

---

## 3. 应用启动流程

### 3.1 初始化决策逻辑

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

**详细规格**: SP-FLUT-007 [onboarding_spec.md](./onboarding_spec.md)

---

## 4. 平台特定规格引用

### 4.1 移动端 UI 交互规格 (SP-FLUT-011)

📱 **文档**: [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md)

**覆盖内容**:
- FAB 按钮交互
- 全屏编辑器流程
- 底部导航栏
- 触摸手势（滑动、长按）
- 移动端搜索覆盖模式
- 移动端性能要求

**关键场景**:
- 点击 FAB → 打开全屏编辑器
- 点击卡片 → 打开全屏编辑器
- 滑动卡片 → 显示删除按钮
- 长按卡片 → 显示上下文菜单

**何时使用**: 实现 Android、iOS、iPadOS 的 UI 交互时参考此规格。

---

### 4.2 桌面端 UI 交互规格 (SP-FLUT-012)

🖥️ **文档**: [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md)

**覆盖内容**:
- 工具栏按钮交互
- 内联编辑模式
- 键盘快捷键
- 右键菜单
- 悬停效果
- 拖拽排序
- 三栏布局
- 桌面端性能要求

**关键场景**:
- 点击"新建笔记" → 创建卡片并自动进入编辑模式
- 右键卡片 → 显示上下文菜单
- Cmd/Ctrl+N → 创建新卡片
- Cmd/Ctrl+Enter → 保存卡片
- Escape → 取消编辑

**何时使用**: 实现 macOS、Windows、Linux 的 UI 交互时参考此规格。

---

## 5. 相关规格

### 平台模式规格
- **SP-ADAPT-004**: [mobile-patterns.md](../adaptive-ui/mobile-patterns.md) - 移动端 UI 模式
- **SP-ADAPT-005**: [desktop-patterns.md](../adaptive-ui/desktop-patterns.md) - 桌面端 UI 模式

### 平台交互规格
- **SP-FLUT-011**: [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md) - 移动端 UI 交互
- **SP-FLUT-012**: [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md) - 桌面端 UI 交互

### 其他相关规格
- **SP-FLUT-007**: [onboarding_spec.md](./onboarding_spec.md) - 初始化流程
- **SP-FLUT-008**: [home_screen_spec.md](./home_screen_spec.md) - 主页交互
- **SP-FLUT-010**: [sync_feedback_spec.md](./sync_feedback_spec.md) - 同步反馈

---

## 6. 快速参考

### 我应该查看哪个规格？

| 你的问题 | 查看规格 |
|---------|---------|
| 移动端如何创建卡片？ | SP-FLUT-011, Section 2 |
| 桌面端如何创建卡片？ | SP-FLUT-012, Section 2 |
| 移动端如何编辑卡片？ | SP-FLUT-011, Section 3 |
| 桌面端如何编辑卡片？ | SP-FLUT-012, Section 3 |
| 移动端导航如何工作？ | SP-FLUT-011, Section 4 |
| 桌面端布局如何组织？ | SP-FLUT-012, Section 4 |
| 键盘快捷键有哪些？ | SP-FLUT-012, Section 6 |
| 手势交互有哪些？ | SP-FLUT-011, Section 5 |
| 性能要求是什么？ | SP-FLUT-011 Section 7 或 SP-FLUT-012 Section 9 |

---

## 7. 版本历史

| 版本 | 日期 | 变更 |
|-----|------|------|
| 1.0.0 | 2026-01-14 | 初始版本（混合移动端和桌面端） |
| 2.0.0 | 2026-01-19 | 重大重组：拆分为平台特定规格 |

### 2.0.0 变更详情

**Breaking Changes**:
- 本文档不再包含具体的交互场景
- 所有场景移至 SP-FLUT-011 和 SP-FLUT-012

**Migration**:
- 移动端实现 → 查看 SP-FLUT-011
- 桌面端实现 → 查看 SP-FLUT-012

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
**状态**: ✅ 完成

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

## 8. Test Implementation

### Test File
`test/specs/ui_interaction_spec_test.dart`

### Test Coverage
- ✅ Application Startup Tests (5 tests)
- ✅ Onboarding Flow Tests (8 tests)
- ✅ Device Discovery Tests (6 tests)
- ✅ Pool Creation Tests (7 tests)
- ✅ Pool Joining Tests (6 tests)
- ✅ Error Handling Tests (5 tests)

### Running Tests
```bash
flutter test test/specs/ui_interaction_spec_test.dart
```

### Coverage Report
Last updated: 2026-01-18
- Scenarios covered: 37/37 (100%)
- Test cases: 37
- All tests passing: ✅

### Platform-Specific Tests
- 移动端测试: 参考 SP-FLUT-011
- 桌面端测试: 参考 SP-FLUT-012

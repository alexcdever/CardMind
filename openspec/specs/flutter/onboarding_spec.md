# 初始化流程规格说明书

## 📋 规格编号: SP-FLUT-007
**依赖**: SP-SPM-001（单池模型核心规格）, SP-DEV-002（DeviceConfig）  
**版本**: 1.0.0  
**状态**: 待实施

---

## 1. 概述

### 1.1 目标
定义CardMind Flutter应用的初始化流程，确保：
- 用户首次使用时正确引导
- 与DeviceConfig的join_pool机制无缝集成
- 本地存储和同步服务正确初始化

### 1.2 初始化流程概述
```
首次启动 → 欢迎页 → 创建/加入池 → 初始化完成 → 主页
```

---

## 2. 状态管理

### 2.1 App状态枚举
```dart
enum AppInitializationStatus {
  /// 初始状态
  initial,
  
  /// 欢迎页
  welcome,
  
  /// 选择操作：创建池或加入池
  selectAction,
  
  /// 创建新池
  creatingPool,
  
  /// 加入现有池
  joiningPool,
  
  /// 初始化存储和服务
  initializing,
  
  /// 初始化完成，可进入主页
  completed,
  
  /// 错误状态
  error,
}
```

### 2.2 初始化状态模型
```dart
class OnboardingState extends ChangeNotifier {
  AppInitializationStatus _status = AppInitializationStatus.initial;
  String? _currentPoolId;
  String? _errorMessage;
  bool _isLoading = false;
  
  // Getters
  AppInitializationStatus get status => _status;
  String? get currentPoolId => _currentPoolId;
  bool get isLoading => _isLoading;
  
  // State transitions
  Future<void> startOnboarding() async { ... }
  Future<void> createNewPool(String poolName, String? password) async { ... }
  Future<void> joinExistingPool(String poolId, String? password) async { ... }
  Future<void> completeInitialization() async { ... }
  void retry() { ... }
}
```

---

## 3. 流程规格

### 3.1 首次启动流程

#### Spec-ONB-001: 检测首次使用
```dart
/// it_should_show_welcome_page_on_first_launch()
Widget build(BuildContext context) {
  return FutureBuilder<bool>(
    future: _checkIsFirstLaunch(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return SplashScreen();
      }
      
      if (snapshot.data == true) {
        return WelcomePage();
      }
      
      return FutureBuilder<DeviceConfig>(
        future: _loadDeviceConfig(),
        builder: (context, configSnapshot) {
          if (configSnapshot.hasData && configSnapshot.data!.poolId != null) {
            return HomeScreen();
          }
          return WelcomePage();
        },
      );
    },
  );
}

/// it_should_detect_first_launch_by_checking_device_config()
Future<bool> _checkIsFirstLaunch() async {
  final config = await DeviceConfigApi.getDeviceConfig();
  return config == null;
}
```

#### Spec-ONB-002: 欢迎页交互
```dart
/// it_should_navigate_to_select_action_on_get_started()
class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<OnboardingState>(context);
    
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('欢迎使用 CardMind'),
          ElevatedButton(
            onPressed: () => state.startOnboarding(),
            child: Text('开始使用'),
          ),
        ],
      ),
    );
  }
}
```

### 3.2 创建池流程

#### Spec-ONB-003: 创建新池
```dart
/// it_should_create_pool_and_join_it()
Future<void> createNewPool(String poolName, String? password) async {
  setLoading(true);
  
  try {
    // 1. 调用API创建池
    final poolId = await PoolApi.createPool(poolName, password);
    
    // 2. DeviceConfig加入池
    await DeviceConfigApi.joinPool(poolId);
    
    // 3. 初始化CardStore
    await CardStoreApi.initCardStore();
    
    // 4. 启动同步服务
    await SyncApi.startSync();
    
    // 5. 更新状态
    _currentPoolId = poolId;
    _status = AppInitializationStatus.completed;
    
  } catch (e) {
    _errorMessage = e.toString();
    _status = AppInitializationStatus.error;
  } finally {
    setLoading(false);
  }
}

/// it_should_show_error_when_pool_creation_fails()
Widget buildCreatePoolPage() {
  return Column(
    children: [
      TextField(
        onChanged: (value) => _poolName = value,
        decoration: InputDecoration(labelText: '笔记空间名称'),
      ),
      TextField(
        onChanged: (value) => _password = value,
        decoration: InputDecoration(labelText: '密码（可选）'),
      ),
      ElevatedButton(
        onPressed: () => state.createNewPool(_poolName, _password),
        child: Text('创建'),
      ),
    ],
  );
}
```

### 3.3 加入池流程

#### Spec-ONB-004: 加入现有池
```dart
/// it_should_join_existing_pool_with_password()
Future<void> joinExistingPool(String poolId, String? password) async {
  setLoading(true);
  
  try {
    // 1. 验证池存在且密码正确
    await PoolApi.verifyPoolPassword(poolId, password);
    
    // 2. DeviceConfig加入池
    await DeviceConfigApi.joinPool(poolId);
    
    // 3. 同步现有数据
    await SyncApi.startSync();
    await SyncApi.waitForSyncComplete();
    
    // 4. 更新状态
    _currentPoolId = poolId;
    _status = AppInitializationStatus.completed;
    
  } catch (e) {
    _errorMessage = '加入失败: $e';
    _status = AppInitializationStatus.error;
  } finally {
    setLoading(false);
  }
}

/// it_should_reject_wrong_password()
Future<void> testWrongPassword() async {
  expect(
    () => PoolApi.verifyPoolPassword('pool-001', 'wrong-password'),
    throwsA(isA<WrongPasswordException>()),
  );
}
```

---

## 4. 测试规格

### 4.1 状态转换测试
```dart
/// it_should_transition_from_welcome_to_select_action()
test('transition from welcome to select action', () {
  final state = OnboardingState();
  
  state.startOnboarding();
  
  expect(state.status, AppInitializationStatus.selectAction);
});

/// it_should_complete_initialization_after_creating_pool()
test('complete initialization after creating pool', () async {
  final state = OnboardingState();
  
  await state.createNewPool('My Notes', null);
  
  expect(state.status, AppInitializationStatus.completed);
  expect(state.currentPoolId, isNotNull);
});
```

### 4.2 错误处理测试
```dart
/// it_should_show_error_when_creating_pool_fails()
test('show error when pool creation fails', () async {
  final state = OnboardingState();
  
  await state.createNewPool('My Notes', 'wrong-password');
  
  expect(state.status, AppInitializationStatus.error);
  expect(state.errorMessage, isNotNull);
});

/// it_should_allow_retry_on_error()
test('allow retry on error', () async {
  final state = OnboardingState();
  state.status = AppInitializationStatus.error;
  
  state.retry();
  
  expect(state.status, AppInitializationStatus.selectAction);
});
```

---

## 5. 实施检查清单

- [ ] 实现`AppInitializationStatus`枚举
- [ ] 实现`OnboardingState`状态管理
- [ ] 实现欢迎页UI
- [ ] 实现创建池流程
- [ ] 实现加入池流程
- [ ] 编写单元测试
- [ ] 编写集成测试
- [ ] 验证与Rust API的桥接

---

## 6. 版本历史

| 版本 | 日期 | 变更 |
|-----|------|------|
| 1.0.0 | 2026-01-14 | 初始版本 |

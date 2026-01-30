import 'package:cardmind/bridge/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

/// 集成测试环境初始化
///
/// 用于需要 Rust Bridge 的集成测试
class IntegrationTestEnvironment {
  static bool _initialized = false;

  /// 初始化集成测试环境
  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    TestWidgetsFlutterBinding.ensureInitialized();

    try {
      // 初始化 Rust Bridge
      await RustLib.init();
      _initialized = true;
      print('✅ Integration test environment initialized');
    } catch (e) {
      print('⚠️ Failed to initialize Rust Bridge: $e');
      print('   Integration tests requiring Rust Bridge will be skipped');
    }
  }

  /// 检查是否已初始化
  static bool get isInitialized => _initialized;

  /// 清理测试环境
  static Future<void> cleanup() async {
    // 清理逻辑（如果需要）
  }
}

/// 集成测试辅助函数
///
/// 用于跳过需要 Rust Bridge 但未初始化的测试
void integrationTest(
  String description,
  Future<void> Function(WidgetTester) callback, {
  bool skip = false,
}) {
  testWidgets(description, (WidgetTester tester) async {
    if (!IntegrationTestEnvironment.isInitialized) {
      // 跳过需要 Rust Bridge 的测试
      print('⏭️  Skipping: $description (Rust Bridge not initialized)');
      return;
    }

    await callback(tester);
  }, skip: skip);
}

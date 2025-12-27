# CardMind 日志规范

本文档提供开箱即用的日志方案，适用于Rust和Flutter两端。

## 为什么需要日志？

- 🐛 **调试问题**: 快速定位bug发生的位置和原因
- 📊 **追踪流程**: 了解程序执行流程和状态变化
- ⚠️ **监控异常**: 及时发现和处理错误
- 📈 **性能分析**: 记录耗时操作，优化性能

---

## Rust侧 - 使用tracing

### 安装依赖

在`rust/Cargo.toml`中添加：

```toml
[dependencies]
# 日志框架（推荐使用tracing，性能好且功能强大）
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
```

### 初始化日志系统

在`rust/src/lib.rs`中添加：

```rust
use tracing_subscriber;

/// 初始化日志系统
/// 应该在应用启动时调用一次
pub fn init_logger() {
    tracing_subscriber::fmt()
        // 设置日志级别（可通过RUST_LOG环境变量覆盖）
        .with_max_level(tracing::Level::INFO)
        // 显示目标模块
        .with_target(true)
        // 显示代码位置（文件名和行号）
        .with_file(true)
        .with_line_number(true)
        // 时间戳格式
        .with_timer(tracing_subscriber::fmt::time::time())
        .init();
}
```

### 使用日志

```rust
use tracing::{info, warn, error, debug, trace};

// 1. 信息日志（重要操作）
info!("创建卡片: title={}", title);

// 2. 警告日志（潜在问题）
warn!("卡片标题为空: id={}", id);

// 3. 错误日志（必须修复的问题）
error!("创建卡片失败: {}", e);

// 4. 调试日志（开发时有用）
debug!("Loro文档状态: {:?}", doc);

// 5. 追踪日志（非常详细的信息）
trace!("进入create_card函数");
```

### 实际应用示例

```rust
// src/store/card_store.rs

use tracing::{info, error, debug};

impl CardStore {
    pub fn create_card(&mut self, title: &str, content: &str) -> Result<Card> {
        info!("开始创建卡片: title=\"{}\"", title);

        let id = Self::generate_card_id();
        debug!("生成卡片ID: {}", id);

        let doc = match self.load_or_create_card_doc(&id) {
            Ok(d) => d,
            Err(e) => {
                error!("加载Loro文档失败: id={}, error={}", id, e);
                return Err(e);
            }
        };

        // 写入数据
        let card_map = doc.get_map("card");
        card_map.insert("id", id.clone())?;
        card_map.insert("title", title)?;
        card_map.insert("content", content)?;

        doc.commit();
        debug!("Loro文档已commit: id={}", id);

        self.save_card(&id, doc)?;
        info!("卡片创建成功: id={}", id);

        Ok(card)
    }

    pub fn delete_card(&mut self, id: &str) -> Result<()> {
        info!("删除卡片: id={}", id);

        let doc = self.load_or_create_card_doc(id).map_err(|e| {
            error!("加载卡片失败: id={}, error={}", id, e);
            e
        })?;

        let card_map = doc.get_map("card");
        card_map.insert("is_deleted", true)?;

        doc.commit();
        self.save_card(id, doc)?;

        info!("卡片已软删除: id={}", id);
        Ok(())
    }
}
```

### 日志级别说明

| 级别 | 使用场景 | 示例 |
|------|----------|------|
| `error!` | 错误，必须修复 | 文件写入失败、数据库连接失败 |
| `warn!` | 警告，需要关注 | 空标题、超长内容、配置项缺失 |
| `info!` | 重要信息，默认显示 | 卡片创建、删除、同步完成 |
| `debug!` | 调试信息，开发时使用 | 函数参数、中间状态 |
| `trace!` | 追踪信息，非常详细 | 函数进入/退出、循环迭代 |

---

## Flutter侧 - 使用logger包

### 安装依赖

在`pubspec.yaml`中添加：

```yaml
dependencies:
  logger: ^2.0.0
```

### 初始化日志系统

在`lib/main.dart`中添加：

```dart
import 'package:logger/logger.dart';

// 全局logger实例
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,     // 显示调用栈层数
    errorMethodCount: 8, // 错误时显示更多调用栈
    lineLength: 120,    // 每行字符数
    colors: true,       // 彩色输出
    printEmojis: true,  // 使用emoji（可选）
    printTime: true,    // 显示时间
  ),
  level: Level.info,    // 默认级别
);

// 生产环境可以使用简化版
final logger = Logger(
  printer: SimplePrinter(colors: false),
  level: Level.warning,  // 生产环境只显示警告和错误
);
```

### 使用日志

```dart
import 'package:card_mind/main.dart'; // 导入logger

// 1. 信息日志
logger.i('创建卡片: $title');

// 2. 调试日志
logger.d('API调用参数: title=$title, content=$content');

// 3. 警告日志
logger.w('卡片标题为空');

// 4. 错误日志
logger.e('创建卡片失败', error: e, stackTrace: stackTrace);

// 5. 严重错误
logger.f('致命错误: 数据库初始化失败');
```

### 实际应用示例

```dart
// lib/services/card_service.dart

import 'package:card_mind/main.dart'; // logger
import 'package:card_mind/bridge/bridge_generated.dart';

class CardService {
  final api = CardMindApi();

  Future<void> init(String dataDir) async {
    logger.i('初始化CardService: dataDir=$dataDir');

    try {
      await api.initCardStore(dataDir: dataDir);
      logger.i('CardService初始化成功');
    } catch (e, stackTrace) {
      logger.e('CardService初始化失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Card> createCard(String title, String content) async {
    logger.i('创建卡片: title="$title"');
    logger.d('内容长度: ${content.length}字符');

    try {
      final card = await api.createCard(title: title, content: content);
      logger.i('卡片创建成功: id=${card.id}');
      return card;
    } catch (e, stackTrace) {
      logger.e('创建卡片失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<Card>> getAllCards() async {
    logger.d('获取所有卡片');

    try {
      final cards = await api.getAllCards();
      logger.i('获取卡片成功: 共${cards.length}张');
      return cards;
    } catch (e, stackTrace) {
      logger.e('获取卡片失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteCard(String id) async {
    logger.i('删除卡片: id=$id');

    try {
      await api.deleteCard(id: id);
      logger.i('卡片删除成功');
    } catch (e, stackTrace) {
      logger.e('删除卡片失败: id=$id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
```

### Provider中使用日志

```dart
// lib/providers/card_provider.dart

import 'package:flutter/foundation.dart';
import 'package:card_mind/main.dart'; // logger

class CardProvider with ChangeNotifier {
  List<Card> _cards = [];
  bool _isLoading = false;

  List<Card> get cards => _cards;
  bool get isLoading => _isLoading;

  Future<void> loadCards() async {
    logger.d('CardProvider: 开始加载卡片');

    _isLoading = true;
    notifyListeners();

    try {
      _cards = await cardService.getAllCards();
      logger.i('CardProvider: 卡片加载成功，共${_cards.length}张');
    } catch (e, stackTrace) {
      logger.e('CardProvider: 卡片加载失败', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCard(String title, String content) async {
    logger.i('CardProvider: 创建卡片');

    try {
      final card = await cardService.createCard(title, content);
      _cards.insert(0, card);  // 添加到列表开头
      notifyListeners();
      logger.i('CardProvider: 卡片添加到列表');
    } catch (e) {
      logger.e('CardProvider: 创建卡片失败', error: e);
      rethrow;
    }
  }
}
```

---

## 调试技巧

### Rust端

#### 1. 设置日志级别

通过`RUST_LOG`环境变量控制：

```bash
# 显示所有级别的日志
RUST_LOG=trace flutter run

# 只显示info及以上
RUST_LOG=info flutter run

# 显示debug及以上
RUST_LOG=debug flutter run

# 只显示特定模块的debug日志
RUST_LOG=card_mind::store=debug flutter run

# 多个模块
RUST_LOG=card_mind::store=debug,card_mind::api=info flutter run
```

#### 2. 过滤特定内容

```bash
# 只看包含"卡片"的日志
flutter run 2>&1 | grep "卡片"

# 只看错误日志
flutter run 2>&1 | grep "ERROR"
```

#### 3. 保存日志到文件

```bash
flutter run 2>&1 | tee app.log
```

### Flutter端

#### 1. 动态调整日志级别

```dart
// 开发环境
if (kDebugMode) {
  logger.level = Level.debug;
} else {
  // 生产环境
  logger.level = Level.warning;
}
```

#### 2. 条件日志

```dart
// 只在调试模式下记录
if (kDebugMode) {
  logger.d('调试信息: $data');
}
```

#### 3. 自定义日志输出

```dart
class MyLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // 保存到文件、上报到服务器等
    for (var line in event.lines) {
      print(line);
      // saveToFile(line);
    }
  }
}

final logger = Logger(
  printer: PrettyPrinter(),
  output: MyLogOutput(),
);
```

---

## 最佳实践

### 1. 日志内容规范

**好的日志**：
```rust
// ✅ 清晰明确
info!("创建卡片成功: id={}, title=\"{}\"", card.id, card.title);

// ✅ 包含上下文
error!("保存卡片失败: id={}, path={}, error={}", id, path.display(), e);
```

**不好的日志**：
```rust
// ❌ 信息不足
info!("创建卡片");

// ❌ 过于冗长
debug!("The card with id {} and title {} was created at {} with content {} ...", ...);
```

### 2. 敏感信息处理

```rust
// ❌ 不要记录敏感信息
info!("用户密码: {}", password);

// ✅ 只记录非敏感信息
info!("用户登录: username={}", username);

// ✅ 对敏感信息脱敏
info!("卡片内容预览: {}...", content.chars().take(20).collect::<String>());
```

### 3. 性能考虑

```rust
// ❌ 避免昂贵的字符串格式化（如果日志级别不够，这些计算会白费）
debug!("数据详情: {}", expensive_to_format_data());

// ✅ 使用惰性求值
debug!("数据详情: {:?}", data);  // {:?}只在需要时才格式化
```

### 4. 日志层次

```
应用启动 → info
    ↓
重要操作（CRUD） → info
    ↓
函数调用详情 → debug
    ↓
循环迭代、条件分支 → trace
    ↓
错误异常 → error/warn
```

### 5. 错误日志包含上下文

```rust
// ❌ 缺少上下文
error!("操作失败");

// ✅ 包含详细上下文
error!(
    "保存卡片失败: id={}, path={}, error={}",
    card_id,
    file_path.display(),
    e
);
```

---

## 常见问题

### Q1: 如何在发布版本中禁用调试日志？

**Rust**:
```rust
// 编译时剥离trace和debug日志
#[cfg(not(debug_assertions))]
tracing_subscriber::fmt()
    .with_max_level(tracing::Level::INFO)
    .init();

#[cfg(debug_assertions)]
tracing_subscriber::fmt()
    .with_max_level(tracing::Level::DEBUG)
    .init();
```

**Flutter**:
```dart
final logger = Logger(
  level: kDebugMode ? Level.debug : Level.warning,
);
```

### Q2: 日志太多影响性能怎么办？

1. **生产环境提高日志级别**（只保留info/warn/error）
2. **避免循环中打印debug日志**
3. **使用异步日志**（tracing默认是异步的）

### Q3: 如何保存日志到文件？

**Rust** (需要额外库):
```toml
[dependencies]
tracing-appender = "0.2"
```

```rust
use tracing_appender::rolling::{RollingFileAppender, Rotation};

let file_appender = RollingFileAppender::new(Rotation::DAILY, "logs", "cardmind.log");
tracing_subscriber::fmt()
    .with_writer(file_appender)
    .init();
```

**Flutter**:
自定义`LogOutput`写入文件。

### Q4: 如何在Release模式看到Rust日志?

```bash
# Android
adb logcat | grep "cardmind"

# iOS
idevicesyslog | grep "cardmind"

# Windows/macOS/Linux
flutter run --release
```

---

## 示例：完整的日志集成

### Rust侧（lib.rs）

```rust
use tracing_subscriber;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // 初始化日志
    init_logger();

    tracing::info!("CardMind应用启动");
}

fn init_logger() {
    #[cfg(debug_assertions)]
    let level = tracing::Level::DEBUG;

    #[cfg(not(debug_assertions))]
    let level = tracing::Level::INFO;

    tracing_subscriber::fmt()
        .with_max_level(level)
        .with_target(true)
        .with_file(true)
        .with_line_number(true)
        .init();
}
```

### Flutter侧（main.dart）

```dart
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

// 全局logger
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
  level: kDebugMode ? Level.debug : Level.info,
);

void main() async {
  logger.i('CardMind Flutter应用启动');

  // 捕获全局错误
  FlutterError.onError = (details) {
    logger.e('Flutter错误', error: details.exception, stackTrace: details.stack);
  };

  runApp(MyApp());
}
```

---

## 总结

### 快速开始清单

- [ ] Rust: 添加`tracing`和`tracing-subscriber`依赖
- [ ] Rust: 在`lib.rs`调用`init_logger()`
- [ ] Flutter: 添加`logger`依赖
- [ ] Flutter: 在`main.dart`创建全局`logger`实例
- [ ] 在关键操作中添加`info!`日志
- [ ] 在错误处理中添加`error!`日志
- [ ] 测试日志输出：`RUST_LOG=debug flutter run`

### 记住

- **开发时**: 多用`debug!`帮助调试
- **生产时**: 只保留`info!`/`warn!`/`error!`
- **错误时**: 一定要记录上下文信息
- **性能时**: 避免在热路径上频繁打日志

日志是你调试问题的最好朋友，用好它！🔍

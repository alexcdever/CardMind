# Rust 边界扫描器实施计划

## 现状

当前测试边界扫描器**仅支持 Dart/Flutter 代码**，使用 `dart analyzer` 包解析 AST。

Rust 代码（`rust/src/`）**未被扫描**。

## 目标

实现 Rust 边界扫描器，能够：
1. 识别 Rust 代码中的边界条件（if/match/Result/? 等）
2. 收集 Rust 测试覆盖率（使用 cargo-llvm-cov）
3. 生成统一的边界覆盖报告（Dart + Rust）

## 技术方案对比

### 方案 A: 使用 syn crate（推荐）

**优点**: 
- 精确解析 Rust AST
- 可识别复杂的边界模式
- 与 Dart 扫描器架构一致

**缺点**:
- 需要学习 syn API
- 需要编写较多代码

**实现步骤**:
1. 创建 `rust/tool/boundary_scanner/Cargo.toml`
2. 使用 syn 解析 Rust 文件
3. 识别边界条件（if/match/Result/Option/? 等）
4. 输出 JSON 格式的边界列表
5. Dart 扫描器读取 JSON 并合并报告

**依赖**:
```toml
[dependencies]
syn = { version = "2.0", features = ["full", "visit"] }
quote = "1.0"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### 方案 B: 使用 cargo-llvm-cov

**优点**:
- 直接获取覆盖率数据
- 无需自己解析 AST

**缺点**:
- 只能知道哪些行被执行，不知道是什么类型的边界
- 需要安装 llvm-tools

**实现步骤**:
1. 运行 `cargo llvm-cov --json`
2. 解析 JSON 输出
3. 结合简单的文本扫描识别边界类型

### 方案 C: 正则表达式（快速但不精确）

**优点**:
- 实现快速
- 无需额外依赖

**缺点**:
- 容易误判
- 无法处理复杂语法

## 推荐方案：A（syn crate）

## 实施步骤

### Phase 1: 基础框架（1 天）

**任务**:
1. 创建 `rust/tool/boundary_scanner/` 目录结构
2. 初始化 Cargo 项目
3. 实现文件遍历和解析

**产出**:
- `rust/tool/boundary_scanner/Cargo.toml`
- `rust/tool/boundary_scanner/src/main.rs`
- 能够遍历 `rust/src/` 并解析所有 `.rs` 文件

### Phase 2: 边界识别（1.5 天）

**任务**:
1. 实现 AST 访问者模式
2. 识别以下边界类型：
   - `if` / `else if` / `else` 表达式
   - `match` 表达式
   - `if let` / `while let`
   - `Result` 类型的 `?` 操作符
   - `Option` 类型的解包
   - `loop` / `while` / `for` 循环
   - 空值检查（`.is_none()`, `.is_ok()`, 等）

**产出**:
- 完整的边界识别逻辑
- 输出 JSON 格式的边界数据

### Phase 3: 覆盖率集成（1 天）

**任务**:
1. 集成 `cargo-llvm-cov` 生成覆盖率数据
2. 匹配边界行号与覆盖率数据
3. 计算真实覆盖率

**产出**:
- 能够输出带覆盖率信息的边界列表

### Phase 4: 报告合并（0.5 天）

**任务**:
1. 修改 Dart 扫描器调用 Rust 扫描器
2. 合并 Dart 和 Rust 的边界数据
3. 生成统一报告

**产出**:
- 统一的 Markdown 报告（包含 Dart + Rust）

### Phase 5: 集成与测试（0.5 天）

**任务**:
1. 集成到 `quality.dart`
2. 编写单元测试
3. 更新文档

## 文件结构

```
rust/tool/boundary_scanner/
├── Cargo.toml
├── src/
│   ├── main.rs              # 入口
│   ├── scanner.rs           # 扫描逻辑
│   ├── visitor.rs           # AST 访问者
│   ├── boundary.rs          # 边界数据结构
│   └── coverage.rs          # 覆盖率集成
└── tests/
    └── test_scanner.rs
```

## Rust 边界类型映射

| Rust 语法 | 边界类型 | 示例 |
|-----------|---------|------|
| `if expr { }` | condition | `if x > 0` |
| `if let Some(x) = opt { }` | null | 空值检查 |
| `match expr { }` | condition | `match result` |
| `expr?` | exception | `file.read()?` |
| `Result<T, E>` | exception | 错误处理 |
| `Option::unwrap()` | null | 可能 panic |
| `.is_none()` / `.is_some()` | null | 空值检查 |
| `loop { }` / `while` | lifecycle | 循环边界 |
| `async fn` / `.await` | async | 异步边界 |
| `Mutex::lock()` | concurrency | 并发边界 |

## 与现有系统集成

### 修改 `test_boundary_scanner.dart`

```dart
Future<ScanResult> scan() async {
  // 1. 扫描 Dart 边界（现有）
  final dartBoundaries = await _scanDartBoundaries();
  
  // 2. 扫描 Rust 边界（新增）
  final rustBoundaries = await _scanRustBoundaries();
  
  // 3. 合并边界
  final allBoundaries = [...dartBoundaries, ...rustBoundaries];
  
  // 4. 收集 Dart 覆盖率（现有）
  await _collectDartCoverage();
  
  // 5. 收集 Rust 覆盖率（新增）
  await _collectRustCoverage();
  
  // 6. 匹配覆盖率（现有逻辑）
  ...
}

Future<List<Boundary>> _scanRustBoundaries() async {
  // 调用 Rust 扫描器
  final result = await Process.run(
    'cargo',
    ['run', '--manifest-path', 'rust/tool/boundary_scanner/Cargo.toml'],
  );
  
  // 解析 JSON 输出
  final json = jsonDecode(result.stdout);
  return json.map((b) => Boundary.fromJson(b)).toList();
}
```

## 时间估算

- **Phase 1**: 1 天
- **Phase 2**: 1.5 天
- **Phase 3**: 1 天
- **Phase 4**: 0.5 天
- **Phase 5**: 0.5 天

**总计**: 4.5 天

## 优先级建议

**当前项目状态**: 如果没有大量 Rust 业务逻辑，可以延迟实施。

**建议**:
- **高优先级**: 如果 Rust 层包含核心业务逻辑
- **中优先级**: 如果 Rust 主要是 FFI 桥接
- **低优先级**: 如果业务逻辑主要在 Flutter 层

## 相关资源

- [syn crate 文档](https://docs.rs/syn/)
- [cargo-llvm-cov](https://github.com/taiki-e/cargo-llvm-cov)
- [Rust AST 遍历示例](https://github.com/dtolnay/syn/tree/master/examples)

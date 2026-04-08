# 2026-04-08 Rust 动态库运行态路径统一设计

## 1. 背景与目标

- 当前仓库已经具备 Rust 动态库构建能力，`cargo build --release` 会在 `rust/target/release/` 产出 `libcardmind_rust.dylib`。
- 但 Flutter 运行链路、FRB 真库测试链路、以及 macOS app bundle 拷贝链路对动态库位置的依赖并不统一：
  - 有的链路直接读取 `rust/target/release/libcardmind_rust.dylib`；
  - 有的链路在 app build 后再复制到 bundle；
  - 有的链路依赖 FRB 默认相对目录解析。
- 历史记录已经出现多次以下问题：
  - 新 worktree 或新环境下找不到动态库；
  - Flutter/Dart 绑定与 Rust 动态库版本不同步；
  - 运行时拿到的动态库与测试使用的动态库不是同一份产物。

本设计的目标是：

- 为“运行态动态库”建立唯一官方路径；
- 明确区分“Cargo 编译缓存”和“运行态产物”；
- 让测试、运行、以及 app bundle 同步都依赖同一份运行态动态库；
- 为后续进一步处理 worktree 共享缓存问题保留清晰边界。

## 2. 问题定义

### 2.1 当前事实

- `rust/target/release/` 是 Cargo 编译产物目录，本质职责是构建缓存与中间产物承载。
- 当前 FRB 默认加载配置仍指向 `rust/target/release/`。
- 多个 Flutter 合同测试与集成测试直接硬编码 `rust/target/release/libcardmind_rust.dylib`。
- `tool/build.dart run` 会在 macOS 下把 `rust/target/release/libcardmind_rust.dylib` 复制到 app bundle。

### 2.2 实际问题

- 运行态动态库来源不唯一，导致不同链路可能消费不同副本。
- 测试和运行直接依赖 Cargo 目录，导致执行目录、worktree、构建顺序都会影响成功率。
- 当 Rust 代码或 FRB 绑定发生变化时，问题经常表现为“动态库不存在”或“动态库有问题”，但根因其实是路径漂移或版本不同步。

### 2.3 根因归纳

- `rust/target/...` 被同时当成“构建缓存目录”和“运行态真相源”使用，职责混淆。
- 动态库路径解析缺少单一入口，导致测试、运行、打包各自拼路径。
- 当前策略没有约束“哪些代码可以直接读取 Cargo 目录”。

## 3. 备选方案比较

### 3.1 方案 A（选定）：引入受控运行态动态库目录

- 保留 `rust/target/...` 作为 Cargo 编译缓存源。
- 新增仓库内统一运行态目录，例如 `build/native/<platform>/`。
- `tool/build.dart lib` 在完成 Cargo 构建后，把动态库同步到统一运行态目录。
- FRB 真库测试、Flutter 显式加载逻辑、以及 macOS app bundle 拷贝都统一从运行态目录读取。

优点：

- 运行态只有一个真相源，最直接解决路径漂移问题；
- 测试与运行加载的是同一份动态库；
- 后续若要切换共享缓存策略，只需调整构建源，不必重写运行侧代码。

缺点：

- 需要收口现有路径硬编码；
- 需要在构建脚本里增加产物同步逻辑。

### 3.2 方案 B：保留 Cargo 路径，只统一 Dart 侧加载入口

- 不新增运行态目录；
- 所有加载逻辑统一走一个 Dart 方法，但该方法最终仍返回 `rust/target/release/...`。

优点：

- 改动更小；
- 能减少散落硬编码。

缺点：

- 根因未消除，运行态仍依赖 Cargo 目录；
- worktree、执行目录与构建缓存生命周期问题仍然存在；
- app bundle 与测试链路仍可能各自复制和持有不同副本。

### 3.3 方案 C：全局共享 Cargo target 并统一运行态目录

- 配置统一 `CARGO_TARGET_DIR`，使多个 worktree 共享编译缓存；
- 同时引入统一运行态目录。

优点：

- 构建复用最好，worktree 切换成本最低；
- 从体验上更接近“动态库可长期缓存”。

缺点：

- 需要引入更强的环境和团队约束；
- 超出本轮“先稳定运行态来源”的最小范围。

## 4. 选定方案与边界

本轮选择方案 A。

明确边界如下：

- 本轮实现范围仅保证 macOS 运行态动态库路径统一。
- 非 macOS 平台在本轮不落地运行态目录规则，也不做占位实现；若统一入口在非 macOS 平台被调用，必须显式报“当前仅支持 macOS”的未支持错误。
- 本轮只统一“运行态动态库来源”，不处理全局共享 `CARGO_TARGET_DIR`。
- 本轮不增加自动后台重建机制；若运行态目录缺库，只给出明确错误和标准构建指令。
- 本轮不修改 FRB 代码生成策略，只修改动态库产物同步与加载路径策略。

## 5. 最终设计

### 5.1 目录职责划分

- `rust/target/release/libcardmind_rust.dylib`
  - 职责：Cargo 编译缓存源。
  - 约束：仅构建脚本可直接读取。
- `build/native/macos/libcardmind_rust.dylib`
  - 职责：macOS 运行态动态库官方路径。
  - 约束：测试、运行、打包均读取该路径。

后续如扩展 Linux/Windows，可沿用同一规则：

- `build/native/linux/...`
- `build/native/windows/...`

### 5.2 构建脚本职责

`tool/build.dart` 需要收口为两层职责：

- `cargo build --release`：负责生成编译产物；
- 产物同步：负责把平台对应动态库从 Cargo 目录复制到 `build/native/<platform>/`。

`lib` 子命令完成后的语义调整为：

- Rust 库构建成功；
- 运行态动态库已经同步到官方路径；
- 成功日志应明确打印运行态动态库位置。

同步失败语义需要显式固定：

- 若 `cargo build --release` 失败，则本次 `lib` 命令直接失败，禁止继续同步旧产物。
- 若 Cargo 构建成功，但源动态库不存在、复制失败、或目标目录写入失败，则本次 `lib` 命令也必须失败。
- 一旦进入“准备写入运行态动态库”阶段，脚本必须先删除旧的官方运行态 dylib，再写入新的 dylib；禁止在同步失败后保留旧副本继续作为运行输入。
- 也就是说，官方运行态目录只允许处于两种状态：
  - 存在且为本次成功同步后的新 dylib；
  - 不存在 dylib，后续测试/运行必须显式失败。

这样可避免“Cargo 已变但运行态仍偷偷沿用旧副本”导致的版本漂移。

### 5.3 Dart 侧统一加载入口

需要新增单一的 Dart 路径解析入口，用于：

- 返回当前平台运行态动态库的绝对路径；
- 在文件不存在时抛出明确错误；
- 错误信息必须直接提示执行 `dart run tool/build.dart lib`。

该入口的边界也需要固定：

- 位置：放在仓库内可被 Flutter 真库测试与运行初始化共同复用的基础设施层，而不是散落在单个测试文件中。
- 职责：只负责定位并校验官方运行态动态库路径，不负责触发构建、不负责兜底回退到 Cargo 目录。
- 输入：可为空；平台分发判断由该入口内部基于当前平台解析。
- 输出：官方运行态动态库的绝对路径字符串，供 `ExternalLibrary.open(...)` 使用。
- 错误约束：抛出的错误消息至少包含以下信息：
  - 当前尝试读取的官方路径；
  - 动态库不存在或不可用这一事实；
  - 标准恢复命令 `dart run tool/build.dart lib`。

平台约束：

- 本轮只解析 macOS 官方运行态路径 `build/native/macos/libcardmind_rust.dylib`。
- 若当前平台不是 macOS，该入口必须抛出明确未支持错误，并说明“当前仅支持 macOS 运行态动态库路径解析”。

FRB 集成约束：

- 所有真实初始化必须显式调用 `ExternalLibrary.open(<official-runtime-path>)`，再传入 `RustLib.init(...)`。
- 禁止把 FRB 默认相对路径解析作为隐式后备路径。
- FRB 生成代码中的默认 loader 配置在本轮可以保留，但真实运行链路不得依赖该默认配置来寻找 dylib。

约束：

- FRB 真库初始化逻辑只能通过该入口获取动态库路径；
- 禁止在测试或业务代码中继续手写 `rust/target/release/...`。

### 5.4 测试链路收口

以下测试类别统一改为通过 Dart 单点入口加载动态库：

- FRB 合同测试；
- Flutter/Rust 真库集成测试；
- 其他依赖真实 dylib 的测试。

其中“依赖真实 dylib”的识别标准明确为：

- 任何直接调用 `ExternalLibrary.open(...)` 的测试代码；
- 任何直接拼接、返回、缓存 `libcardmind_rust.dylib` 路径的测试代码；
- 任何为真实 FRB 初始化提供 dylib 路径的测试 helper、fixture、或启动器代码。

不在本轮收口范围内的测试：

- `RustLib.initMock(...)` 纯 mock 测试；
- 不触发真实动态库加载的普通 Flutter 单测。

收口后测试的真实含义变为：

- 校验“运行态官方动态库”能被 Flutter 正常加载；
- 不再校验 Cargo 缓存目录本身是否可直接作为运行输入。

### 5.5 macOS run 链路收口

`tool/build.dart run` 在 macOS 下的动态库复制逻辑应调整为：

- 从 `build/native/macos/libcardmind_rust.dylib` 复制到 app bundle `Contents/Frameworks/`；
- 不再直接从 `rust/target/release/` 复制。

这样可确保：

- app bundle 使用的动态库与测试链路使用的是同一份运行态产物；
- 若 `lib` 子命令收口正确，`run` 子命令无需再关心 Cargo 产物路径。

## 6. 禁止事项

- 禁止业务代码直接依赖 `rust/target/release/` 作为运行态动态库位置。
- 禁止 FRB 真库测试继续硬编码 `rust/target/release/libcardmind_rust.dylib`。
- 禁止 `run` 链路绕过运行态目录，直接从 Cargo 目录复制 dylib。
- 禁止在多个测试文件内重复定义动态库路径解析逻辑。

## 7. 数据流与错误处理

### 7.1 构建链路

- `dart run tool/build.dart lib`
- `tool/build.dart` 在 `rust/` 目录执行 `cargo build --release`
- 从 Cargo 产物目录定位平台对应动态库
- 将动态库复制到 `build/native/<platform>/`
- 输出运行态动态库绝对路径

### 7.2 测试链路

- 测试调用 Dart 单点入口获取运行态动态库路径
- `ExternalLibrary.open(<official-runtime-path>)`
- `RustLib.init(...)`

当运行态动态库不存在时：

- 报错信息必须清晰说明官方路径不存在；
- 明确提示先执行 `dart run tool/build.dart lib`；
- 不做静默回退到 Cargo 目录的补丁行为。

### 7.3 运行链路

- `dart run tool/build.dart run`
- 内部先执行 `lib`
- Flutter app build 完成后，从 `build/native/macos/` 复制 dylib 到 app bundle
- 打开 app

## 8. 验证策略

### 8.1 构建验证

- `dart run tool/build.dart lib` 成功后，`build/native/macos/libcardmind_rust.dylib` 必须存在。
- 日志需显示 Cargo 构建成功和运行态动态库同步成功。

### 8.2 测试验证

- 所有 FRB 真库测试必须从统一入口加载动态库。
- 至少一条 Flutter/Rust 真链路测试可证明官方运行态动态库可正常完成初始化与调用。
- 需要增加静态验收：除 `tool/build.dart` 外，仓库运行态代码、测试代码、测试 helper 中不再存在对 `rust/target/release/libcardmind_rust.dylib` 的运行态引用。
- 需要增加结构验收：所有真实 dylib 加载点都必须通过统一 helper 或统一入口函数收口，而不是各测试文件分别拼接路径。

### 8.3 运行验证

- `dart run tool/build.dart run` 能完成：构建 Rust 库 -> 同步运行态 dylib -> 构建 Flutter app -> 拷贝到 app bundle -> 启动 app。
- app bundle 中的 dylib 来源路径必须是 `build/native/macos/`，而非 Cargo 目录。

### 8.4 文档验证

- `README.md` 需明确区分：
  - Cargo 编译缓存目录；
  - 官方运行态动态库目录；
  - 当动态库缺失时的标准恢复命令。
- `AGENTS.md` 中的构建脚本说明需同步更新运行态动态库目录职责，避免后续流程继续把 `rust/target/...` 误当成运行态真相源。
- 如 `tool/DIR.md` 已承载构建脚本语义，也需同步更新动态库路径职责说明。

文档更新后的目标是让开发者能明确区分：
  - Cargo 编译缓存目录；
  - 官方运行态动态库目录；
  - 当动态库缺失时的标准恢复命令。

## 9. 非目标

- 不在本轮引入全局共享 `CARGO_TARGET_DIR`。
- 不在本轮实现“检测到缺库自动重建”。
- 不在本轮处理 iOS/Android 动态库分发策略。
- 不在本轮改造 FRB 代码生成产物内容。

## 10. 完成判定

- 仓库内存在唯一官方运行态动态库路径，且由构建脚本负责同步。
- 所有真实动态库加载链路都只依赖该官方路径。
- `rust/target/...` 仅保留为 Cargo 编译缓存源，不再被测试和运行直接消费。
- `run` 链路与测试链路使用同一份运行态动态库。
- 动态库缺失时，错误信息可直接指导用户使用标准命令恢复。
- 本轮范围内的真实加载链路全部显式绕过 FRB 默认相对路径解析。
- 除 `tool/build.dart` 外，仓库中不再保留对 `rust/target/release/libcardmind_rust.dylib` 的运行态硬编码引用。

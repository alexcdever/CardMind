# macOS Desktop Support

<!-- Task ID: macos-desktop-support -->
<!-- Contract section is frozen after commit. Lifecycle sections are maintained by the main agent. -->

```pipeline-contract
{
  "schema": 1,
  "task_id": "macos-desktop-support",
  "allowed_paths": [
    "macos/**",
    "lib/models/update_manifest.dart",
    "lib/services/platform_update_installer.dart",
    "lib/pages/settings_page.dart",
    "test/models/update_manifest_test.dart",
    "test/services/platform_update_installer_test.dart",
    "test/macos_desktop_support_test.dart",
    ".github/workflows/manual-build-artifacts.yml",
    "test/release_workflow_test.dart",
    "pubspec.yaml",
    "pubspec.lock",
    "AGENTS.md",
    "docs/standards/tech-stack-baseline.md",
    "docs/standards/git-and-pr.md",
    ".workflow/macos-desktop-support/**",
    "docs/tasks/macos-desktop-support.md"
  ],
  "forbidden_paths": [
    ".env",
    "android/**",
    "windows/**",
    "linux/**",
    "rust-backend/src/**",
    "lib/src/rust/**"
  ],
  "acceptance_tests": [
    {
      "id": "AT1",
      "evidence_level": 1,
      "test_ref": "test/models/update_manifest_test.dart: identifies macOS arm64 as the current update platform",
      "command_ref": "flutter test test/models/update_manifest_test.dart --timeout 3m"
    },
    {
      "id": "AT2",
      "evidence_level": 1,
      "test_ref": "test/services/platform_update_installer_test.dart: macOS reports manual installation without launching a platform installer",
      "command_ref": "flutter test test/services/platform_update_installer_test.dart --timeout 3m"
    },
    {
      "id": "AT3",
      "evidence_level": 1,
      "test_ref": "test/macos_desktop_support_test.dart: macOS project metadata and Rust bundle integration are committed",
      "command_ref": "flutter test test/macos_desktop_support_test.dart --timeout 3m"
    },
    {
      "id": "AT4",
      "evidence_level": 1,
      "test_ref": "test/release_workflow_test.dart: release workflow includes macOS artifact and release dependency",
      "command_ref": "flutter test test/release_workflow_test.dart --timeout 3m"
    },
    {
      "id": "AT5",
      "evidence_level": 4,
      "test_ref": "built macOS app bundle: Flutter release build contains a non-empty Rust dylib in Contents/Frameworks",
      "command_ref": "cargo build --release && flutter build macos --release && test -s build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_rust.dylib && otool -L build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_rust.dylib"
    },
    {
      "id": "AT6",
      "evidence_level": 1,
      "test_ref": "Flutter analyzer and dependency resolution: project supports Dart 3.12.2+",
      "command_ref": "flutter pub get && flutter analyze"
    }
  ]
}
```

## 任务身份

- 项目：CardMind
- 领域或阶段：Flutter macOS 桌面平台支持
- 用户结果或系统能力：在干净 macOS 环境构建并运行包含 Rust/FRB 后端的 CardMind macOS 应用，并纳入发布产物流程
- 状态：未开始

## 依赖与范围

### 前置条件

- 当前基线为 `9b9fbac5`，工作区初始干净。
- `pubspec.yaml` 要求 Dart SDK `^3.12.2`，发布 workflow 已使用 Flutter `3.44.9`。
- Flutter 官方命令 `flutter create --platforms=macos .` 用于给现有项目生成 macOS 工程。
- Rust crate `rust-backend` 产出 `libcardmind_backend.dylib`；FRB 运行态约定是 `build/native/macos/libcardmind_rust.dylib`。

### 允许修改

- 标准 Flutter macOS host 工程及其 Runner 配置。
- macOS 更新平台枚举、更新清单平台键和设置页平台映射。
- macOS Rust 动态库复制/签名所需的构建辅助配置和 macOS release workflow。
- macOS 专项测试、现有 workflow 测试和必要的项目平台文档。
- 当前任务证据目录 `.workflow/macos-desktop-support/`。

### 明确不改

- 不修改 Android、Windows、Linux 工程或 Rust 业务源码。
- 不修改 FRB 生成文件或 Rust API/数据协议。
- 不实现 Apple Developer 签名、公证、App Store 发布或 DMG 生成。
- 不为 macOS 增加摄像头扫码；macOS 使用现有手动配对入口。
- 不把 macOS 更新错误地映射为 Windows 进程或 Android method channel 安装。

## 事实、假设与待决

### 已确认事实

- `flutter build macos --no-pub` 当前报告 `No macOS desktop project configured`。
- 当前机器 Xcode 提供 macOS SDK 27.0；本机 Flutter 3.44.0 搭载 Dart 3.12.0，低于项目约束。
- `lib/services/platform_update_installer.dart` 当前枚举只有 `windows`、`android`、`linux`。
- `lib/models/update_manifest.dart` 当前非 Windows/Android 平台统一返回 `linux-x64`。
- 现有 macOS 构建辅助逻辑把 Rust dylib复制到 app bundle 的 `Contents/Frameworks`，但该逻辑依赖缺失的 macOS host 工程。

### 未验证事实

- 当前本机是否已安装 Flutter 3.44.9 或可无网络切换到该版本。
- 当前 macOS CocoaPods 状态能否完成新生成工程的依赖安装。
- `cargo build --release` 产物的 install name 是否能被最终 app bundle 的 `@rpath` 加载。
- GitHub Actions `macos-latest` 上完整 release job 的实际执行结果。

### 禁止猜测

- 不以单元测试代替真实 macOS bundle 构建验收。
- 不因环境缺失而降低 Dart SDK 约束或删除 macOS 构建验收。
- 如果 macOS workflow 需要改变发布资产命名、签名或 manifest schema，必须停下建立 continuation 任务请求决策。

## 设计与行为契约

[Flutter/macOS 构建或用户启动]
→ [Runner 启动 Flutter；FRB 从 app bundle Contents/Frameworks 加载 Rust dylib]
→ [现有 NoteRepository、SQLite、mDNS、同步和日志服务使用 macOS 支持目录]
→ [用户可进入笔记列表、编辑器、设备配对和设置页面]

[用户在 macOS 设置页检查并下载更新]
→ [当前平台识别为 macos-arm64；清单选择 macOS asset]
→ [下载并校验文件；安装器返回 ManualInstallRequired]
→ [界面提示用户手动打开/替换下载的 macOS 产物，不启动 Android/Windows 安装器]

- Rust 动态库必须在 release app bundle 的 `Contents/Frameworks/` 下非空。
- macOS 只显示 show-code 和 manual-entry 配对模式，不显示 Android 扫码模式。
- 已有平台的更新平台键和安装行为保持不变。
- macOS workflow 必须等待 macOS 构建、动态库校验、ZIP 打包完成后才进入 release job。
- 构建失败、动态库缺失、签名/打包失败必须以非零退出，不得上传伪产物。

## 环境前置

1. 使用 Flutter `3.44.9` 或其他提供 Dart `>=3.12.2` 的兼容 Flutter SDK。
2. macOS 主机安装 Xcode、macOS SDK、CocoaPods、Rust stable 和 `cargo`。
3. 从仓库根目录运行 `flutter pub get`，再运行 FRB codegen（如依赖需要）。
4. 真机构建命令的单条超时为 10 分钟；单元测试命令的单条超时为 3 分钟。

## 验收测试

### 验收测试1：更新清单识别 macOS 平台

- 触发：在 macOS 测试进程解析包含 macOS asset 的合法更新清单。
- 断言：当前平台键为 `macos-arm64`，清单被接受，`currentAsset` 指向 macOS 产物；Windows、Android、Linux 既有键仍被接受。
- 测试：`test/models/update_manifest_test.dart: identifies macOS arm64 as the current update platform`
- 命令：`flutter test test/models/update_manifest_test.dart --timeout 3m`
- 验收模式：单元
- 证据等级：1
- 结果要求：退出码 0；该用例实际断言 macOS key 和 asset，不得只断言对象非空。

### 验收测试2：macOS 更新使用手动安装路径

- 触发：将已校验 macOS 更新文件交给 `PlatformUpdateInstaller`。
- 断言：返回 `ManualInstallRequired`，消息明确需要手动安装，且 Windows launcher、Android URI provider 和 Android method channel 均未被调用。
- 测试：`test/services/platform_update_installer_test.dart: macOS reports manual installation without launching a platform installer`
- 命令：`flutter test test/services/platform_update_installer_test.dart --timeout 3m`
- 验收模式：单元
- 证据等级：1
- 结果要求：退出码 0；失败路径不能启动外部进程或 Android channel。

### 验收测试3：macOS 工程和 Rust bundle 配置

- 触发：读取仓库中生成并配置后的 macOS 工程文件。
- 断言：工程存在 Runner target，Bundle ID 为 `com.cardmind.v2`，Podfile/Runner 配置包含 Flutter macOS 集成，构建辅助配置把非空 Rust dylib复制到 app bundle 的 `Contents/Frameworks`。
- 测试：`test/macos_desktop_support_test.dart: macOS project metadata and Rust bundle integration are committed`
- 命令：`flutter test test/macos_desktop_support_test.dart --timeout 3m`
- 验收模式：单元/静态工程检查
- 证据等级：1
- 结果要求：退出码 0；断言必须读取实际工程/脚本内容，不得只检查目录存在。

### 验收测试4：macOS release workflow

- 触发：读取 GitHub Actions release workflow。
- 断言：存在 macOS job，固定兼容 Flutter 版本，构建 macOS、复制并检查 Rust dylib、生成 `CardMind-macOS-arm64.zip`，release job 等待并校验该资产，manifest 生成包含它。
- 测试：`test/release_workflow_test.dart: release workflow includes macOS artifact and release dependency`
- 命令：`flutter test test/release_workflow_test.dart --timeout 3m`
- 验收模式：单元/CI 配置检查
- 证据等级：1
- 结果要求：退出码 0；同时保留 Android、Windows、Linux workflow 断言。

### 验收测试5：真实 macOS release bundle

- 触发：在 macOS 主机从 Rust 源码和 Flutter 工程构建 release app。
- 断言：`flutter build macos --release` 退出码 0；`cardmind.app/Contents/Frameworks/libcardmind_rust.dylib` 存在且非空；`otool -L` 能读取它；应用 bundle 可被 macOS 打开或至少通过 `codesign --verify --deep --strict` 检查。
- 测试：`build/macos/Build/Products/Release/cardmind.app` 及其中的动态库
- 命令：`cargo build --release && flutter build macos --release && test -s build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_rust.dylib && otool -L build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_rust.dylib`
- 验收模式：真实桌面构建
- 证据等级：4
- 结果要求：每条命令退出码 0，产物路径与当前 worktree 一致；缺少 Flutter/Dart/Xcode/CocoaPods/Rust 环境时标记 BLOCKED，不得改写为 PASS。

### 验收测试6：依赖和静态分析

- 触发：在满足 Dart SDK 约束的 Flutter 环境中解析依赖并分析项目。
- 断言：`flutter pub get` 与 `flutter analyze` 均成功，无新增 macOS 兼容性错误。
- 测试：项目整体
- 命令：`flutter pub get && flutter analyze`
- 验收模式：静态分析/依赖解析
- 证据等级：1
- 结果要求：每条命令退出码 0；Dart SDK 不满足时标记 BLOCKED，并保留原始版本输出。

## 决策点

出现以下情况时，保留 worktree 并报告给主代理，不得静默改变契约：

1. Flutter 模板或 Xcode 新版本要求签名、公证或改变现有 bundle identity 才能构建。
2. Rust dylib 无法以现有 FRB loader 在 app bundle 中加载，需要修改生成文件或 Rust API。
3. GitHub release manifest 只能支持现有三平台，加入 macOS 需要改变 schema 或用户可见发布策略。
4. 本机工具链不足以运行 AT5；应记录 BLOCKED 并等待用户提供/批准环境调整。

---

## 任务级进度（主代理维护）

> 以下内容不是新的设计权威。契约区在提交后冻结；此处记录进度、裁决和最终结果。

### 任务锚点

- 基线 HEAD：9b9fbac5
- 契约提交：-
- 执行分支：-
- 执行 worktree：-

### 验收台账

| 验收测试 | 状态 | 当前测试/命令 | 最新证据 | 备注 |
|---|---|---|---|---|
| 验收测试1 | 未开始 | `flutter test test/models/update_manifest_test.dart --timeout 3m` | - | - |
| 验收测试2 | 未开始 | `flutter test test/services/platform_update_installer_test.dart --timeout 3m` | - | - |
| 验收测试3 | 未开始 | `flutter test test/macos_desktop_support_test.dart --timeout 3m` | - | - |
| 验收测试4 | 未开始 | `flutter test test/release_workflow_test.dart --timeout 3m` | - | - |
| 验收测试5 | 未开始 | `cargo build --release && flutter build macos --release ...` | - | - |
| 验收测试6 | 未开始 | `flutter pub get && flutter analyze` | - | - |

### 执行记录

| 时间/轮次 | 事件 | 结果 | 证据 | 后续 |
|---|---|---|---|---|
| 2026-09-20 / 0 | 任务单创建 | 未开始 | - | 校验并提交冻结契约 |

### 设计变更与延续任务索引

- 无。如需设计裁决，建立延续任务并链接 `docs/tasks/macos-desktop-support-continuation-N.md`；机器路径保留 `continuation`，不得覆盖本任务历史。

### 最终结果

- 状态：未开始
- 执行子代理：未开始
- 独立审查子代理：未开始
- 主代理最终检查：未开始
- 合并提交：-
- 合并后复验：未开始
- 遗留项：-

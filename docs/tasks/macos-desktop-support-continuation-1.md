# macOS Desktop Support Continuation 1

<!-- Task ID: macos-desktop-support-continuation-1 -->
<!-- Parent task: macos-desktop-support. Contract is frozen after commit. -->

```pipeline-contract
{
  "schema": 1,
  "task_id": "macos-desktop-support-continuation-1",
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
    "tool/build.dart",
    "tool/release/generate_update_manifest.py",
    "tool/release/test_generate_update_manifest.py",
    "tool/src/git_gate/host_build.dart",
    "test/git_gate_test.dart",
    ".metadata",
    "pubspec.yaml",
    "pubspec.lock",
    "AGENTS.md",
    "docs/standards/tech-stack-baseline.md",
    "docs/standards/git-and-pr.md",
    ".workflow/macos-desktop-support-continuation-1/**",
    "docs/tasks/macos-desktop-support-continuation-1.md"
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
      "id": "C1",
      "evidence_level": 1,
      "test_ref": "test/models/update_manifest_test.dart: identifies macOS arm64 as the current update platform",
      "command_ref": "flutter test test/models/update_manifest_test.dart --timeout 3m"
    },
    {
      "id": "C2",
      "evidence_level": 1,
      "test_ref": "test/services/platform_update_installer_test.dart: macOS reports manual installation without launching a platform installer",
      "command_ref": "flutter test test/services/platform_update_installer_test.dart --timeout 3m"
    },
    {
      "id": "C3",
      "evidence_level": 1,
      "test_ref": "test/macos_desktop_support_test.dart: macOS project metadata and Rust bundle integration are committed",
      "command_ref": "flutter test test/macos_desktop_support_test.dart --timeout 3m"
    },
    {
      "id": "C4",
      "evidence_level": 1,
      "test_ref": "test/release_workflow_test.dart: release workflow includes macOS artifact and release dependency",
      "command_ref": "flutter test test/release_workflow_test.dart --timeout 3m"
    },
    {
      "id": "C5",
      "evidence_level": 1,
      "test_ref": "tool/release/test_generate_update_manifest.py: macOS asset is emitted in generated manifests",
      "command_ref": "python3 -m unittest tool.release.test_generate_update_manifest -v"
    },
    {
      "id": "C6",
      "evidence_level": 1,
      "test_ref": "test/git_gate_test.dart: macOS runtime library specification uses the actual FRB loader name and bundle destination",
      "command_ref": "flutter test test/git_gate_test.dart --timeout 3m"
    },
    {
      "id": "C7",
      "evidence_level": 4,
      "test_ref": "built macOS app bundle: Flutter release build contains a loadable Rust dylib in Contents/Frameworks",
      "command_ref": "cargo build --release && flutter build macos --release && test -s build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_backend.dylib && otool -L build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_backend.dylib"
    },
    {
      "id": "C8",
      "evidence_level": 1,
      "test_ref": "Flutter analyzer and dependency resolution: project supports Dart 3.12.2+",
      "command_ref": "flutter pub get && flutter analyze"
    }
  ]
}
```

## 任务身份

- 项目：CardMind
- 父任务：`macos-desktop-support`，契约提交 `3b6bdceb`
- 领域或阶段：macOS 支持范围修正与实现
- 用户结果或系统能力：补齐 macOS 支持所需的更新清单生成器、FRB 动态库实际加载路径和原生工程集成，并完成真实 release bundle 验收
- 状态：未开始

## 依赖与范围

### 前置条件

- 父任务已冻结并提交，基线为 `3b6bdceb`。
- 父任务明确 macOS 完整桌面支持、无 Apple 签名/公证、保留 Android/Windows/Linux 行为。
- 当前 FRB 生成配置的 loader stem 为 `cardmind_backend`，不能把历史 `libcardmind_rust.dylib` 命名假设当成已验证事实。

### 允许修改

- 父任务允许路径。
- `tool/build.dart`、`tool/release/generate_update_manifest.py`、对应生成器测试、host runtime 测试和 `.metadata`，用于修正父任务遗漏的真实构建/发布边界。
- 当前 continuation 的证据目录 `.workflow/macos-desktop-support-continuation-1/`。

### 明确不改

- 不修改 Android、Windows、Linux 工程或 Rust 业务源码。
- 不修改 FRB 生成文件或 Rust API/数据协议。
- 不实现 Apple Developer 签名、公证、App Store 发布或 DMG 生成。
- 不为 macOS 增加摄像头扫码。

## 事实、假设与待决

### 已确认事实

- 父任务允许路径没有包含更新清单生成器和现有构建辅助代码，但 macOS manifest 必须由生成器产出。
- `lib/src/rust/frb_generated.dart` 的 `ExternalLibraryLoaderConfig.stem` 是 `cardmind_backend`。
- FRB 2.12.0 macOS loader 会寻找 `libcardmind_backend.dylib` 或匹配的 framework 名称。
- `tool/build.dart` 当前运行态命名为 `libcardmind_rust.dylib`，与 FRB loader stem 不一致。
- `tool/src/git_gate/host_build.dart` 当前 macOS runtime 目标也使用 `libcardmind_backend.dylib`，存在现有约定不一致。
- `tool/release/generate_update_manifest.py` 当前只生成 Windows、Android、Linux 三个平台。

### 未验证事实

- Xcode build phase 复制动态库的最佳插入点，以及 macOS app bundle 对 dylib install name 的最终要求。
- 目标 macOS runner 是否需要 framework 目录形式，还是直接 dylib + `@rpath` 即可。
- 当前本机能否安装/切换到满足 Dart `>=3.12.2` 的 Flutter 3.44.9。

### 禁止猜测

- 不删除或修改生成的 `lib/src/rust/**` 来绕过命名问题。
- 不把 manifest 生成器改成接受缺失的 macOS 资产；缺失资产必须使发布 job 失败。
- 不用“构建命令退出 0”替代 bundle 内动态库存在且可加载的检查。

## 设计与行为契约

[构建或发布 macOS]
→ [Rust release dylib 按 FRB loader 实际名称进入 app bundle；manifest 生成器要求 macOS asset]
→ [macOS app 可由 Flutter runner 加载 FRB 后端；发布 job 只上传完整资产]
→ [笔记、同步、设备配对和设置功能沿用现有跨平台业务；更新在 macOS 上提示手动安装]

- FRB loader 的 stem、dylib 文件名、bundle 目录和 workflow 校验必须相互一致。
- macOS asset key 固定为 `macos-arm64`，artifact 固定为 `CardMind-macOS-arm64.zip`，除非用户另行裁决。
- 旧平台 manifest asset、安装行为和 release artifact 不回归。
- 构建/发布所需文件缺失时返回非零，不上传伪产物。

## 环境前置

1. Flutter 提供 Dart `>=3.12.2`，Rust stable、Xcode/macOS SDK 和 CocoaPods 可用。
2. 仓库根目录先执行 `flutter pub get`，必要时执行 FRB codegen。
3. 单元测试命令单条超时 3 分钟，真实 macOS build 单条超时 10 分钟。

## 验收测试

### 验收测试1：macOS 更新清单识别

- 触发：解析包含 `macos-arm64` asset 的合法更新清单。
- 断言：清单被接受，当前 asset 是 macOS 产物，旧平台 asset 仍保留。
- 测试：`test/models/update_manifest_test.dart: identifies macOS arm64 as the current update platform`
- 命令：`flutter test test/models/update_manifest_test.dart --timeout 3m`
- 验收模式：单元
- 证据等级：1
- 结果要求：退出码 0，断言平台键和 asset 名称。

### 验收测试2：macOS 手动更新安装

- 触发：将 macOS 已校验更新文件传给 `PlatformUpdateInstaller`。
- 断言：返回 `ManualInstallRequired`，不调用 Windows launcher、Android URI provider 或 method channel。
- 测试：`test/services/platform_update_installer_test.dart: macOS reports manual installation without launching a platform installer`
- 命令：`flutter test test/services/platform_update_installer_test.dart --timeout 3m`
- 验收模式：单元
- 证据等级：1
- 结果要求：退出码 0，失败路径不启动外部安装器。

### 验收测试3：macOS 工程和 Rust bundle 集成

- 触发：读取提交的 macOS Xcode/Flutter 工程与构建配置。
- 断言：Runner bundle ID 为 `com.cardmind.v2`；项目包含 Flutter macOS 集成；构建流程把 `libcardmind_backend.dylib` 放入 app bundle `Contents/Frameworks` 并保留可加载名称。
- 测试：`test/macos_desktop_support_test.dart: macOS project metadata and Rust bundle integration are committed`
- 命令：`flutter test test/macos_desktop_support_test.dart --timeout 3m`
- 验收模式：静态工程检查
- 证据等级：1
- 结果要求：退出码 0，读取实际工程和脚本内容。

### 验收测试4：macOS release workflow

- 触发：读取 GitHub Actions release workflow。
- 断言：macOS job 构建、校验、压缩 `CardMind-macOS-arm64.zip`；release job 等待 macOS 并将资产交给 manifest 生成器和 release 上传。
- 测试：`test/release_workflow_test.dart: release workflow includes macOS artifact and release dependency`
- 命令：`flutter test test/release_workflow_test.dart --timeout 3m`
- 验收模式：CI 配置检查
- 证据等级：1
- 结果要求：退出码 0，旧三平台断言继续通过。

### 验收测试5：manifest 生成器包含 macOS

- 触发：使用四个非空 staged release asset 生成清单。
- 断言：输出包含 `macos-arm64`、正确 artifact、HTTPS 下载地址、大小和 SHA-256；缺失 macOS asset 时失败。
- 测试：`tool/release/test_generate_update_manifest.py: macOS asset is emitted in generated manifests`
- 命令：`python3 -m unittest tool.release.test_generate_update_manifest -v`
- 验收模式：发布工具单元
- 证据等级：1
- 结果要求：退出码 0，测试同时覆盖成功和缺失资产失败路径。

### 验收测试6：host runtime 名称一致

- 触发：检查 host runtime 规格和构建 CLI 的 macOS 路径。
- 断言：cargo 产物、runtime staging 文件、bundle 文件和 FRB loader stem 形成一致可追踪链路。
- 测试：`test/git_gate_test.dart: macOS runtime library specification uses the actual FRB loader name and bundle destination`
- 命令：`flutter test test/git_gate_test.dart --timeout 3m`
- 验收模式：构建工具单元
- 证据等级：1
- 结果要求：退出码 0，不接受只验证旧历史名称的断言。

### 验收测试7：真实 macOS release bundle

- 触发：在 macOS 主机执行 Rust 和 Flutter release 构建。
- 断言：release app bundle 内存在非空 `libcardmind_backend.dylib`，`otool -L` 可读取，且 bundle 可通过 `codesign --verify --deep --strict`。
- 测试：`build/macos/Build/Products/Release/cardmind.app`
- 命令：`cargo build --release && flutter build macos --release && test -s build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_backend.dylib && otool -L build/macos/Build/Products/Release/cardmind.app/Contents/Frameworks/libcardmind_backend.dylib`
- 验收模式：真实桌面构建
- 证据等级：4
- 结果要求：每个命令退出码 0；工具链缺失标记 BLOCKED，不降级为 PASS。

### 验收测试8：依赖解析与分析

- 触发：在满足 SDK 约束的 Flutter 环境中执行依赖解析和静态分析。
- 断言：`flutter pub get`、`flutter analyze` 成功。
- 测试：项目整体
- 命令：`flutter pub get && flutter analyze`
- 验收模式：静态分析
- 证据等级：1
- 结果要求：Dart 版本不满足时保留原始版本证据并标记 BLOCKED。

## 决策点

出现以下情况时，保留 worktree 并报告，不得静默扩大契约：

1. macOS loader 需要修改 FRB 生成文件或 Rust API 才能加载。
2. macOS release 资产命名或 manifest schema 需要改变用户可见发布策略。
3. 需要 Apple Developer 证书、公证或 DMG 才能完成当前验收。
4. 本机环境不足以执行真实 bundle 验收。

---

## 任务级进度（主代理维护）

### 任务锚点

- 父任务基线：3b6bdceb
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
| 验收测试5 | 未开始 | `python3 -m unittest tool.release.test_generate_update_manifest -v` | - | - |
| 验收测试6 | 未开始 | `flutter test test/git_gate_test.dart --timeout 3m` | - | - |
| 验收测试7 | 未开始 | `cargo build --release && flutter build macos --release ...` | - | - |
| 验收测试8 | 未开始 | `flutter pub get && flutter analyze` | - | - |

### 执行记录

| 时间/轮次 | 事件 | 结果 | 证据 | 后续 |
|---|---|---|---|---|
| 2026-09-20 / 0 | continuation 创建 | 未开始 | - | 校验并提交冻结契约 |

### 设计变更与延续任务索引

- 父任务：`docs/tasks/macos-desktop-support.md`
- 本任务记录父任务允许路径遗漏和 FRB loader/旧 dylib 命名冲突。

### 最终结果

- 状态：未开始
- 执行子代理：未开始
- 独立审查子代理：未开始
- 主代理最终检查：未开始
- 合并提交：-
- 合并后复验：未开始
- 遗留项：-

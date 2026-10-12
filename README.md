# CardMind

面向多设备个人用户的笔记同步应用。Flutter 前端 + Rust 核心，基于 iroh 网络库和 Loro CRDT 实现低感知、低延迟的跨设备笔记同步。

## 技术栈

| 层 | 技术 |
|---|------|
| 前端 | Flutter 3.44 (Dart 3.12) |
| 核心逻辑 | Rust (cardmind-backend) |
| CRDT 存储 | Loro 1.13 |
| 网络层 | iroh 1.0 (直连模式，默认禁用 relay) + mDNS |
| 查询层 | SQLite (Rust 端 rusqlite) |
| 跨语言桥 | flutter_rust_bridge 2.12 |

## 架构

```
Flutter (UI) ←→ FRB ←→ Rust (业务后端)
                          ├─ LoroDoc (真实信源)
                          ├─ SQLite (读模型)
                          └─ iroh + mDNS (网络同步与设备发现)
```

- **读写分离**：所有写入通过 Rust → LoroDoc，投影到 SQLite 供查询
- **单用户跨端**：目标平台为移动端（Android + iOS，覆盖手机与平板）与桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）；笔记编辑+列表采用双栏布局（仓库现有平台工程目录见 `AGENTS.md`「当前状态」）

## 项目结构

```
lib/              Flutter UI (v2)
  bridge/         Rust FFI 桥接辅助
  models/         Dart 领域模型
  pages/          页面
  scanner/        扫码桥接（Android 实现 + 桩）
  services/       应用级服务（设置、更新）
  ui/             设计系统组件
  src/rust/       FRB 自动生成代码
rust-backend/     Rust 核心
  src/            api, store, sync, discovery, debug_log
  tests/          集成测试
test/             Flutter 测试
integration_test/ 平台集成测试
docs/             文档（见「文档地图」）
tool/             工具脚本
sync-verify/      同步验证代码
```

## 文档架构

- `AGENTS.md`：仓库入口文档，定义读取顺序、命令与执行入口规则
- `docs/product.md`：产品定义
- `docs/adr/`：架构决策记录（长期决策的真相源）
- `docs/standards/`：工程规范
- `docs/research/`：仍服务于技术决策的研究资料
- `docs/testing/`：集成测试说明

## 常用命令

```bash
# Flutter
flutter pub get                         # 获取依赖
flutter analyze                         # 静态分析
flutter test                            # 测试
flutter build windows --release         # Windows 打包

# Rust
cd rust-backend && cargo test           # 测试
cd rust-backend && cargo build --release # 发布构建
```

## 文档地图

- `docs/product.md` — 产品定义
- `docs/personas.md` — 目标用户画像
- `docs/product-decisions.md` — 产品决策日志
- `docs/sync-network.md` — 同步网络设计
- `docs/goal.md` — 当前任务的正式行为与验收标准（设备连接可用性检查）
- `docs/adr/` — 架构决策记录
- `docs/research/` — 研究资料
- `docs/testing/` — 集成测试说明
- `docs/standards/` — 工程规范（AI 协作、TDD、测试、Git/PR、编码风格、UI 风格等）

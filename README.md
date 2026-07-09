# CardMind

面向多设备个人用户的笔记同步应用。Flutter 前端 + Rust 核心，基于 iroh 网络库和 Loro CRDT 实现低感知、低延迟的跨设备笔记同步。

## 技术栈

| 层 | 技术 |
|---|------|
| 前端 | Flutter 3.44 (Dart 3.12) |
| 核心逻辑 | Rust (cardmind-backend) |
| CRDT 存储 | Loro |
| 网络层 | iroh (直连模式) + mDNS |
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
- **单用户桌面优先**：Windows 为主平台，笔记编辑+列表双栏布局
- **原型双源**：`prototype/` 是 UI 原型真源

## 项目结构

```
lib/            Flutter UI (v2)
  bridge/       Rust FFI 桥接辅助
  models/       Dart 领域模型
  pages/        页面
  src/rust/     FRB 自动生成代码
rust-backend/   Rust 核心
  src/          api, store, sync, discovery
  tests/        集成测试
test/           Flutter 测试
prototype/      UI 原型（HTML/CSS）
docs/           文档
tool/           工具脚本
```

## 文档架构

- `AGENTS.md`：仓库入口文档，定义读取顺序、命令与执行入口规则
- `docs/product.md`：产品定位
- `docs/plans/`：历史设计计划（仅供追溯）
- `docs/standards/`：工程规范

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
- `docs/progress.md` — 工作进度
- `docs/standards/` — 工程规范（AI 协作、TDD、测试、Git/PR、编码风格、UI 风格等）

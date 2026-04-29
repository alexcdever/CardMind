# 分形文档规范设计（2026-02-25）

## 目标
- 通过“文件头声明 + 目录清单 + 根规范”形成自指约束，提升目标还原度。
- 以 AI 自觉维护为主，脚本/工具强制校验为兜底。
- 全仓一致性与可追溯性优先于开发速度。

## 范围
- 全仓目录与文件生效。
- 排除构建物与第三方依赖。
- 本设计仅定义规范与校验要求，不涉及业务逻辑修改。

## 产物
- `docs/standards/documentation.md`：规范正文与排除列表。
- `README.md`：添加指向规范的链接。
- `AGENTS.md`：添加指向规范的链接。
- 每个文件新增三行头部注释：`input`、`output`、`pos`。

## 规范定义
- 文件规则：文件头三行注释说明 `input`、`output`、`pos`，并明确“修改本文件需同步更新文件头”。

## 排除项
- 构建物与缓存目录：`build/`、`rust/target/`、`ios/Pods/`、`android/.gradle/`、`linux/build/`、`macos/Build/`、`windows/build/`。
- 依赖与锁文件：`pubspec.lock`。
- 代码生成文件（如存在）：`lib/**.g.dart`、`lib/**.freezed.dart`。

## 校验策略
- 新增文件必须包含三行头部注释。
- 脚本对排除路径不做检查。

## 验收标准
- 新增文件缺少头注释时校验失败。
- `docs/standards/documentation.md` 存在且可被 README/AGENTS 链接。

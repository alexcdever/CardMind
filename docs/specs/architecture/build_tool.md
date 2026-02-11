# 构建工具规格
- 相关文档:
  - [工具脚本收敛设计](../../plans/2026-02-04-tool-scripts-consolidation-design.md)
- 测试覆盖:
  - `test/unit/tool/build_dart_unit_test.dart`
  - `test/unit/tool/prepare_dart_unit_test.dart`

## 概述

构建工具由 `tool/build.dart` 与 `tool/prepare.dart` 组成。`build` 负责构建流程，`prepare` 负责环境检测与自动安装。

## 核心约束

- 所有构建必须先执行 `prepare`，`prepare` 失败则构建中止。
- 环境检测与安装逻辑必须位于 `prepare`，`build` 不再负责检测/安装。
- 平台默认矩阵：
  - macOS: Android + iOS + macOS
  - Windows: Windows
  - Linux: Linux
- Android NDK 路径与预编译目录必须动态选择，不允许写死平台目录。
- `prepare` 必须将环境变量写入当前 shell 配置文件（macOS 默认 `~/.zshrc`）。

## 数据流

1. `build` 解析平台参数
2. 调用 `prepare` → 检测/安装/生成环境映射
3. `build` 读取环境映射并执行构建

## 关键场景

### 场景：构建前准备
- **GIVEN** 用户执行 `dart tool/build.dart app`
- **WHEN** `build` 启动
- **THEN** 必须先调用 `prepare`，失败则立即退出

### 场景：不支持平台请求
- **GIVEN** 当前系统为 Windows
- **WHEN** 用户请求 iOS 平台
- **THEN** `prepare` 必须报错并退出

### 场景：NDK 路径选择
- **GIVEN** Android SDK 下存在多个 NDK 版本
- **WHEN** 执行 `prepare`
- **THEN** 必须选择最高版本并检测可用的 prebuilt 目录

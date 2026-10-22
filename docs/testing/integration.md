# Integration journeys

> 迁移 4.6 起：`integration_test/`（Flutter 平台集成测试）与 tool/feature_test.dart
> runner 已整删；前端为 NSH（`nsh-app`），真机/双实例验收改为按任务人工执行。
> 本文保留作测试地图说明；自动化 E2E runner 属后续任务。

## 现状测试资产

- **TSX 前端测试**：`nsh-app/*_test.ts` 与 `nsh-app/web/src/*_test.ts`，
  node --test 经 tsx 加载，门禁 `tsx:test` 全量跑：
  `cd nsh-app && npx tsx --test "*_test.ts" "web/src/*_test.ts"`。
- **Rust 集成测试**：`rust-backend/tests/`，`cargo test --all-features --jobs 1`；
  pre-commit 门禁按 staged 文件映射到具体 target。
- **数据共存探针**：`nsh-app/data_coexist_test.ts`（静态断言 + cargo 探针读夹具 db）。

## 发布/验收（无自动化 runner）

真机 GUI 与双实例 E2E 同步链路（NSH 壳 + Rust 后端 + iroh/mDNS）按任务验收执行，
不进 push 门禁。历史 Flutter journeys 与 tool/feature_test.dart 已在 4.6 删除，
如需恢复平台级集成 runner，以 NSH 打包产物（`nsh build`/`nsh package`）为对象重建。

# Spec-First Execution Policy

- 当任务涉及功能实现、行为变更、跨层改动（Flutter/Rust/FRB/存储/同步）时，先执行 `docs/specs/` 规格文档 CRUD 与一致性检查，再进入代码实现。

- 正式规格文档主目录为 `docs/specs/`；`docs/plans/` 用于设计与实现计划（含 ADR 式追溯），除非用户明确要求，不将正式规格写入 `docs/plans/`。

- 对 `docs/specs/` 的新增、删除、重命名，必须同步更新 `docs/specs/DIR.md`；目录语义变化时同步更新 `docs/DIR.md`。

- 使用执行计划类技能（如 executing-plans）时，将“规格文档 CRUD 与索引一致性检查”作为 Task 1。

- 需求存在缺口或冲突时，先在规格文档记录“待确认项/假设”，再推进实现。

- 仅在规格与实现不一致时更新规格，避免无关扩写，保持术语一致、范围清晰、验收标准可测试。

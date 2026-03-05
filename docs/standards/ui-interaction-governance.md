# UI Interaction Governance

- UI 交互变更必须同步更新治理文档三件套：
  - `docs/specs/ui-interaction.md`
  - `docs/specs/ui-interaction.md`
  - `docs/specs/ui-interaction.md`

- 治理守卫测试必须通过：`flutter test docs/standards/ui-interaction-governance.md`。

- 交互守卫测试必须通过：`flutter test test/interaction_guard_test.dart`，禁止空交互（如 `onPressed: () {}`、`onTap: () {}`）与无说明禁用交互（如 `onPressed: null`）。

- 发布前按门禁文档执行：`docs/specs/ui-interaction.md`。

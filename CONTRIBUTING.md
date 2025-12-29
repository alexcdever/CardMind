# 贡献指南

感谢你对 CardMind 项目的关注！我们欢迎各种形式的贡献。

## 🤝 如何贡献

### 报告 Bug

1. 在 [Issues](https://github.com/YOUR_USERNAME/CardMind/issues) 中搜索是否已有相同问题
2. 如果没有，创建新 Issue，包含：
   - 清晰的标题
   - 详细的复现步骤
   - 预期行为 vs 实际行为
   - 环境信息（`flutter doctor -v` 输出）
   - 相关日志或截图

### 提出功能建议

1. 检查 [ROADMAP.md](docs/ROADMAP.md) 是否已在规划中
2. 创建 Issue，标记为 `enhancement`
3. 描述：
   - 功能的使用场景
   - 为什么需要这个功能
   - 可能的实现方案（可选）

### 提交代码

#### 准备工作

1. Fork 本仓库
2. Clone 你的 fork：
   ```bash
   git clone https://github.com/YOUR_USERNAME/CardMind.git
   cd CardMind
   ```
3. 添加上游仓库：
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/CardMind.git
   ```
4. 按照 [SETUP.md](docs/SETUP.md) 搭建开发环境

#### 开发流程

1. **创建功能分支**
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout -b feature/your-feature-name
   ```

2. **TDD 开发**（必须！）
   ```bash
   # 先写测试
   # tests/your_feature_test.rs

   # 运行测试（应该失败）
   cargo test

   # 实现功能
   # src/your_feature.rs

   # 测试通过
   cargo test
   ```

3. **确保代码质量**
   ```bash
   # Rust 静态检查（必须零警告）
   cd rust
   cargo clippy --all-targets --all-features

   # Rust 格式化
   cargo fmt

   # Flutter 静态检查（必须零警告）
   flutter analyze

   # Flutter 格式化
   dart format lib/

   # 运行所有测试
   cargo test && flutter test

   # 检查测试覆盖率（必须 >80%）
   cargo tarpaulin --out Html
   ```

4. **提交代码**
   ```bash
   git add .
   git commit -m "feat: 简短描述

   详细说明（可选）
   - 要点1
   - 要点2
   "
   ```

   遵循 [Commit 规范](README.md#git-commit规范)

5. **推送到你的 fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **创建 Pull Request**
   - 在 GitHub 上创建 PR
   - 标题清晰简洁
   - 描述包含：
     - 解决的问题（关联 Issue）
     - 实现思路
     - 测试情况
     - 截图（如果是 UI 改动）

#### PR 检查清单

提交 PR 前，确保：

- [ ] **遵循架构规范**
  - [ ] 所有写操作通过 Loro，不直接写 SQLite
  - [ ] 调用了 `loro_doc.commit()`
  - [ ] 使用 UUID v7（不是 v4）

- [ ] **测试要求**
  - [ ] 新功能有对应测试
  - [ ] 所有测试通过
  - [ ] 测试覆盖率 >80%
  - [ ] 包含集成测试（如果涉及数据层）

- [ ] **代码质量**
  - [ ] `cargo clippy` 零警告
  - [ ] `flutter analyze` 零警告
  - [ ] 代码已格式化（`cargo fmt` 和 `dart format`）
  - [ ] 没有 `unwrap()` 或 `expect()`（使用 `?` 传播错误）

- [ ] **文档**
  - [ ] 公开 API 有文档注释
  - [ ] 复杂逻辑有代码注释
  - [ ] 更新了相关文档（如 API.md）

- [ ] **Git**
  - [ ] Commit 信息符合规范
  - [ ] 没有提交敏感信息
  - [ ] PR 描述清晰

## 📖 开发规范

### 必读文档

1. **[CLAUDE.md](CLAUDE.md)** - 架构核心规则（5条黄金规则）
2. **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - 技术架构设计
3. **[TESTING_GUIDE.md](docs/TESTING_GUIDE.md)** - TDD 开发流程

### 架构约束

**绝对不可违反的规则**：

1. 🚫 **永远不要直接写 SQLite** - 所有写操作必须通过 Loro
2. ✅ **必须调用 `loro_doc.commit()`** - 否则订阅不触发
3. 🆔 **必须使用 UUID v7** - 不是 v4
4. 🧪 **先写测试再写代码** - TDD 强制
5. 📊 **测试覆盖率 >80%** - 硬性要求

### 代码风格

**Rust**:
```rust
// ✅ 好的代码
pub fn create_card(&mut self, title: &str, content: &str) -> Result<Card> {
    let id = Uuid::now_v7().to_string();

    let doc = self.load_or_create_card_doc(&id)?;  // 使用 ?
    let card_map = doc.get_map("card");

    card_map.insert("title", title)?;
    doc.commit();  // 必须 commit

    Ok(card)
}

// ❌ 不好的代码
pub fn create_card(&mut self, title: &str, content: &str) -> Card {
    let id = Uuid::new_v4().to_string();  // 应该用 v7

    let doc = self.load_or_create_card_doc(&id).unwrap();  // 不要用 unwrap

    // 忘记 commit()

    card
}
```

**Flutter/Dart**:
```dart
// ✅ 好的代码
Future<Card> createCard(String title, String content) async {
  try {
    final card = await api.createCard(title: title, content: content);
    logger.i('卡片创建成功: ${card.id}');
    return card;
  } catch (e, stackTrace) {
    logger.e('创建卡片失败', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

// ❌ 不好的代码
Future<Card> createCard(String title, String content) async {
  final card = await api.createCard(title: title, content: content);
  print('创建成功');  // 应该用 logger
  return card;
}
```

## 🔍 Code Review 流程

1. **自动检查**（CI）
   - 运行所有测试
   - 检查代码覆盖率
   - 静态分析（clippy + flutter analyze）

2. **人工审查**
   - 架构合规性
   - 代码质量
   - 测试完整性
   - 文档完整性

3. **反馈和修改**
   - 根据 Review 意见修改
   - 推送更新到同一 PR
   - 重新触发 CI

4. **合并**
   - 所有检查通过
   - 至少 1 个 Reviewer 批准
   - 合并到 `develop` 分支

## 🎯 贡献的优先级

### 高优先级（急需）

- 🐛 Bug 修复
- 📝 文档改进（错别字、补充说明）
- 🧪 增加测试覆盖率

### 中优先级

- ✨ 新功能（需在 ROADMAP 中）
- ⚡ 性能优化
- ♿ 可访问性改进

### 低优先级

- 🎨 UI/UX 微调
- 📦 依赖更新
- 🔧 工具改进

### 暂不接受

- ❌ 不在 ROADMAP 中的大型功能
- ❌ 破坏架构的改动
- ❌ 没有测试的代码

## 💬 社区交流

### 获取帮助

1. 阅读 [FAQ.md](docs/FAQ.md)
2. 搜索已有 Issues
3. 在 Issues 中提问（标记 `question`）

### 讨论

- 大型功能建议：先创建 Issue 讨论，获得认可后再开发
- 架构问题：在 Issue 中讨论，标记 `architecture`
- 日常交流：Issue 评论区

## 📜 行为准则

### 我们的承诺

我们致力于为每个人提供友好、安全和包容的环境。

### 我们的标准

✅ **正面行为**:
- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情

❌ **不可接受的行为**:
- 使用性化语言或图像
- 人身攻击或贬损评论
- 公开或私下骚扰
- 未经许可发布他人的私人信息

### 执行

不遵守行为准则的情况将根据严重程度采取相应措施，包括警告、禁言或永久封禁。

## 📄 许可证

通过贡献代码，你同意你的贡献将在与项目相同的许可证下授权。

## 🙏 感谢

感谢每一位贡献者！你的参与让 CardMind 变得更好。

---

## 快速链接

- [开发环境搭建](docs/SETUP.md)
- [架构设计](docs/ARCHITECTURE.md)
- [TDD 指南](docs/TESTING_GUIDE.md)
- [开发路线图](docs/ROADMAP.md)
- [FAQ](docs/FAQ.md)

---

**首次贡献？** 寻找标记为 `good first issue` 的 Issue 开始！

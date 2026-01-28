## Context

**Background**: CardMind 当前缺乏移动端专用的全屏编辑体验。用户在移动设备上编辑笔记时，界面元素分散，缺乏专注环境，且没有自动保存机制保障数据安全。

**Current State**: 
- 现有编辑器基于桌面端设计，在移动端体验不佳
- 缺乏沉浸式编辑环境
- 手动保存机制容易导致数据丢失
- 没有针对移动端优化的交互设计

**Constraints**:
- 必须遵循移动端平台特定设计（非响应式）
- 需要与现有 Card 数据模型集成
- 必须支持 Flutter 框架和 Dart 语言
- 需要符合 CardMind 的双层架构（Loro CRDT + SQLite）

**Stakeholders**: 移动端用户、产品团队、开发团队

## Goals / Non-Goals

**Goals:**
- 提供沉浸式的移动端全屏编辑体验
- 实现自动保存机制（1秒防抖）保障数据安全
- 简化编辑功能，专注于标题和内容编辑
- 支持新建和编辑两种模式
- 防止用户误操作丢失数据

**Non-Goals:**
- 不支持标签管理功能（简化体验）
- 不支持富文本编辑（纯文本）
- 不支持协作编辑
- 不支持桌面端响应式设计

## Decisions

### 1. 组件架构设计

**Decision**: 使用 StatefulWidget 管理编辑器状态

**Rationale**: 
- 编辑器需要管理复杂的状态（标题、内容、自动保存定时器、未保存更改标记）
- StatefulWidget 提供生命周期管理，适合处理定时器和资源清理
- 与 Flutter 框架原生集成，性能最优

**Alternatives Considered**:
- StatelessWidget + 外部状态管理: 增加复杂度，不适合单次编辑场景
- Provider/BLoC: 过度工程化，增加不必要的抽象层

### 2. 自动保存机制

**Decision**: 使用 Timer 实现 1 秒防抖自动保存

**Rationale**:
- 防抖机制平衡保存频率和性能
- 1 秒延迟提供良好的用户体验，不会过于频繁
- Timer API 简单可靠，易于实现和测试

**Alternatives Considered**:
- ValueNotifier + debouncer: 增加依赖复杂度
- Stream + debounce: 过度抽象，不适合简单场景

### 3. 布局设计

**Decision**: 采用全屏沉浸式布局，工具栏固定顶部

**Rationale**:
- 符合移动端用户习惯（类似系统原生编辑器）
- 提供最大的编辑空间
- 工具栏固定位置便于用户访问

**Alternatives Considered**:
- 浮动工具栏: 遮挡编辑内容，体验不佳
- 底部工具栏: 与系统导航栏冲突，误操作风险高

### 4. 数据验证策略

**Decision**: 保存前进行内容验证，空内容不允许保存

**Rationale**:
- 防止创建无意义的空笔记
- 符合用户预期（笔记应该有内容）
- 减少数据污染，提升列表质量

**Alternatives Considered**:
- 允许空内容: 导致数据质量下降
- 软删除: 增加复杂度，不符合简化原则

### 5. 确认对话框设计

**Decision**: 有未保存更改时显示确认对话框

**Rationale**:
- 防止用户误操作丢失数据
- 自动保存有 1 秒延迟，可能存在未保存更改
- 给用户明确的选择权

**Alternatives Considered**:
- 自动保存无提示: 用户不知道是否有未保存更改
- 总是提示: 增加用户操作负担

## Risks / Trade-offs

### [Risk] 性能问题 → 长文本输入可能影响渲染性能
**Mitigation**: 使用 TextEditingController 原生管理，避免不必要的 Widget 重建

### [Risk] 内存泄漏 → Timer 可能导致内存泄漏
**Mitigation**: 在 dispose 方法中正确取消 Timer，遵循 Flutter 生命周期管理

### [Risk] 数据丢失 → 应用崩溃时可能丢失未保存数据
**Mitigation**: 1 秒防抖机制最大程度减少数据丢失，引导用户使用完成按钮

### [Risk] 用户体验 → 自动保存可能影响用户编辑流畅性
**Mitigation**: 异步保存，不阻塞 UI 线路，使用状态指示器

### [Trade-off] 功能简化 vs 功能完整性
**Decision**: 选择功能简化，专注核心编辑体验，移除标签等复杂功能

### [Trade-off] 移动端专用 vs 响应式设计
**Decision**: 选择移动端专用设计，提供最佳移动端体验

## Migration Plan

### Phase 1: 组件实现
1. 创建 NoteEditorFullscreen StatefulWidget
2. 实现基础布局和工具栏
3. 添加标题和内容输入框
4. 实现元数据显示区域

### Phase 2: 交互逻辑
1. 实现自动保存机制
2. 添加完成和关闭按钮逻辑
3. 实现确认对话框
4. 添加内容验证

### Phase 3: 集成测试
1. 单元测试覆盖所有状态管理
2. Widget 测试覆盖所有交互场景
3. 集成测试验证与数据层连接
4. 性能测试确保流畅体验

### Phase 4: 部署上线
1. 代码审查和测试验证
2. 渐进式发布（A/B 测试）
3. 监控用户反馈和性能指标
4. 回滚策略：保留原有编辑器作为备选

### Rollback Strategy
- 保留原有编辑器组件
- 通过功能开关控制新旧编辑器
- 监控关键指标（保存成功率、用户满意度）
- 问题严重时立即回滚到旧版本

## Open Questions

1. **国际化支持**: 工具栏文字和提示信息的多语言支持策略
2. **主题适配**: 深色模式下的具体颜色和样式定义
3. **无障碍支持**: 屏幕阅读器和其他辅助技术的兼容性
4. **性能基准**: 具体的性能指标和测试标准定义
5. **设备适配**: 不同屏幕尺寸和设备类型的适配策略

## Technical Specifications

### 组件结构定义

```dart
class NoteEditorFullscreen extends StatefulWidget {
  final Card? card;              // null = 新建模式，非 null = 编辑模式
  final String currentDevice;    // 当前设备标识
  final bool isOpen;             // 是否打开编辑器
  final OnClose onClose;         // 关闭回调
  final OnSave onSave;           // 保存回调

  const NoteEditorFullscreen({
    this.card,
    required this.currentDevice,
    required this.isOpen,
    required this.onClose,
    required this.onSave,
  });
}

typedef OnClose = void Function();
typedef OnSave = void Function(Card card);
```

### 状态管理定义

```dart
class _NoteEditorFullscreenState extends State<NoteEditorFullscreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  String _originalTitle = '';
  String _originalContent = '';
}
```

### 视觉布局规范

```
┌─────────────────────────────────────┐
│ [×]              自动保存  [完成]    │ ← 工具栏 (56px + SafeArea.top)
├─────────────────────────────────────┤
│                                     │
│  笔记标题 (Input)                    │ ← 标题输入框
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  开始写笔记... (Textarea)            │ ← 内容输入框 (min-h: 60vh)
│                                     │
│                                     │
│                                     │
│  ─────────────────────────────────  │
│  创建时间: 2026/1/26 14:30:45       │ ← 元数据区域
│  更新时间: 2026/1/26 15:20:30       │
│  最后编辑设备: iPhone 15            │
│                                     │
└─────────────────────────────────────┘
```

### 性能基准指标

| 指标 | 目标值 | 测试方法 |
|------|--------|----------|
| 自动保存频率 | 最多每秒 1 次 | 连续输入测试 |
| 内容输入响应 | < 16ms | 输入延迟测试 |
| 打开/关闭动画 | 60fps | 动画流畅度测试 |
| 内存使用增长 | < 10MB | 长时间编辑测试 |

### 数据模型集成

```dart
// 与现有 Card 模型集成
class Card {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastEditDevice;
  final bool deleted;
}
```

### 文件结构定义

```
lib/
├── widgets/
│   └── note_editor_fullscreen.dart
├── widgets/dialogs/
│   └── unsaved_changes_dialog.dart
└── models/
    └── editor_state.dart
```

### 国际化要求

```dart
// 支持的语言
const supportedLocales = [
  Locale('zh', 'CN'),  // 简体中文
  Locale('en', 'US'),  // 英语
];

// 需要国际化的文本
const i18nKeys = [
  'auto_save',           // 自动保存
  'complete',            // 完成
  'note_title',          // 笔记标题
  'start_writing',       // 开始写笔记...
  'content_empty',       // 内容不能为空
  'unsaved_changes',     // 有未保存的更改
  'save_and_close',      // 保存并关闭
  'discard_changes',     // 放弃更改
  'cancel',              // 取消
  'untitled_note',       // 无标题笔记
  'created_time',        // 创建时间
  'updated_time',        // 更新时间
  'last_edit_device',    // 最后编辑设备
];
```

### 可访问性要求

```dart
// 语义标签
Semantics(
  label: '笔记标题输入框',
  hint: '请输入笔记标题',
  textField: true,
)

// 交互提示
Semantics(
  button: true,
  label: '完成编辑',
  onTap: () => _handleComplete(),
)

// 状态通知
Semantics(
  liveRegion: true,
  label: '自动保存已启用',
)
```
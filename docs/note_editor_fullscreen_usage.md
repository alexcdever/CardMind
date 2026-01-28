# NoteEditorFullscreen 使用示例

## 基本用法

### 新建模式

```dart
import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isEditorOpen = false;

  void _openNewNoteEditor() {
    setState(() {
      _isEditorOpen = true;
    });
  }

  void _closeEditor() {
    setState(() {
      _isEditorOpen = false;
    });
  }

  void _saveCard(bridge.Card card) {
    // 保存卡片到数据库
    print('保存新卡片: ${card.title}');
    // TODO: 调用 Rust API 保存卡片
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('我的笔记')),
      body: Stack(
        children: [
          // 主内容
          Center(child: Text('笔记列表')),

          // 全屏编辑器
          if (_isEditorOpen)
            NoteEditorFullscreen(
              card: null, // null 表示新建模式
              currentDevice: 'iPhone 15',
              isOpen: _isEditorOpen,
              onClose: _closeEditor,
              onSave: _saveCard,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewNoteEditor,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### 编辑模式

```dart
class NoteListPage extends StatefulWidget {
  @override
  _NoteListPageState createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPageState> {
  bool _isEditorOpen = false;
  bridge.Card? _editingCard;

  void _openEditNoteEditor(bridge.Card card) {
    setState(() {
      _editingCard = card;
      _isEditorOpen = true;
    });
  }

  void _closeEditor() {
    setState(() {
      _isEditorOpen = false;
      _editingCard = null;
    });
  }

  void _updateCard(bridge.Card card) {
    // 更新卡片到数据库
    print('更新卡片: ${card.id}');
    // TODO: 调用 Rust API 更新卡片
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('笔记列表')),
      body: Stack(
        children: [
          // 笔记列表
          ListView(
            children: [
              ListTile(
                title: Text('示例笔记'),
                onTap: () => _openEditNoteEditor(
                  bridge.Card(
                    id: 'card-123',
                    title: '示例笔记',
                    content: '这是笔记内容',
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                    deleted: false,
                    tags: [],
                    lastEditDevice: 'iPhone 15',
                  ),
                ),
              ),
            ],
          ),

          // 全屏编辑器
          if (_isEditorOpen)
            NoteEditorFullscreen(
              card: _editingCard, // 传入现有卡片进行编辑
              currentDevice: 'iPhone 15',
              isOpen: _isEditorOpen,
              onClose: _closeEditor,
              onSave: _updateCard,
            ),
        ],
      ),
    );
  }
}
```

## 高级用法

### 与导航系统集成

```dart
class AppNavigator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: [
        MaterialPage(
          child: NoteListPage(),
        ),
      ],
      onPopPage: (route, result) {
        return route.didPop(result);
      },
    );
  }
}
```

### 与状态管理集成（Provider）

```dart
class NoteEditorProvider extends ChangeNotifier {
  bool _isOpen = false;
  bridge.Card? _editingCard;

  bool get isOpen => _isOpen;
  bridge.Card? get editingCard => _editingCard;

  void openNewNote() {
    _editingCard = null;
    _isOpen = true;
    notifyListeners();
  }

  void openEditNote(bridge.Card card) {
    _editingCard = card;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    _isOpen = false;
    _editingCard = null;
    notifyListeners();
  }

  Future<void> saveCard(bridge.Card card) async {
    // 保存卡片
    // TODO: 调用 Rust API
    close();
  }
}

// 使用
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NoteEditorProvider(),
      child: Consumer<NoteEditorProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            body: Stack(
              children: [
                // 主内容
                NoteListView(),

                // 编辑器
                if (provider.isOpen)
                  NoteEditorFullscreen(
                    card: provider.editingCard,
                    currentDevice: 'iPhone 15',
                    isOpen: provider.isOpen,
                    onClose: provider.close,
                    onSave: provider.saveCard,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

## 特性说明

### 自动保存

编辑器会在用户停止输入 1 秒后自动保存内容：

```dart
// 自动保存会调用 onSave 回调
onSave: (card) {
  print('自动保存触发');
  // 保存到数据库
}
```

### 未保存更改检测

当用户尝试关闭编辑器时，如果有未保存的更改，会显示确认对话框：

- **保存并关闭**: 保存更改并关闭编辑器
- **放弃更改**: 不保存更改，直接关闭
- **取消**: 返回编辑器继续编辑

### 空内容验证

- **新建模式**: 如果内容为空，可以直接关闭，不会创建笔记
- **编辑模式**: 如果内容为空，会显示错误提示"内容不能为空"

### 空标题处理

如果标题为空或只包含空格，保存时会自动填充为"无标题笔记"。

## 注意事项

1. **设备标识**: `currentDevice` 参数应该传入当前设备的唯一标识
2. **UUID 生成**: 新建模式下，当前实现使用临时 ID，实际应用中应该调用 Rust 层的 UUID v7 生成 API
3. **动画性能**: 编辑器使用 300ms 的滑入/滑出动画，确保在 60fps 下流畅运行
4. **内存管理**: 编辑器会在 dispose 时自动清理定时器和控制器，无需手动管理

## 测试

组件包含完整的测试覆盖：

```bash
# 运行单元测试
flutter test test/widgets/note_editor_fullscreen_unit_test.dart

# 运行 Widget 测试
flutter test test/widgets/note_editor_fullscreen_test.dart

# 运行所有测试
flutter test test/widgets/note_editor_fullscreen*.dart
```

## 参考

- 设计规格: `docs/plans/2026-01-25-note-editor-fullscreen-ui-design.md`
- OpenSpec 规格: `openspec/changes/note-editor-fullscreen-ui-design/`
- 数据模型: `rust/src/models/card.rs`

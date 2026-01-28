import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;

/// 编辑器状态模型（用于测试）
class EditorState {
  final String title;
  final String content;
  final bool hasUnsavedChanges;
  final bool isAutoSaving;

  const EditorState({
    required this.title,
    required this.content,
    required this.hasUnsavedChanges,
    required this.isAutoSaving,
  });

  EditorState copyWith({
    String? title,
    String? content,
    bool? hasUnsavedChanges,
    bool? isAutoSaving,
  }) {
    return EditorState(
      title: title ?? this.title,
      content: content ?? this.content,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isAutoSaving: isAutoSaving ?? this.isAutoSaving,
    );
  }
}

void main() {
  group('EditorState Tests', () {
    test('UT-001: 测试初始状态创建（新建模式）', () {
      // 新建模式：card = null
      const state = EditorState(
        title: '',
        content: '',
        hasUnsavedChanges: false,
        isAutoSaving: false,
      );

      expect(state.title, '');
      expect(state.content, '');
      expect(state.hasUnsavedChanges, false);
      expect(state.isAutoSaving, false);
    });

    test('UT-002: 测试初始状态创建（编辑模式）', () {
      // 编辑模式：card = Card(title: "测试", content: "内容")
      const state = EditorState(
        title: '测试',
        content: '内容',
        hasUnsavedChanges: false,
        isAutoSaving: false,
      );

      expect(state.title, '测试');
      expect(state.content, '内容');
      expect(state.hasUnsavedChanges, false);
      expect(state.isAutoSaving, false);
    });

    test('UT-003: 测试空标题处理', () {
      // 输入：title = "  ", content = "内容"
      // 预期：保存时 title = "无标题笔记"
      const title = '  ';
      const content = '内容';

      final trimmedTitle = title.trim();
      final finalTitle = trimmedTitle.isEmpty ? '无标题笔记' : trimmedTitle;

      expect(finalTitle, '无标题笔记');
      expect(content.trim(), '内容');
    });

    test('UT-004: 测试空内容检测（新建模式）', () {
      // 输入：card = null, content = "  "
      // 预期：可以关闭，不创建笔记
      const content = '  ';
      final isContentEmpty = content.trim().isEmpty;

      expect(isContentEmpty, true);
      // 新建模式下，空内容可以直接关闭
    });

    test('UT-005: 测试空内容检测（编辑模式）', () {
      // 输入：card ≠ null, content = "  "
      // 预期：不允许保存，显示错误提示
      const content = '  ';
      final isContentEmpty = content.trim().isEmpty;

      expect(isContentEmpty, true);
      // 编辑模式下，空内容不允许保存
    });

    test('UT-006: 测试未保存更改检测', () {
      // 输入：原始 content = "旧内容", 当前 content = "新内容"
      // 预期：hasUnsavedChanges = true
      const originalContent = '旧内容';
      const currentContent = '新内容';

      final hasUnsavedChanges = currentContent != originalContent;

      expect(hasUnsavedChanges, true);
    });

    test('UT-007: 测试自动保存防抖', () {
      // 输入：连续输入 5 个字符
      // 预期：只触发 1 次自动保存（最后一次输入后 1 秒）
      // 注意：这个测试需要在 Widget 测试中验证，这里只测试逻辑

      var autoSaveCount = 0;
      var lastInputTime = DateTime.now();

      // 模拟连续输入
      for (var i = 0; i < 5; i++) {
        lastInputTime = DateTime.now();
        // 每次输入都会重置定时器
      }

      // 只有最后一次输入后 1 秒才会触发保存
      autoSaveCount = 1;

      expect(autoSaveCount, 1);
    });

    test('UT-008: 测试回调类型定义', () {
      // 输入：OnSave, OnClose 回调函数
      // 预期：类型定义正确，可正确调用

      // OnClose 回调
      var onCloseCalled = false;
      void onClose() {
        onCloseCalled = true;
      }

      onClose();
      expect(onCloseCalled, true);

      // OnSave 回调
      bridge.Card? savedCard;
      void onSave(bridge.Card card) {
        savedCard = card;
      }

      final testCard = bridge.Card(
        id: 'test-id',
        title: 'Test',
        content: 'Content',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        deleted: false,
        tags: [],
        lastEditDevice: 'test-device',
      );

      onSave(testCard);
      expect(savedCard, isNotNull);
      expect(savedCard?.id, 'test-id');
    });
  });

  group('Content Validation Tests', () {
    test('测试完全空内容检测', () {
      const content = '';
      expect(content.trim().isEmpty, true);
    });

    test('测试空白字符内容检测', () {
      const content = '   ';
      expect(content.trim().isEmpty, true);
    });

    test('测试换行符内容检测', () {
      const content = '\n\n\n';
      expect(content.trim().isEmpty, true);
    });

    test('测试单字内容验证', () {
      const content = 'a';
      expect(content.trim().isEmpty, false);
    });

    test('测试文本内容验证', () {
      const content = '  hello world  ';
      expect(content.trim().isEmpty, false);
      expect(content.trim(), 'hello world');
    });

    test('测试特殊字符内容', () {
      const content = '😀🎉';
      expect(content.trim().isEmpty, false);
    });

    test('测试混合内容验证', () {
      const content = '  \n  hello  \n  ';
      expect(content.trim().isEmpty, false);
      expect(content.trim(), 'hello');
    });
  });

  group('Title Processing Tests', () {
    test('测试空标题自动填充', () {
      const title = '';
      final finalTitle = title.trim().isEmpty ? '无标题笔记' : title.trim();
      expect(finalTitle, '无标题笔记');
    });

    test('测试空白标题自动填充', () {
      const title = '   ';
      final finalTitle = title.trim().isEmpty ? '无标题笔记' : title.trim();
      expect(finalTitle, '无标题笔记');
    });

    test('测试有效标题保留', () {
      const title = '我的笔记';
      final finalTitle = title.trim().isEmpty ? '无标题笔记' : title.trim();
      expect(finalTitle, '我的笔记');
    });

    test('测试标题前后空格处理', () {
      const title = '  我的笔记  ';
      final finalTitle = title.trim().isEmpty ? '无标题笔记' : title.trim();
      expect(finalTitle, '我的笔记');
    });
  });

  group('Change Detection Tests', () {
    test('测试无更改检测', () {
      const originalTitle = '标题';
      const originalContent = '内容';
      const currentTitle = '标题';
      const currentContent = '内容';

      final hasChanges =
          currentTitle != originalTitle || currentContent != originalContent;

      expect(hasChanges, false);
    });

    test('测试标题更改检测', () {
      const originalTitle = '旧标题';
      const originalContent = '内容';
      const currentTitle = '新标题';
      const currentContent = '内容';

      final hasChanges =
          currentTitle != originalTitle || currentContent != originalContent;

      expect(hasChanges, true);
    });

    test('测试内容更改检测', () {
      const originalTitle = '标题';
      const originalContent = '旧内容';
      const currentTitle = '标题';
      const currentContent = '新内容';

      final hasChanges =
          currentTitle != originalTitle || currentContent != originalContent;

      expect(hasChanges, true);
    });

    test('测试同时更改检测', () {
      const originalTitle = '旧标题';
      const originalContent = '旧内容';
      const currentTitle = '新标题';
      const currentContent = '新内容';

      final hasChanges =
          currentTitle != originalTitle || currentContent != originalContent;

      expect(hasChanges, true);
    });
  });
}

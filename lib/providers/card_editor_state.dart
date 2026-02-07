import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/card_api_impl.dart';
import '../services/card_api_interface.dart';

/// Card Editor State Management
///
/// 规格编号: SP-FLUT-009
/// 管理卡片编辑器的状态，包括：
/// - 标题和内容
/// - 自动保存状态
/// - 错误处理
/// - 验证逻辑
class CardEditorState extends ChangeNotifier {
  /// 构造函数，允许注入 API 实现
  CardEditorState({CardApiInterface? cardApi})
    : _cardApi = cardApi ?? CardApiImpl();
  // ========================================
  // 依赖注入
  // ========================================

  /// Card API 接口（可以注入 mock 实现用于测试）
  final CardApiInterface _cardApi;

  // ========================================
  // 状态字段
  // ========================================

  /// 卡片 ID（创建后保存）
  String? _cardId;

  /// 卡片标题
  String _title = '';

  /// 卡片内容（支持 Markdown）
  String _content = '';

  /// 是否正在保存
  bool _isSaving = false;

  /// 错误信息
  String? _errorMessage;

  /// 最后保存时间
  DateTime? _lastSaved;

  /// 自动保存 debounce timer
  Timer? _debounceTimer;

  /// 成功指示器 timer
  Timer? _successTimer;

  /// 是否显示成功指示器
  bool _showSuccessIndicator = false;

  // ========================================
  // Getters
  // ========================================

  String get title => _title;
  String get content => _content;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSaved => _lastSaved;
  bool get showSuccessIndicator => _showSuccessIndicator;

  /// 标题是否有效（非空且不超过 200 字符）
  bool get isTitleValid {
    final trimmed = _title.trim();
    return trimmed.isNotEmpty && trimmed.length <= 200;
  }

  /// 是否有未保存的更改
  bool get hasUnsavedChanges {
    return _title.isNotEmpty || _content.isNotEmpty;
  }

  // ========================================
  // 任务 3.4: 实现 updateTitle() 方法
  // ========================================

  /// 更新标题
  ///
  /// 触发自动保存（500ms debounce）
  void updateTitle(String newTitle) {
    _title = newTitle;
    _errorMessage = null; // 清除错误信息
    notifyListeners();

    // 触发自动保存
    _triggerAutoSave();
  }

  // ========================================
  // 任务 3.5: 实现 updateContent() 方法
  // ========================================

  /// 更新内容
  ///
  /// 触发自动保存（500ms debounce）
  void updateContent(String newContent) {
    _content = newContent;
    _errorMessage = null; // 清除错误信息
    notifyListeners();

    // 触发自动保存
    _triggerAutoSave();
  }

  // ========================================
  // 任务 3.6: 实现 autoSave() 方法（带 debounce）
  // ========================================

  /// 触发自动保存（带 500ms debounce）
  void _triggerAutoSave() {
    // 取消之前的 timer
    _debounceTimer?.cancel();

    // 设置新的 timer（500ms 后执行）
    _debounceTimer = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  /// 执行自动保存
  Future<void> _autoSave() async {
    // 只有标题有效时才保存
    if (!isTitleValid) {
      return;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_cardId == null) {
        // 第一次保存：创建新卡片
        final card = await _cardApi.createCard(
          title: _title.trim(),
          content: _content,
        );
        _cardId = card.id;
      } else {
        // 后续保存：更新已存在的卡片
        await _cardApi.updateCard(
          id: _cardId!,
          title: _title.trim(),
          content: _content,
        );
      }

      _lastSaved = DateTime.now();
      _isSaving = false;

      // 显示成功指示器 2 秒
      _showSuccessIndicator = true;
      notifyListeners();

      _successTimer?.cancel();
      _successTimer = Timer(const Duration(seconds: 2), () {
        _showSuccessIndicator = false;
        notifyListeners();
      });
    } on Exception catch (e) {
      _handleSaveError(e);
    }
  }

  // ========================================
  // 任务 3.7: 实现 manualSave() 方法
  // ========================================

  /// 手动保存（点击"完成"按钮时调用）
  ///
  /// 返回是否保存成功
  Future<bool> manualSave() async {
    // 验证输入
    final validationError = validate();
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_cardId == null) {
        // 第一次保存：创建新卡片
        final card = await _cardApi.createCard(
          title: _title.trim(),
          content: _content,
        );
        _cardId = card.id;
      } else {
        // 后续保存：更新已存在的卡片
        await _cardApi.updateCard(
          id: _cardId!,
          title: _title.trim(),
          content: _content,
        );
      }

      _lastSaved = DateTime.now();
      _isSaving = false;
      notifyListeners();

      return true;
    } on Exception catch (e) {
      _handleSaveError(e);
      return false;
    }
  }

  // ========================================
  // 任务 3.8: 实现 validate() 方法
  // ========================================

  /// 验证输入
  ///
  /// 返回错误信息，如果验证通过则返回 null
  String? validate() {
    final trimmedTitle = _title.trim();

    // 检查标题是否为空
    if (trimmedTitle.isEmpty) {
      return '标题不能为空';
    }

    // 检查标题长度
    if (trimmedTitle.length > 200) {
      return '标题不能超过 200 字符';
    }

    // 内容可以为空，不需要验证

    return null;
  }

  // ========================================
  // 任务 3.9: 实现错误处理逻辑
  // ========================================

  /// 处理保存错误
  void _handleSaveError(Object error) {
    _isSaving = false;

    // 根据错误类型设置错误信息
    if (error.toString().contains('network') ||
        error.toString().contains('connection')) {
      _errorMessage = '保存失败，请检查网络连接';
    } else {
      _errorMessage = '保存失败: ${error.toString()}';
    }

    notifyListeners();
  }

  /// 重试保存
  Future<void> retrySave() async {
    _errorMessage = null;
    notifyListeners();

    await manualSave();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ========================================
  // 清理资源
  // ========================================

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }
}

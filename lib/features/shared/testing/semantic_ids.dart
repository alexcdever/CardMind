/// # 语义标识常量
///
/// 测试可访问性标识常量文件，供跨页面共享。
///
/// 提供 UI 自动化与 widget test 共享的语义标识常量，
/// 集中定义关键交互控件的稳定 semantics id，避免散落硬编码。
///
/// 本文件集中管理自动化锚点，避免页面内重复硬编码。
library semantic_ids;

/// 语义标识常量集合。
///
/// 包含所有 UI 自动化测试所需的语义标识符。
class SemanticIds {
  /// 卡片搜索输入框。
  static const cardsSearchInput = 'cards.search_input';

  /// 卡片创建浮动按钮。
  static const cardsCreateFab = 'cards.create_fab';

  /// 卡片列表。
  static const cardsList = 'cards.list';

  /// 桌面编辑器标题输入框。
  static const cardsDesktopEditorTitleInput =
      'cards.desktop_editor.title_input';

  /// 桌面编辑器正文输入框。
  static const cardsDesktopEditorBodyInput = 'cards.desktop_editor.body_input';

  /// 桌面编辑器保存按钮。
  static const cardsDesktopEditorSaveButton =
      'cards.desktop_editor.save_button';

  /// 离开对话框保存按钮。
  static const cardsLeaveDialogSave = 'cards.leave_dialog.save';

  /// 离开对话框放弃按钮。
  static const cardsLeaveDialogDiscard = 'cards.leave_dialog.discard';

  /// 离开对话框取消按钮。
  static const cardsLeaveDialogCancel = 'cards.leave_dialog.cancel';

  /// 卡片项前缀。
  static const cardsItemPrefix = 'cards.item';

  /// 编辑器标题输入框。
  static const editorTitleInput = 'editor.title_input';

  /// 编辑器正文输入框。
  static const editorBodyInput = 'editor.body_input';

  /// 编辑器保存按钮。
  static const editorSaveButton = 'editor.save_button';

  /// 编辑器离开对话框保存按钮。
  static const editorLeaveDialogSave = 'editor.leave_dialog.save';

  /// 编辑器离开对话框放弃按钮。
  static const editorLeaveDialogDiscard = 'editor.leave_dialog.discard';

  /// 编辑器离开对话框取消按钮。
  static const editorLeaveDialogCancel = 'editor.leave_dialog.cancel';

  /// 池创建按钮。
  static const poolCreateButton = 'pool.create_button';

  /// 池加入扫码按钮。
  static const poolJoinScanButton = 'pool.join_scan_button';

  /// 池编辑按钮。
  static const poolEditButton = 'pool.edit_button';

  /// 池解散按钮。
  static const poolDissolveButton = 'pool.dissolve_button';

  /// 池离开按钮。
  static const poolLeaveButton = 'pool.leave_button';

  /// 待处理申请通过按钮。
  static const poolPendingApprove = 'pool.pending.approve';

  /// 待处理申请拒绝按钮。
  static const poolPendingReject = 'pool.pending.reject';

  /// 离开对话框确认按钮。
  static const poolLeaveDialogConfirm = 'pool.leave_dialog.confirm';

  /// 离开对话框取消按钮。
  static const poolLeaveDialogCancel = 'pool.leave_dialog.cancel';

  /// 错误主操作按钮。
  static const poolErrorPrimaryAction = 'pool.error.primary_action';

  /// 扫码对话框成功状态。
  static const poolScanDialogSuccess = 'pool.scan_dialog.success';

  /// 扫码对话框管理员离线状态。
  static const poolScanDialogAdminOffline = 'pool.scan_dialog.admin_offline';

  /// 扫码对话框超时状态。
  static const poolScanDialogTimeout = 'pool.scan_dialog.timeout';

  /// 编辑对话框名称输入框。
  static const poolEditDialogNameInput = 'pool.edit_dialog.name_input';

  /// 编辑对话框保存按钮。
  static const poolEditDialogSave = 'pool.edit_dialog.save';

  /// 编辑对话框取消按钮。
  static const poolEditDialogCancel = 'pool.edit_dialog.cancel';

  /// 解散对话框确认按钮。
  static const poolDissolveDialogConfirm = 'pool.dissolve_dialog.confirm';

  /// 解散对话框取消按钮。
  static const poolDissolveDialogCancel = 'pool.dissolve_dialog.cancel';

  /// 同步重试按钮。
  static const poolSyncRetry = 'pool.sync.retry';

  /// 同步重连按钮。
  static const poolSyncReconnect = 'pool.sync.reconnect';

  /// 同步查看错误按钮。
  static const poolSyncViewError = 'pool.sync.view_error';

  /// 导航栏卡片页。
  static const navCards = 'nav.cards';

  /// 导航栏池页。
  static const navPool = 'nav.pool';

  /// 设置页面。
  static const settingsPage = 'settings.page';

  /// 卡片上下文菜单删除选项。
  static const cardsContextMenuDelete = 'cards.context_menu.delete';
}

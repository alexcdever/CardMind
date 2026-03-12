// input: 提供 UI 自动化与 widget test 共享的语义标识常量。
// output: 集中定义关键交互控件的稳定 semantics id，避免散落硬编码。
// pos: 测试可访问性标识常量文件，供跨页面共享。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件集中管理自动化锚点，避免页面内重复硬编码。
class SemanticIds {
  static const cardsSearchInput = 'cards.search_input';
  static const cardsCreateFab = 'cards.create_fab';
  static const cardsList = 'cards.list';
  static const cardsDesktopEditorTitleInput =
      'cards.desktop_editor.title_input';
  static const cardsDesktopEditorBodyInput = 'cards.desktop_editor.body_input';
  static const cardsDesktopEditorSaveButton =
      'cards.desktop_editor.save_button';
  static const cardsLeaveDialogSave = 'cards.leave_dialog.save';
  static const cardsLeaveDialogDiscard = 'cards.leave_dialog.discard';
  static const cardsLeaveDialogCancel = 'cards.leave_dialog.cancel';
  static const cardsItemPrefix = 'cards.item';

  static const editorTitleInput = 'editor.title_input';
  static const editorBodyInput = 'editor.body_input';
  static const editorSaveButton = 'editor.save_button';
  static const editorLeaveDialogSave = 'editor.leave_dialog.save';
  static const editorLeaveDialogDiscard = 'editor.leave_dialog.discard';
  static const editorLeaveDialogCancel = 'editor.leave_dialog.cancel';

  static const poolCreateButton = 'pool.create_button';
  static const poolJoinScanButton = 'pool.join_scan_button';
  static const poolEditButton = 'pool.edit_button';
  static const poolDissolveButton = 'pool.dissolve_button';
  static const poolLeaveButton = 'pool.leave_button';
  static const poolPendingApprove = 'pool.pending.approve';
  static const poolPendingReject = 'pool.pending.reject';
  static const poolLeaveDialogConfirm = 'pool.leave_dialog.confirm';
  static const poolLeaveDialogCancel = 'pool.leave_dialog.cancel';
  static const poolErrorPrimaryAction = 'pool.error.primary_action';
  static const poolScanDialogSuccess = 'pool.scan_dialog.success';
  static const poolScanDialogAdminOffline = 'pool.scan_dialog.admin_offline';
  static const poolScanDialogTimeout = 'pool.scan_dialog.timeout';
  static const poolEditDialogNameInput = 'pool.edit_dialog.name_input';
  static const poolEditDialogSave = 'pool.edit_dialog.save';
  static const poolEditDialogCancel = 'pool.edit_dialog.cancel';
  static const poolDissolveDialogConfirm = 'pool.dissolve_dialog.confirm';
  static const poolDissolveDialogCancel = 'pool.dissolve_dialog.cancel';
  static const poolSyncRetry = 'pool.sync.retry';
  static const poolSyncReconnect = 'pool.sync.reconnect';
  static const poolSyncViewError = 'pool.sync.view_error';
}

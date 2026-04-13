part of 'pool_page.dart';

extension _PoolPageDialogs on _PoolPageState {
  Future<void> _scanAndJoin(BuildContext context) async {
    var draftCode = '';
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('扫码加入'),
          content: Semantics(
            container: true,
            explicitChildNodes: true,
            identifier: SemanticIds.poolJoinDialogCodeInput,
            label: '加入码输入框',
            textField: true,
            child: TextFormField(
              key: const ValueKey('pool.join_dialog.code_input'),
              autofocus: true,
              onChanged: (value) {
                draftCode = value;
              },
              decoration: const InputDecoration(
                labelText: '加入码',
                hintText: '输入池 ID 或加入字符串',
              ),
            ),
          ),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolJoinDialogCancel,
              label: '取消加入数据池',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.join_dialog.cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolJoinDialogConfirm,
              label: '确认加入数据池',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.join_dialog.confirm'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop(draftCode.trim()),
                child: const Text('确认加入'),
              ),
            ),
          ],
        );
      },
    );

    if (code == null || code.trim().isEmpty) return;
    unawaited(_controller.joinByCode(code));
  }

  Future<void> _confirmLeavePool(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: const Text('退出后会移除池关联数据，确认退出吗？'),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolLeaveDialogCancel,
              label: '取消退出数据池',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.leave_dialog.cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolLeaveDialogConfirm,
              label: '确认退出数据池',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.leave_dialog.confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认退出'),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) return;
    unawaited(Future<void>(() => _controller.confirmExit()));
  }

  Future<bool> _showConfirmationDialog({
    required BuildContext context,
    required String content,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(content),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: confirmLabel == '确认解散'
                  ? SemanticIds.poolDissolveDialogCancel
                  : SemanticIds.poolLeaveDialogCancel,
              label: confirmLabel == '确认解散' ? '取消解散数据池' : '取消',
              button: true,
              child: TextButton(
                key: ValueKey(
                  confirmLabel == '确认解散'
                      ? 'pool.dissolve_dialog.cancel'
                      : 'pool.confirm_dialog.cancel',
                ),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: confirmLabel == '确认解散'
                  ? SemanticIds.poolDissolveDialogConfirm
                  : SemanticIds.poolLeaveDialogConfirm,
              label: confirmLabel == '确认解散' ? '确认解散数据池' : confirmLabel,
              button: true,
              child: TextButton(
                key: ValueKey(
                  confirmLabel == '确认解散'
                      ? 'pool.dissolve_dialog.confirm'
                      : 'pool.confirm_dialog.confirm',
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _showEditPoolDialog(BuildContext context) async {
    final state = _controller.state;
    if (state is! PoolJoined) return;

    var draftName = state.poolName;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑池信息'),
          content: Semantics(
            container: true,
            explicitChildNodes: true,
            identifier: SemanticIds.poolEditDialogNameInput,
            label: '池名称输入框',
            textField: true,
            child: TextFormField(
              key: const ValueKey('pool.edit_dialog.name_input'),
              initialValue: state.poolName,
              onChanged: (value) {
                draftName = value;
              },
            ),
          ),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolEditDialogCancel,
              label: '取消编辑池信息',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.edit_dialog.cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolEditDialogSave,
              label: '保存池信息',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.edit_dialog.save'),
                onPressed: () => Navigator.of(dialogContext).pop(draftName),
                child: const Text('保存'),
              ),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    _controller.editPoolInfo(name.trim());
  }

  Future<void> _confirmDissolvePool(BuildContext context) async {
    final confirmed = await _showConfirmationDialog(
      context: context,
      content: '确认解散该数据池？',
      confirmLabel: '确认解散',
    );

    if (confirmed) {
      _controller.dissolvePool();
    }
  }
}

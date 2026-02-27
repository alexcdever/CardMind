enum JoinAction {
  retryWithNewInfo,
  rescan,
  retryJoin,
  retryLater,
  retryNowOrUseLocal,
  reapply,
  goToPoolDetails,
}

class JoinErrorUiModel {
  const JoinErrorUiModel({
    required this.message,
    required this.primaryActionLabel,
    required this.action,
  });

  final String message;
  final String primaryActionLabel;
  final JoinAction action;
}

JoinErrorUiModel mapJoinError(String code) {
  switch (code) {
    case 'POOL_NOT_FOUND':
      return const JoinErrorUiModel(
        message: '未找到该数据池，请重新获取池信息。',
        primaryActionLabel: '重新获取池信息',
        action: JoinAction.retryWithNewInfo,
      );
    case 'INVALID_POOL_HASH':
      return const JoinErrorUiModel(
        message: '池标识无效，请重新扫码。',
        primaryActionLabel: '重新扫码',
        action: JoinAction.rescan,
      );
    case 'INVALID_KEY_HASH':
      return const JoinErrorUiModel(
        message: '校验失败，请重新发起加入。',
        primaryActionLabel: '重新发起加入',
        action: JoinAction.retryJoin,
      );
    case 'ADMIN_OFFLINE':
      return const JoinErrorUiModel(
        message: '管理员离线，请稍后重试。',
        primaryActionLabel: '稍后重试',
        action: JoinAction.retryLater,
      );
    case 'REQUEST_TIMEOUT':
      return const JoinErrorUiModel(
        message: '请求超时，可立即重试或继续本地使用。',
        primaryActionLabel: '立即重试',
        action: JoinAction.retryNowOrUseLocal,
      );
    case 'REJECTED_BY_ADMIN':
      return const JoinErrorUiModel(
        message: '申请已被管理员拒绝，可重新申请。',
        primaryActionLabel: '重新申请',
        action: JoinAction.reapply,
      );
    case 'ALREADY_MEMBER':
      return const JoinErrorUiModel(
        message: '你已是成员，可直接进入池详情。',
        primaryActionLabel: '前往池详情',
        action: JoinAction.goToPoolDetails,
      );
    default:
      return const JoinErrorUiModel(
        message: '请求失败，请重试。',
        primaryActionLabel: '重试加入',
        action: JoinAction.retryJoin,
      );
  }
}

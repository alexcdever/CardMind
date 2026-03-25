/// # 加入错误映射器
///
/// 负责将加入数据池失败的错误码转换为可展示的 UI 语义。
/// 提供用户友好的错误提示和对应的操作指引。
library join_error_mapper;

/// 加入操作的用户交互动作类型。
enum JoinAction {
  /// 使用新信息重试。
  retryWithNewInfo,

  /// 重新扫码。
  rescan,

  /// 重试加入。
  retryJoin,

  /// 稍后重试。
  retryLater,

  /// 立即重试或使用本地。
  retryNowOrUseLocal,

  /// 重新申请。
  reapply,

  /// 前往池详情。
  goToPoolDetails,
}

/// 加入错误 UI 模型。
///
/// 包含展示给用户的错误信息和建议操作。
class JoinErrorUiModel {
  /// 创建加入错误 UI 模型。
  const JoinErrorUiModel({
    required this.message,
    required this.primaryActionLabel,
    required this.action,
  });

  /// 展示给用户的错误消息。
  final String message;

  /// 主操作按钮的标签。
  final String primaryActionLabel;

  /// 建议的用户操作。
  final JoinAction action;
}

/// 将错误码映射为 UI 模型。
///
/// [code] - 后端返回的错误码。
///
/// 返回包含用户友好提示和操作指引的 UI 模型。
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
        message: '发生了什么：请求超时。可以做什么：立即重试或继续本地使用。',
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

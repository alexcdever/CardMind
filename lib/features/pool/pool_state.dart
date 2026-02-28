// input: lib/features/pool/pool_state.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 功能模块，负责状态编排、交互反馈与页面渲染。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
sealed class PoolState {
  const PoolState();

  const factory PoolState.notJoined() = PoolNotJoined;
  const factory PoolState.joined({
    List<PoolPendingRequest> pending,
    bool exitShouldFail,
    String? approvalMessage,
  }) = PoolJoined;
  const factory PoolState.error(String code) = PoolError;
  const factory PoolState.exitPartialCleanup() = PoolExitPartialCleanup;

  static PoolState joinedWithPending() {
    return const PoolState.joined(
      pending: <PoolPendingRequest>[
        PoolPendingRequest(id: 'alice', displayName: 'alice@pending'),
      ],
    );
  }
}

class PoolNotJoined extends PoolState {
  const PoolNotJoined();
}

class PoolJoined extends PoolState {
  const PoolJoined({
    this.pending = const <PoolPendingRequest>[],
    this.exitShouldFail = false,
    this.approvalMessage,
  });

  final List<PoolPendingRequest> pending;
  final bool exitShouldFail;
  final String? approvalMessage;
}

class PoolError extends PoolState {
  const PoolError(this.code);

  final String code;
}

class PoolExitPartialCleanup extends PoolState {
  const PoolExitPartialCleanup();
}

class PoolPendingRequest {
  const PoolPendingRequest({
    required this.id,
    required this.displayName,
    this.rejectShouldFail = false,
    this.error,
  });

  final String id;
  final String displayName;
  final bool rejectShouldFail;
  final String? error;

  PoolPendingRequest copyWith({String? error}) {
    return PoolPendingRequest(
      id: id,
      displayName: displayName,
      rejectShouldFail: rejectShouldFail,
      error: error,
    );
  }
}

// input: 池流程运行态与待审批请求数据
// output: 池页面渲染所需状态模型与实体
// pos: 池域状态定义；修改需同步控制器、页面与测试
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

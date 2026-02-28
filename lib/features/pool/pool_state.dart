// input: 业务通过工厂构造传入 pending、error code、exit 标记等状态数据。
// output: 提供 PoolState 各分支类型与 PoolPendingRequest 数据结构。
// pos: 数据池状态模型定义，负责描述入池流程全部状态形态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
sealed class PoolState {
  const PoolState();

  const factory PoolState.notJoined() = PoolNotJoined;
  const factory PoolState.joined({
    List<PoolPendingRequest> pending,
    bool exitShouldFail,
    String poolName,
    bool isOwner,
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
    this.poolName = '默认数据池',
    this.isOwner = true,
    this.approvalMessage,
  });

  final List<PoolPendingRequest> pending;
  final bool exitShouldFail;
  final String poolName;
  final bool isOwner;
  final String? approvalMessage;

  PoolJoined copyWith({
    List<PoolPendingRequest>? pending,
    bool? exitShouldFail,
    String? poolName,
    bool? isOwner,
    String? approvalMessage,
  }) {
    return PoolJoined(
      pending: pending ?? this.pending,
      exitShouldFail: exitShouldFail ?? this.exitShouldFail,
      poolName: poolName ?? this.poolName,
      isOwner: isOwner ?? this.isOwner,
      approvalMessage: approvalMessage ?? this.approvalMessage,
    );
  }
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

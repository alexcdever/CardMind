sealed class PoolState {
  const PoolState();

  const factory PoolState.notJoined() = PoolNotJoined;
  const factory PoolState.joined() = PoolJoined;
  const factory PoolState.error(String code) = PoolError;
}

class PoolNotJoined extends PoolState {
  const PoolNotJoined();
}

class PoolJoined extends PoolState {
  const PoolJoined();
}

class PoolError extends PoolState {
  const PoolError(this.code);

  final String code;
}

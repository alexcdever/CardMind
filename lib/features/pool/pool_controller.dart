import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter/foundation.dart';

class PoolController extends ChangeNotifier {
  PoolController({PoolState initialState = const PoolState.notJoined()})
    : _state = initialState;

  PoolState _state;

  PoolState get state => _state;

  void setState(PoolState state) {
    _state = state;
    notifyListeners();
  }

  void createPool() {
    _state = const PoolState.joined();
    notifyListeners();
  }

  void approve(String requestId) {
    final joined = _state;
    if (joined is! PoolJoined) return;

    final updated = joined.pending
        .where((item) => item.id != requestId)
        .toList(growable: false);

    _state = PoolState.joined(
      pending: updated,
      exitShouldFail: joined.exitShouldFail,
      approvalMessage: '审批已通过',
    );
    notifyListeners();
  }

  void reject(String requestId) {
    final joined = _state;
    if (joined is! PoolJoined) return;

    final updated = joined.pending
        .map((item) {
          if (item.id != requestId) return item;
          if (item.rejectShouldFail) {
            return item.copyWith(error: '拒绝失败：网络异常');
          }
          return null;
        })
        .whereType<PoolPendingRequest>()
        .toList(growable: false);

    _state = PoolState.joined(
      pending: updated,
      exitShouldFail: joined.exitShouldFail,
      approvalMessage: joined.approvalMessage,
    );
    notifyListeners();
  }

  void simulateRejectFailurePending() {
    _state = const PoolState.joined(
      pending: <PoolPendingRequest>[
        PoolPendingRequest(
          id: 'bob',
          displayName: 'bob@pending-fail',
          rejectShouldFail: true,
        ),
      ],
    );
    notifyListeners();
  }

  void confirmExit() {
    final joined = _state;
    if (joined is PoolJoined && joined.exitShouldFail) {
      _state = const PoolState.exitPartialCleanup();
      notifyListeners();
      return;
    }

    _state = const PoolState.notJoined();
    notifyListeners();
  }

  void retryCleanup() {
    _state = const PoolState.notJoined();
    notifyListeners();
  }
}

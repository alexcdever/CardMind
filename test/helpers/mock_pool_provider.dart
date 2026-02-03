import 'package:cardmind/providers/pool_provider.dart';

/// Test double for PoolProvider to control joined state in UI tests.
class MockPoolProvider extends PoolProvider {
  MockPoolProvider({bool isJoined = true}) : _isJoined = isJoined;

  final bool _isJoined;

  @override
  bool get isJoined => _isJoined;
}

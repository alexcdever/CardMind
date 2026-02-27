import 'package:cardmind/features/pool/join_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps ADMIN_OFFLINE to retry message', () {
    expect(mapJoinError('ADMIN_OFFLINE'), contains('稍后重试'));
  });
}

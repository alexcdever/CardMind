import 'dart:io';

import '../../debug_pool.dart';

class DebugPoolRunner {
  DebugPoolRunner({required this.runner});

  final Runner runner;

  Future<int> run({
    required String owner,
    required String joiner,
    required String pin,
    required String? iosDeviceId,
    required bool keepRunning,
    required bool verbose,
    required void Function(String) log,
    required void Function(String) logError,
  }) async {
    log('debug pool orchestration is not implemented yet');
    return 0;
  }
}

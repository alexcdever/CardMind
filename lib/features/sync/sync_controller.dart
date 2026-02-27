import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/foundation.dart';

class SyncController extends ChangeNotifier {
  SyncController({
    required this.service,
    SyncStatus initial = const SyncStatus.idle(),
  }) : _status = initial;

  final SyncService service;
  SyncStatus _status;

  SyncStatus get status => _status;

  Future<void> connect(String target) async {
    _status = const SyncStatus.connecting();
    notifyListeners();
    _status = await service.connect(target);
    notifyListeners();
  }

  Future<void> retry() async {
    _status = const SyncStatus.connecting();
    notifyListeners();
    _status = await service.retry();
    notifyListeners();
  }

  Future<void> refresh() async {
    _status = await service.status();
    notifyListeners();
  }
}

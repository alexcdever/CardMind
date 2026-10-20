import 'dart:async';

import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';

import 'note_repository_stub.dart';

/// 设备页 / 列表页共享的内存 fake repository：记录配对与连通性调用轨迹。
class DevicesRepository extends NoteRepositoryStub
    implements ConnectivityRepository {
  List<PairedDeviceRow> pairedDevices = [];
  String deviceNameValue = 'My PC';
  String deviceIdValue = 'dev-1234567890';
  String acceptCodeValue = '123456';
  int acceptCodeCalls = 0;
  int credentialCalls = 0;
  int credentialConnectCalls = 0;
  int removeCalls = 0;
  final List<String> removedPeerIds = [];
  int connectCalls = 0;
  String? connectCode;
  PairingTarget? connectTarget;
  String connectPeerName = 'New Phone';

  /// 任务 J：mDNS 广播生命周期记录（显示码开启/关闭）。
  bool advertisingStarted = false;
  bool advertisingStopped = false;
  Future<int> Function(String peerId)? connectivityCheck;

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async =>
      List.of(pairedDevices);

  @override
  Future<String> deviceName() async => deviceNameValue;

  @override
  Future<String> deviceId() async => deviceIdValue;

  @override
  Future<String> beginPairingAccept() async {
    acceptCodeCalls++;
    return acceptCodeValue;
  }

  /// 组合 API（任务 J）：生成配对码并启动 mDNS 广播。
  @override
  Future<String> beginPairingAcceptAndAdvertise() async {
    acceptCodeCalls++;
    advertisingStarted = true;
    return acceptCodeValue;
  }

  @override
  Future<void> stopPairingAdvertising() async {
    advertisingStopped = true;
  }

  @override
  Future<List<PeerInfo>> discoverPeers() async => [];

  @override
  Future<int> checkDeviceConnectivity(String peerId) async =>
      connectivityCheck?.call(peerId) ?? 0;

  @override
  Future<void> removePairedDevice(String peerId) async {
    removeCalls++;
    removedPeerIds.add(peerId);
    pairedDevices.removeWhere((d) => d.peerId == peerId);
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    connectCalls++;
    connectCode = code;
    connectTarget = target;
    pairedDevices.add(
      PairedDeviceRow(
        peerId: target.deviceId,
        name: connectPeerName,
        lastSeen: DateTime.now().toIso8601String(),
        pairedAt: DateTime.now().toIso8601String(),
      ),
    );
    return PairingResult(peerId: target.deviceId, peerName: connectPeerName);
  }

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() async {
    credentialCalls++;
    return PairingCredentialDisplay(
      code: '289260',
      credential: 'cm1.credential-fake-text',
      expiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    );
  }

  @override
  Future<ParsedPairingCredential> parsePairingCredential(
    String credential,
  ) async {
    return ParsedPairingCredential(
      code: '289260',
      deviceId: 'parsed-device',
      expiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      nonce: '11111111111111111111111111111111',
      ips: const [],
    );
  }

  @override
  Future<PairingResult> beginPairingConnectWithCredential(
    String credential,
  ) async {
    credentialConnectCalls++;
    return PairingResult(peerId: 'parsed-device', peerName: 'Trusted PC');
  }

  /// 任务 M：有界接收——本 fake 不模拟接收（显示码弹窗仅展示码，不配对），
  /// 返回永不完成的 future，使现有显示码测试保持"等待中"状态。
  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(Duration timeout) =>
      Completer<PairingRequest?>().future;

  // ━━ NoteListPage 也使用本 fake（mobile FAB / sidebar 用例）━━

  @override
  Future<List<NoteRow>> listNotes() async => [];

  @override
  Future<List<NoteRow>> searchNotes(String query) async => [];

  @override
  Future<void> softDelete(String id) async {}

  // ━━ NoteListPage 内嵌/导航到的二级页面（editor / trash）━━

  @override
  Future<String?> getNote(String id) async => null;

  @override
  Future<void> createNote(String id, String content) async {}

  @override
  Future<String> generateNoteId() async => 'generated-id';

  @override
  Future<void> updateMetadata(String id, List<String> tags) async {}

  @override
  Future<List<LinkRow>> getBacklinks(String id) async => [];

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async => [];

  @override
  Future<void> restore(String id) async {}

  @override
  Future<void> purge(String id) async {}

  @override
  Future<List<NoteRow>> trashList() async => [];

  @override
  Future<List<String>> localAddrs() async => [];

  @override
  Future<void> setDeviceName(String name) async {}
}

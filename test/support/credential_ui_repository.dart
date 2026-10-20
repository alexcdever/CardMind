import 'dart:async';

import 'package:cardmind/bridge/pairing_credential_exception.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';

import 'note_repository_stub.dart';

/// 凭证 UI 专用 fake repository：记录配对 API 调用轨迹，可控模拟
/// 凭证生成、accept、confirm 行为（generation round token 语义）。
class CredentialUiRepository extends NoteRepositoryStub {
  int credentialCalls = 0;
  int acceptCalls = 0;
  int confirmCalls = 0;
  int discoverCalls = 0;
  int connectCalls = 0;
  int credentialConnectCalls = 0;
  int parseCalls = 0;
  int stopAdvertisingCalls = 0;

  String confirmCode = '';
  String? lastCredentialArg;

  /// credential 生成序列（每次 beginPairingCredential 取下一个；耗尽用最后一个）。
  List<PairingCredentialDisplay> credentialSeq = [
    PairingCredentialDisplay(
      code: '111111',
      credential: 'cm1.credential-first',
      expiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    ),
  ];

  /// accept 默认立即返回请求（generation 就绪后）。
  PairingRequest? acceptResult = const PairingRequest(
    code: '111111',
    deviceId: 'initiator-device',
    deviceName: 'New Phone',
    relayInfo: '',
    ips: [],
    nonce: '11111111111111111111111111111111',
  );

  /// accept 抛错（模拟后端异常）。每轮 accept 立即结束——用于需要
  /// 「重新生成」按钮快速完成的用例（旧 accept future 已结束，无需等待窗口）。
  Object? acceptError;

  /// 前 N 次 accept 返回 null（模拟有界窗口超时）。任务 U7：超时会触发
  /// 静默自动重生成链——测试时钟下必须"有限次 null + 挂起"收尾，
  /// 否则重生成链在纯 microtask 中无限旋转拖死 pumpAndSettle。
  int timeoutResults = 0;

  /// accept 挂起 gate（一次性：首个到达的 accept 消费后清除）。
  Completer<PairingRequest?>? acceptGate;

  /// timeoutResults/acceptGate 均未命中时挂起等待（模拟真实设备窗口内的
  /// 静默等待），保证弹窗保持打开且链路静止、测试可终止。
  bool parkAfterControlled = false;

  /// accept 挂起 gate（用于控制"凭证就绪前不启动 accept"）。
  Completer<void>? credentialGate;

  /// discoverPeers 返回结果。
  List<PeerInfo> peers = [];

  /// parsePairingCredential 抛错（模拟格式/签名/过期/已使用）。
  PairingCredentialException? parseError;

  /// credential connect 抛错（不可达）。
  Object? connectError;
  Completer<PairingResult>? credentialConnectGate;

  /// 设备列表刷新观测钩子（ui-polish-fix-3：断言取消不多余触发 _load）。
  void Function()? onListPairedDevices;

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() async {
    credentialCalls++;
    if (credentialGate case final gate?) await gate.future;
    final display = credentialSeq.length > 1
        ? credentialSeq.removeAt(0)
        : credentialSeq.last;
    return display;
  }

  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(
    Duration timeout,
  ) async {
    acceptCalls++;
    if (acceptError case final error?) throw error;
    if (timeoutResults > 0) {
      timeoutResults--;
      return null;
    }
    if (acceptGate case final gate?) {
      acceptGate = null; // 一次性消费：后续 accept 落到后续规则
      return gate.future;
    }
    if (parkAfterControlled) return Completer<PairingRequest?>().future;
    return acceptResult;
  }

  @override
  Future<PairingResult> confirmPairing(
    String code,
    PairingRequest requester,
  ) async {
    confirmCalls++;
    confirmCode = code;
    return PairingResult(
      peerId: requester.deviceId,
      peerName: requester.deviceName,
    );
  }

  @override
  Future<List<PeerInfo>> discoverPeers() async {
    discoverCalls++;
    return peers;
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    connectCalls++;
    return PairingResult(peerId: target.deviceId, peerName: 'Peer');
  }

  @override
  Future<ParsedPairingCredential> parsePairingCredential(
    String credential,
  ) async {
    parseCalls++;
    if (parseError case final e?) throw e;
    return ParsedPairingCredential(
      code: '111111',
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
    lastCredentialArg = credential;
    if (credentialConnectGate case final gate?) return gate.future;
    if (connectError case final e?) throw e;
    return PairingResult(peerId: 'parsed-device', peerName: 'Trusted PC');
  }

  @override
  Future<void> stopPairingAdvertising() async {
    stopAdvertisingCalls++;
  }

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async {
    onListPairedDevices?.call();
    return [];
  }

  @override
  Future<String> deviceName() async => 'My PC';
  @override
  Future<String> deviceId() async => 'confirmer-device';
  @override
  Future<String> beginPairingAccept() async => '111111';
  @override
  Future<String> beginPairingAcceptAndAdvertise() async => '111111';
  @override
  Future<PairingRequest> acceptPairingRequest() =>
      throw UnimplementedError('UI 走有界版本');
}

/// # 数据池 API 客户端
///
/// 定义数据池相关的 API 客户端抽象和实现。
/// 提供创建池、加入池、获取池信息等操作的接口。
///
/// ## 实现说明
/// - [LocalPoolApiClient] 提供本地模拟实现，用于开发和测试。
/// - [FrbPoolApiClient] 通过 FRB 调用 Rust 后端实现。
library pool_api_client;

import 'dart:async';

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';

class JoinRequestData {
  const JoinRequestData({
    required this.requestId,
    required this.displayName,
    required this.status,
  });

  final String requestId;
  final String displayName;
  final String status;
}

/// 创建池操作的结果数据。
class PoolCreateResult {
  /// 创建池结果。
  const PoolCreateResult({
    required this.poolId,
    required this.poolName,
    required this.isDissolved,
    required this.isOwner,
    required this.currentIdentityLabel,
    required this.memberLabels,
    this.inviteCode,
  });

  final String poolId;

  /// 池名称。
  final String poolName;

  final bool isDissolved;

  /// 当前用户是否为池所有者。
  final bool isOwner;

  /// 当前用户身份标识。
  final String currentIdentityLabel;

  /// 成员标识列表。
  final List<String> memberLabels;

  /// 可分享的邀请码字符串。当前运行态不可生成时为空。
  final String? inviteCode;
}

/// 池视图数据。
class PoolViewData {
  /// 创建池视图数据。
  const PoolViewData({
    required this.poolId,
    required this.poolName,
    required this.isDissolved,
    required this.isOwner,
    required this.currentIdentityLabel,
    required this.memberLabels,
    this.joinRequests = const <JoinRequestData>[],
  });

  final String poolId;

  /// 池名称。
  final String poolName;

  final bool isDissolved;

  /// 当前用户是否为池所有者。
  final bool isOwner;

  /// 当前用户身份标识。
  final String currentIdentityLabel;

  /// 成员标识列表。
  final List<String> memberLabels;

  final List<JoinRequestData> joinRequests;
}

/// 池详情数据。
class PoolDetailData {
  /// 创建池详情数据。
  const PoolDetailData({
    required this.poolId,
    required this.poolName,
    required this.isDissolved,
    required this.isOwner,
    required this.currentIdentityLabel,
    required this.memberLabels,
    this.joinRequests = const <JoinRequestData>[],
  });

  final String poolId;

  /// 池名称。
  final String poolName;

  final bool isDissolved;

  /// 当前用户是否为池所有者。
  final bool isOwner;

  /// 当前用户身份标识。
  final String currentIdentityLabel;

  /// 成员标识列表。
  final List<String> memberLabels;

  final List<JoinRequestData> joinRequests;
}

/// 加入池操作的结果。
class PoolJoinResult {
  /// 成功加入池的结果。
  const PoolJoinResult.joined({required this.poolName})
    : status = 'joined',
      poolId = null,
      requestId = null,
      applicantIdentityLabel = null,
      errorCode = null,
      errorMessage = null;

  /// 已提交加入申请、等待审批的结果。
  const PoolJoinResult.pending({
    required this.poolId,
    required this.poolName,
    required this.requestId,
    required this.applicantIdentityLabel,
  }) : status = 'pending',
       errorCode = null,
       errorMessage = null;

  /// 加入失败的结果。
  const PoolJoinResult.error(this.errorCode, {this.errorMessage})
    : status = 'error',
      poolId = null,
      poolName = null,
      requestId = null,
      applicantIdentityLabel = null;

  final String status;

  final String? poolId;

  /// 池名称，仅在成功时有效。
  final String? poolName;

  final String? requestId;

  final String? applicantIdentityLabel;

  /// 错误码，仅在失败时有效。
  final String? errorCode;

  /// 错误消息，仅在失败时有效。
  final String? errorMessage;

  /// 是否成功加入。
  bool get isSuccess => errorCode == null;

  bool get isJoined => status == 'joined';

  bool get isPending => status == 'pending';
}

/// 数据池 API 客户端抽象接口。
abstract class PoolApiClient {
  /// 创建新的数据池。
  Future<PoolCreateResult> createPool();

  /// 通过加入码加入数据池。
  Future<PoolJoinResult> joinByCode(String code);

  /// 获取已加入的池视图信息。
  Future<PoolViewData?> getJoinedPoolView();

  /// 获取指定池的详细信息。
  Future<PoolDetailData> getPoolDetail(String poolId);

  /// 退出指定数据池。
  Future<void> leavePool(String poolId);

  /// 解散指定数据池。
  Future<PoolDetailData> dissolvePool(String poolId);

  Future<List<JoinRequestData>> submitJoinRequest(String poolId);

  Future<List<JoinRequestData>> approveJoinRequest(
    String poolId,
    String requestId,
  );

  Future<List<JoinRequestData>> rejectJoinRequest(
    String poolId,
    String requestId,
  );

  Future<List<JoinRequestData>> cancelJoinRequest(
    String poolId,
    String requestId,
  );
}

/// 本地模拟实现的数据池 API 客户端。
///
/// 用于开发和测试环境，提供固定的模拟数据响应。
class LocalPoolApiClient implements PoolApiClient {
  /// 所有者池的默认名称。
  static const String ownerPoolName = '我的数据池';

  @override
  Future<PoolCreateResult> createPool() async {
    return const PoolCreateResult(
      poolId: 'local-pool',
      poolName: ownerPoolName,
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@local',
      memberLabels: <String>['owner@local'],
      inviteCode: 'local-pool',
    );
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'ok') {
      return const PoolJoinResult.joined(poolName: ownerPoolName);
    }
    if (code == 'pending') {
      return const PoolJoinResult.pending(
        poolId: 'pending-request-pool',
        poolName: ownerPoolName,
        requestId: 'pending-request',
        applicantIdentityLabel: 'owner@local',
      );
    }
    return PoolJoinResult.error(
      code == 'admin-offline' ? 'ADMIN_OFFLINE' : 'REQUEST_TIMEOUT',
    );
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    return const PoolViewData(
      poolId: 'local-pool',
      poolName: ownerPoolName,
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@local',
      memberLabels: <String>['owner@local'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async {
    return const PoolDetailData(
      poolId: 'local-pool',
      poolName: ownerPoolName,
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@local',
      memberLabels: <String>['owner@local'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<void> leavePool(String poolId) async {}

  @override
  Future<PoolDetailData> dissolvePool(String poolId) async {
    return const PoolDetailData(
      poolId: 'local-pool',
      poolName: ownerPoolName,
      isDissolved: true,
      isOwner: true,
      currentIdentityLabel: 'owner@local',
      memberLabels: <String>['owner@local'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<List<JoinRequestData>> submitJoinRequest(String poolId) async =>
      const <JoinRequestData>[];

  @override
  Future<List<JoinRequestData>> approveJoinRequest(
    String poolId,
    String requestId,
  ) async => const <JoinRequestData>[];

  @override
  Future<List<JoinRequestData>> rejectJoinRequest(
    String poolId,
    String requestId,
  ) async => const <JoinRequestData>[];

  @override
  Future<List<JoinRequestData>> cancelJoinRequest(
    String poolId,
    String requestId,
  ) async => const <JoinRequestData>[];
}

/// 基于 FRB 的数据池 API 客户端实现。
///
/// 通过 Flutter Rust Bridge 调用 Rust 后端实现真实的业务逻辑。
class FrbPoolApiClient implements PoolApiClient {
  /// 创建 FRB 池 API 客户端。
  FrbPoolApiClient({
    required this.nickname,
    required this.os,
    this.endpointId,
    this.appDataDir,
    this.networkId,
    this.debugJoinTrace = false,
    this.debugLogSink,
  });

  /// 端点标识。
  final String? endpointId;

  /// 用户昵称。
  final String nickname;

  /// 操作系统名称。
  final String os;

  /// 应用数据目录。未显式注入 network handle 时，用它懒加载本机运行态网络。
  final String? appDataDir;

  /// 运行态网络实例 ID。存在时优先走真实邀请串入池链路。
  final BigInt? networkId;
  final bool debugJoinTrace;
  final void Function(String line)? debugLogSink;
  BigInt? _cachedRuntimeNetworkId;
  String? _cachedRuntimeEndpointId;

  Future<BigInt?> _ensureNetworkId() async {
    final direct = networkId;
    if (direct != null) {
      return direct;
    }
    final cached = _cachedRuntimeNetworkId;
    if (cached != null) {
      return cached;
    }
    final basePath = appDataDir?.trim();
    if (basePath == null || basePath.isEmpty) {
      return null;
    }
    final resolved = await frb.initPoolNetwork(basePath: basePath);
    _cachedRuntimeNetworkId = resolved;
    return resolved;
  }

  Future<String> _effectiveEndpointId() async {
    final direct = endpointId?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final cached = _cachedRuntimeEndpointId?.trim();
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final resolvedNetworkId = await _ensureNetworkId();
    if (resolvedNetworkId == null) {
      throw StateError('pool runtime requires endpointId or appDataDir');
    }
    final resolved = await frb.getPoolNetworkEndpointId(
      networkId: resolvedNetworkId,
    );
    _cachedRuntimeEndpointId = resolved;
    return resolved;
  }

  String _identityLabelFromMembers(
    List<frb.PoolMemberDto> members,
    String currentEndpointId,
  ) {
    for (final member in members) {
      if (member.endpointId == currentEndpointId) {
        return member.endpointId;
      }
    }
    return currentEndpointId;
  }

  List<String> _memberLabels(List<frb.PoolMemberDto> members) {
    return members.map((member) => member.endpointId).toList(growable: false);
  }

  List<JoinRequestData> _joinRequests(List<frb.JoinRequestDto> requests) {
    return requests
        .map(
          (request) => JoinRequestData(
            requestId: request.requestId,
            displayName: request.applicantEndpointId,
            status: request.status,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PoolCreateResult> createPool() async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final runtimeNetworkId = await _ensureNetworkId();
    final dto = await frb.createPool(
      endpointId: effectiveEndpointId,
      nickname: nickname,
      os: os,
    );
    final detail = await frb.getPoolDetail(
      poolId: dto.id,
      endpointId: effectiveEndpointId,
    );
    final inviteCode = runtimeNetworkId == null
        ? null
        : await frb.createPoolInvite(
            networkId: runtimeNetworkId,
            poolId: dto.id,
          );
    return PoolCreateResult(
      poolId: dto.id,
      poolName: dto.name,
      isDissolved: dto.isDissolved,
      isOwner: dto.currentUserRole == 'admin',
      currentIdentityLabel: _identityLabelFromMembers(
        detail.members,
        effectiveEndpointId,
      ),
      memberLabels: _memberLabels(detail.members),
      inviteCode: inviteCode,
    );
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    try {
      final trimmed = code.trim();
      final runtimeNetworkId = await _ensureNetworkId();
      if (runtimeNetworkId != null && !_looksLikeUuid(trimmed)) {
        final dto = await frb.joinPoolByInvite(
          networkId: runtimeNetworkId,
          code: trimmed,
          nickname: nickname,
          os: os,
          debugTrace: debugJoinTrace,
        );
        if (dto.status == 'pending') {
          return PoolJoinResult.pending(
            poolId: dto.poolId,
            poolName: dto.poolName,
            requestId: dto.requestId ?? 'pending-request',
            applicantIdentityLabel: await _effectiveEndpointId(),
          );
        }
        return PoolJoinResult.joined(poolName: dto.poolName);
      }
      final dto = await frb.joinByCode(
        code: trimmed,
        endpointId: await _effectiveEndpointId(),
        nickname: nickname,
        os: os,
      );
      return PoolJoinResult.joined(poolName: dto.name);
    } on ApiError catch (error) {
      if (debugJoinTrace) {
        _emitJoinTrace(error.message);
      }
      return PoolJoinResult.error(error.code, errorMessage: error.message);
    }
  }

  void _emitJoinTrace(String message) {
    final sink = debugLogSink;
    for (final rawLine in message.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('pool_debug.join.')) {
        continue;
      }
      if (sink != null) {
        sink(line);
      } else {
        Zone.root.run(() => print(line));
      }
    }
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final dto = await frb.getJoinedPoolView(endpointId: effectiveEndpointId);
    if (dto.id.isEmpty) {
      return null;
    }
    return PoolViewData(
      poolId: dto.id,
      poolName: dto.name,
      isDissolved: dto.isDissolved,
      isOwner: dto.currentUserRole == 'admin',
      currentIdentityLabel: _identityLabelFromMembers(
        dto.members,
        effectiveEndpointId,
      ),
      memberLabels: _memberLabels(dto.members),
      joinRequests: _joinRequests(dto.joinRequests),
    );
  }

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final dto = await frb.getPoolDetail(
      poolId: poolId,
      endpointId: effectiveEndpointId,
    );
    return PoolDetailData(
      poolId: dto.id,
      poolName: dto.name,
      isDissolved: dto.isDissolved,
      isOwner: dto.currentUserRole == 'admin',
      currentIdentityLabel: _identityLabelFromMembers(
        dto.members,
        effectiveEndpointId,
      ),
      memberLabels: _memberLabels(dto.members),
      joinRequests: _joinRequests(dto.joinRequests),
    );
  }

  @override
  Future<void> leavePool(String poolId) async {
    await frb.leavePool(
      poolId: poolId,
      endpointId: await _effectiveEndpointId(),
    );
  }

  @override
  Future<PoolDetailData> dissolvePool(String poolId) async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final dto = await frb.dissolvePool(
      poolId: poolId,
      endpointId: effectiveEndpointId,
    );
    final detail = await frb.getPoolDetail(
      poolId: dto.id,
      endpointId: effectiveEndpointId,
    );
    return PoolDetailData(
      poolId: dto.id,
      poolName: dto.name,
      isDissolved: dto.isDissolved,
      isOwner: dto.currentUserRole == 'admin',
      currentIdentityLabel: _identityLabelFromMembers(
        detail.members,
        effectiveEndpointId,
      ),
      memberLabels: _memberLabels(detail.members),
      joinRequests: _joinRequests(detail.joinRequests),
    );
  }

  @override
  Future<List<JoinRequestData>> submitJoinRequest(String poolId) async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final requests = await frb.submitJoinRequest(
      poolId: poolId,
      endpointId: effectiveEndpointId,
      nickname: nickname,
      os: os,
    );
    return _joinRequests(requests);
  }

  @override
  Future<List<JoinRequestData>> approveJoinRequest(
    String poolId,
    String requestId,
  ) async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final requests = await frb.approveJoinRequest(
      poolId: poolId,
      requestId: requestId,
      approverEndpointId: effectiveEndpointId,
    );
    return _joinRequests(requests);
  }

  @override
  Future<List<JoinRequestData>> rejectJoinRequest(
    String poolId,
    String requestId,
  ) async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final requests = await frb.rejectJoinRequest(
      poolId: poolId,
      requestId: requestId,
      approverEndpointId: effectiveEndpointId,
    );
    return _joinRequests(requests);
  }

  @override
  Future<List<JoinRequestData>> cancelJoinRequest(
    String poolId,
    String requestId,
  ) async {
    final effectiveEndpointId = await _effectiveEndpointId();
    final requests = await frb.cancelJoinRequest(
      poolId: poolId,
      requestId: requestId,
      applicantEndpointId: effectiveEndpointId,
    );
    return _joinRequests(requests);
  }

  bool _looksLikeUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value);
  }
}

// input: 接收创建池与加入池动作参数，并按客户端实现路由到后端或本地兼容流程。
// output: 提供数据池用例 ApiClient 抽象与默认本地实现。
// pos: 池后端调用客户端，负责收敛 Flutter 到 Rust 的动作入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件定义池 ApiClient，并保留短期本地兼容实现。
import 'dart:async';

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';

class PoolCreateResult {
  const PoolCreateResult({
    required this.poolName,
    required this.isOwner,
    required this.currentIdentityLabel,
    required this.memberLabels,
  });

  final String poolName;
  final bool isOwner;
  final String currentIdentityLabel;
  final List<String> memberLabels;
}

class PoolViewData {
  const PoolViewData({
    required this.poolName,
    required this.isOwner,
    required this.currentIdentityLabel,
    required this.memberLabels,
  });

  final String poolName;
  final bool isOwner;
  final String currentIdentityLabel;
  final List<String> memberLabels;
}

class PoolDetailData {
  const PoolDetailData({
    required this.poolName,
    required this.isOwner,
    required this.currentIdentityLabel,
    required this.memberLabels,
  });

  final String poolName;
  final bool isOwner;
  final String currentIdentityLabel;
  final List<String> memberLabels;
}

class PoolJoinResult {
  const PoolJoinResult.joined({required this.poolName}) : errorCode = null;

  const PoolJoinResult.error(this.errorCode) : poolName = null;

  final String? poolName;
  final String? errorCode;

  bool get isSuccess => errorCode == null;
}

abstract class PoolApiClient {
  Future<PoolCreateResult> createPool();

  Future<PoolJoinResult> joinByCode(String code);

  Future<PoolViewData?> getJoinedPoolView();

  Future<PoolDetailData> getPoolDetail(String poolId);
}

class LocalPoolApiClient implements PoolApiClient {
  static const String ownerPoolName = '我的数据池';

  @override
  Future<PoolCreateResult> createPool() async {
    return const PoolCreateResult(
      poolName: ownerPoolName,
      isOwner: true,
      currentIdentityLabel: 'owner@local',
      memberLabels: <String>['owner@local'],
    );
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'ok') {
      return const PoolJoinResult.joined(poolName: ownerPoolName);
    }
    return PoolJoinResult.error(
      code == 'admin-offline' ? 'ADMIN_OFFLINE' : 'REQUEST_TIMEOUT',
    );
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    return const PoolViewData(
      poolName: ownerPoolName,
      isOwner: true,
      currentIdentityLabel: 'owner@local',
      memberLabels: <String>['owner@local'],
    );
  }

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async {
    return const PoolDetailData(
      poolName: ownerPoolName,
      isOwner: true,
      currentIdentityLabel: 'owner@local',
      memberLabels: <String>['owner@local'],
    );
  }
}

class FrbPoolApiClient implements PoolApiClient {
  FrbPoolApiClient({
    required this.endpointId,
    required this.nickname,
    required this.os,
  });

  final String endpointId;
  final String nickname;
  final String os;

  String _identityLabelFromMembers(List<frb.PoolMemberDto> members) {
    for (final member in members) {
      if (member.endpointId == endpointId) {
        return member.endpointId;
      }
    }
    return endpointId;
  }

  List<String> _memberLabels(List<frb.PoolMemberDto> members) {
    return members.map((member) => member.endpointId).toList(growable: false);
  }

  @override
  Future<PoolCreateResult> createPool() async {
    final dto = await frb.createPool(
      endpointId: endpointId,
      nickname: nickname,
      os: os,
    );
    final detail = await frb.getPoolDetail(
      poolId: dto.id,
      endpointId: endpointId,
    );
    return PoolCreateResult(
      poolName: dto.name,
      isOwner: dto.currentUserRole == 'admin',
      currentIdentityLabel: _identityLabelFromMembers(detail.members),
      memberLabels: _memberLabels(detail.members),
    );
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    try {
      final dto = await frb.joinByCode(
        code: code,
        endpointId: endpointId,
        nickname: nickname,
        os: os,
      );
      return PoolJoinResult.joined(poolName: dto.name);
    } on ApiError catch (error) {
      return PoolJoinResult.error(error.code);
    }
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    final dto = await frb.getJoinedPoolView(endpointId: endpointId);
    if (dto.id.isEmpty) {
      return null;
    }
    return PoolViewData(
      poolName: dto.name,
      isOwner: dto.currentUserRole == 'admin',
      currentIdentityLabel: _identityLabelFromMembers(dto.members),
      memberLabels: _memberLabels(dto.members),
    );
  }

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async {
    final dto = await frb.getPoolDetail(poolId: poolId, endpointId: endpointId);
    return PoolDetailData(
      poolName: dto.name,
      isOwner: dto.currentUserRole == 'admin',
      currentIdentityLabel: _identityLabelFromMembers(dto.members),
      memberLabels: _memberLabels(dto.members),
    );
  }
}

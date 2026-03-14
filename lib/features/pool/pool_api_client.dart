// input: 接收创建池与加入池动作参数，并按客户端实现路由到后端或本地兼容流程。
// output: 提供数据池用例 ApiClient 抽象与默认本地实现。
// pos: 池后端调用客户端，负责收敛 Flutter 到 Rust 的动作入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件定义池 ApiClient，并保留短期本地兼容实现。
import 'dart:async';

import 'package:cardmind/bridge_generated/api.dart' as frb;

class PoolCreateResult {
  const PoolCreateResult({required this.poolName, required this.isOwner});

  final String poolName;
  final bool isOwner;
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
}

class LocalPoolApiClient implements PoolApiClient {
  static const String ownerPoolName = '我的数据池';

  @override
  Future<PoolCreateResult> createPool() async {
    return const PoolCreateResult(poolName: ownerPoolName, isOwner: true);
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

  @override
  Future<PoolCreateResult> createPool() async {
    final dto = await frb.createPool(
      endpointId: endpointId,
      nickname: nickname,
      os: os,
    );
    return PoolCreateResult(
      poolName: dto.name,
      isOwner: dto.currentUserRole == 'admin',
    );
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) {
    throw UnimplementedError('FRB joinByCode mapping is not available yet');
  }
}

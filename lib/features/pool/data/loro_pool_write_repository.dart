// input: 接收池、成员与请求写模型操作并按 poolId 聚合管理。
// output: 提供池写侧 upsert/list/remove 实现，作为 Loro 写模型真源仓。
// pos: 池 Loro 写仓实现，负责维护池生命周期相关写模型状态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'dart:convert';
import 'dart:typed_data';

import 'package:cardmind/features/pool/data/pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';
import 'package:cardmind/features/shared/storage/loro_doc_path.dart';
import 'package:cardmind/features/shared/storage/loro_doc_store.dart';

class LoroPoolWriteRepository implements PoolWriteRepository {
  LoroPoolWriteRepository({
    this.basePath = 'data/loro',
    this.persistToFile = true,
  });

  factory LoroPoolWriteRepository.inMemory() {
    return LoroPoolWriteRepository(persistToFile: false);
  }

  final String basePath;
  final bool persistToFile;
  final Map<String, _PoolAggregate> _aggregates = <String, _PoolAggregate>{};

  @override
  Future<PoolEntity?> getPoolById(String poolId) async {
    final aggregate = await _loadAggregate(poolId);
    return aggregate.pool;
  }

  @override
  Future<List<PoolMember>> listMembers(String poolId) async {
    final aggregate = await _loadAggregate(poolId);
    return aggregate.members.values.toList(growable: false);
  }

  @override
  Future<List<PoolRequest>> listRequests(String poolId) async {
    final aggregate = await _loadAggregate(poolId);
    return aggregate.requests.values.toList(growable: false);
  }

  @override
  Future<void> removeMember(String poolId, String memberId) async {
    final aggregate = await _loadAggregate(poolId);
    final nextMembers = Map<String, PoolMember>.from(aggregate.members)
      ..remove(memberId);
    await _saveAggregate(poolId, aggregate.copyWith(members: nextMembers));
  }

  @override
  Future<void> removeRequest(String poolId, String requestId) async {
    final aggregate = await _loadAggregate(poolId);
    final nextRequests = Map<String, PoolRequest>.from(aggregate.requests)
      ..remove(requestId);
    await _saveAggregate(poolId, aggregate.copyWith(requests: nextRequests));
  }

  @override
  Future<void> upsertMember(PoolMember member) async {
    final aggregate = await _loadAggregate(member.poolId);
    final nextMembers = Map<String, PoolMember>.from(aggregate.members)
      ..[member.memberId] = member;
    await _saveAggregate(
      member.poolId,
      aggregate.copyWith(members: nextMembers),
    );
  }

  @override
  Future<void> upsertPool(PoolEntity pool) async {
    final aggregate = await _loadAggregate(pool.poolId);
    await _saveAggregate(pool.poolId, aggregate.copyWith(pool: pool));
  }

  @override
  Future<void> upsertRequest(PoolRequest request) async {
    final aggregate = await _loadAggregate(request.poolId);
    final nextRequests = Map<String, PoolRequest>.from(aggregate.requests)
      ..[request.requestId] = request;
    await _saveAggregate(
      request.poolId,
      aggregate.copyWith(requests: nextRequests),
    );
  }

  Future<_PoolAggregate> _loadAggregate(String poolId) async {
    final cached = _aggregates[poolId];
    if (cached != null || !persistToFile) {
      return cached ?? const _PoolAggregate();
    }

    final paths = _poolPaths(poolId);
    if (!paths.snapshot.existsSync() && !paths.update.existsSync()) {
      return const _PoolAggregate();
    }

    final bytes = await LoroDocStore(paths).load();
    final aggregate = _decodeLatest(bytes) ?? const _PoolAggregate();
    _aggregates[poolId] = aggregate;
    return aggregate;
  }

  Future<void> _saveAggregate(String poolId, _PoolAggregate aggregate) async {
    if (persistToFile) {
      final paths = _poolPaths(poolId);
      final store = LoroDocStore(paths);
      await store.ensureCreated();
      final encoded = _encodeAggregate(aggregate);
      if (paths.snapshot.lengthSync() == 0) {
        await paths.snapshot.writeAsBytes(encoded, flush: true);
      } else {
        await store.appendUpdate(encoded);
      }
    }

    _aggregates[poolId] = aggregate;
  }

  LoroDocPath _poolPaths(String poolId) {
    return LoroDocPath.forEntity(
      kind: 'pool-meta',
      id: poolId,
      basePath: basePath,
    );
  }

  Uint8List _encodeAggregate(_PoolAggregate aggregate) {
    final payload = jsonEncode(aggregate.toJson());
    return Uint8List.fromList(utf8.encode('$payload\n'));
  }

  _PoolAggregate? _decodeLatest(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final lines = utf8
        .decode(bytes, allowMalformed: false)
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }
    final json = jsonDecode(lines.last) as Map<String, dynamic>;
    return _PoolAggregate.fromJson(json);
  }
}

class _PoolAggregate {
  const _PoolAggregate({
    this.pool,
    this.members = const <String, PoolMember>{},
    this.requests = const <String, PoolRequest>{},
  });

  final PoolEntity? pool;
  final Map<String, PoolMember> members;
  final Map<String, PoolRequest> requests;

  _PoolAggregate copyWith({
    PoolEntity? pool,
    Map<String, PoolMember>? members,
    Map<String, PoolRequest>? requests,
  }) {
    return _PoolAggregate(
      pool: pool ?? this.pool,
      members: members ?? this.members,
      requests: requests ?? this.requests,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'pool': pool == null
          ? null
          : <String, Object?>{
              'poolId': pool!.poolId,
              'name': pool!.name,
              'dissolved': pool!.dissolved,
              'updatedAtMicros': pool!.updatedAtMicros,
            },
      'members': members.values
          .map(
            (member) => <String, Object?>{
              'poolId': member.poolId,
              'memberId': member.memberId,
              'displayName': member.displayName,
              'role': member.role.name,
              'joinedAtMicros': member.joinedAtMicros,
            },
          )
          .toList(growable: false),
      'requests': requests.values
          .map(
            (request) => <String, Object?>{
              'requestId': request.requestId,
              'poolId': request.poolId,
              'requesterId': request.requesterId,
              'displayName': request.displayName,
              'requestedAtMicros': request.requestedAtMicros,
            },
          )
          .toList(growable: false),
    };
  }

  factory _PoolAggregate.fromJson(Map<String, dynamic> json) {
    final poolJson = json['pool'] as Map<String, dynamic>?;
    final pool = poolJson == null
        ? null
        : PoolEntity(
            poolId: poolJson['poolId'] as String,
            name: poolJson['name'] as String,
            dissolved: poolJson['dissolved'] as bool,
            updatedAtMicros: poolJson['updatedAtMicros'] as int,
          );

    final membersJson = (json['members'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final members = <String, PoolMember>{
      for (final item in membersJson)
        item['memberId'] as String: PoolMember(
          poolId: item['poolId'] as String,
          memberId: item['memberId'] as String,
          displayName: item['displayName'] as String,
          role: item['role'] == PoolRole.owner.name
              ? PoolRole.owner
              : PoolRole.member,
          joinedAtMicros: item['joinedAtMicros'] as int,
        ),
    };

    final requestsJson =
        (json['requests'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    final requests = <String, PoolRequest>{
      for (final item in requestsJson)
        item['requestId'] as String: PoolRequest(
          requestId: item['requestId'] as String,
          poolId: item['poolId'] as String,
          requesterId: item['requesterId'] as String,
          displayName: item['displayName'] as String,
          requestedAtMicros: item['requestedAtMicros'] as int,
        ),
    };

    return _PoolAggregate(pool: pool, members: members, requests: requests);
  }
}

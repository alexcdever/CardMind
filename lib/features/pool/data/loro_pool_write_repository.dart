/// # Loro 池写模型仓储实现
///
/// 基于 Loro 实现池写模型的持久化存储。
/// 提供池、成员、请求的读写与删除能力，作为 Loro 写模型真源仓。
///
/// ## 外部依赖
/// - 依赖 [PoolWriteRepository] 接口定义。
/// - 依赖 [PoolEntity] 定义池实体数据结构。
/// - 依赖 [PoolMember] 定义成员数据结构。
/// - 依赖 [PoolRequest] 定义请求数据结构。
/// - 依赖 [LoroDocPath] 提供文件路径管理。
/// - 依赖 [LoroDocStore] 提供 Loro 文档存储操作。
library loro_pool_write_repository;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cardmind/features/pool/data/pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';
import 'package:cardmind/features/shared/storage/loro_doc_path.dart';
import 'package:cardmind/features/shared/storage/loro_doc_store.dart';

/// Loro 实现的池写模型仓储。
///
/// 负责维护池生命周期相关的写模型状态，支持文件持久化与内存模式。
/// 每个池的所有数据（池本身、成员、请求）以聚合文档形式存储。
class LoroPoolWriteRepository implements PoolWriteRepository {
  /// 创建仓储实例。
  ///
  /// [basePath] 为 Loro 数据存储的根目录，默认为 'data/loro'。
  /// [persistToFile] 控制是否持久化到文件，默认为 true。
  LoroPoolWriteRepository({
    this.basePath = 'data/loro',
    this.persistToFile = true,
  });

  /// 创建内存模式仓储实例。
  ///
  /// 不持久化到文件，数据仅保存在内存中，适用于测试场景。
  factory LoroPoolWriteRepository.inMemory() {
    return LoroPoolWriteRepository(persistToFile: false);
  }

  /// Loro 数据存储的根目录。
  final String basePath;

  /// 是否持久化到文件。
  final bool persistToFile;

  /// 内存缓存，按池 ID 索引聚合数据。
  final Map<String, _PoolAggregate> _aggregates = <String, _PoolAggregate>{};

  /// 根据 ID 查询池。
  ///
  /// [poolId] 为池的唯一标识符。
  /// 返回匹配的 [PoolEntity]，若不存在则返回 null。
  @override
  Future<PoolEntity?> getPoolById(String poolId) async {
    final aggregate = await _loadAggregate(poolId);
    return aggregate.pool;
  }

  /// 查询池的成员列表。
  ///
  /// [poolId] 为池的唯一标识符。
  /// 返回该池下的所有成员列表。
  @override
  Future<List<PoolMember>> listMembers(String poolId) async {
    final aggregate = await _loadAggregate(poolId);
    return aggregate.members.values.toList(growable: false);
  }

  /// 查询池的请求列表。
  ///
  /// [poolId] 为池的唯一标识符。
  /// 返回该池下的所有加入请求列表。
  @override
  Future<List<PoolRequest>> listRequests(String poolId) async {
    final aggregate = await _loadAggregate(poolId);
    return aggregate.requests.values.toList(growable: false);
  }

  /// 移除成员。
  ///
  /// [poolId] 为池的唯一标识符。
  /// [memberId] 为成员的唯一标识符。
  @override
  Future<void> removeMember(String poolId, String memberId) async {
    final aggregate = await _loadAggregate(poolId);
    final nextMembers = Map<String, PoolMember>.from(aggregate.members)
      ..remove(memberId);
    await _saveAggregate(poolId, aggregate.copyWith(members: nextMembers));
  }

  /// 移除请求。
  ///
  /// [poolId] 为池的唯一标识符。
  /// [requestId] 为请求的唯一标识符。
  @override
  Future<void> removeRequest(String poolId, String requestId) async {
    final aggregate = await _loadAggregate(poolId);
    final nextRequests = Map<String, PoolRequest>.from(aggregate.requests)
      ..remove(requestId);
    await _saveAggregate(poolId, aggregate.copyWith(requests: nextRequests));
  }

  /// 插入或更新成员。
  ///
  /// [member] 为要写入的成员数据。
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

  /// 插入或更新池。
  ///
  /// [pool] 为要写入的池实体数据。
  @override
  Future<void> upsertPool(PoolEntity pool) async {
    final aggregate = await _loadAggregate(pool.poolId);
    await _saveAggregate(pool.poolId, aggregate.copyWith(pool: pool));
  }

  /// 插入或更新请求。
  ///
  /// [request] 为要写入的请求数据。
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

  /// 加载指定池的聚合数据。
  ///
  /// 优先从内存缓存获取，若未命中且启用持久化则从文件加载。
  /// [poolId] 为池的唯一标识符。
  /// 返回池的聚合数据，若不存在则返回空聚合。
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

  /// 保存池的聚合数据。
  ///
  /// 若启用持久化则写入文件，同时更新内存缓存。
  /// [poolId] 为池的唯一标识符。
  /// [aggregate] 为要保存的聚合数据。
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

  /// 获取池的 Loro 文档路径。
  ///
  /// [poolId] 为池的唯一标识符。
  /// 返回配置好的 [LoroDocPath] 实例。
  LoroDocPath _poolPaths(String poolId) {
    return LoroDocPath.forEntity(
      kind: 'pool-meta',
      id: poolId,
      basePath: basePath,
    );
  }

  /// 将聚合数据编码为字节数组。
  ///
  /// [aggregate] 为要编码的池聚合数据。
  /// 返回 JSON 格式的 UTF-8 编码字节数组。
  Uint8List _encodeAggregate(_PoolAggregate aggregate) {
    final payload = jsonEncode(aggregate.toJson());
    return Uint8List.fromList(utf8.encode('$payload\n'));
  }

  /// 从字节数组解码最新的聚合数据。
  ///
  /// [bytes] 为 Loro 存储的原始字节数据。
  /// 解析最后一行非空记录作为最新版本。
  /// 返回解码后的 [_PoolAggregate]，若数据为空或无效则返回 null。
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

/// 池聚合数据内部类。
///
/// 将池实体、成员映射、请求映射聚合在一起存储。
class _PoolAggregate {
  /// 创建聚合实例。
  ///
  /// [pool] 为可选的池实体。
  /// [members] 为成员 ID 到成员的映射，默认为空。
  /// [requests] 为请求 ID 到请求的映射，默认为空。
  const _PoolAggregate({
    this.pool,
    this.members = const <String, PoolMember>{},
    this.requests = const <String, PoolRequest>{},
  });

  /// 池实体数据，可能为 null（新建池时）。
  final PoolEntity? pool;

  /// 成员映射表，键为成员 ID。
  final Map<String, PoolMember> members;

  /// 请求映射表，键为请求 ID。
  final Map<String, PoolRequest> requests;

  /// 创建新的聚合实例，可选择性覆盖字段。
  ///
  /// [pool] 为新的池实体，为 null 则保留原值。
  /// [members] 为新的成员映射，为 null 则保留原值。
  /// [requests] 为新的请求映射，为 null 则保留原值。
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

  /// 将聚合数据序列化为 JSON 对象。
  ///
  /// 返回包含池、成员列表、请求列表的映射。
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

  /// 从 JSON 对象反序列化聚合数据。
  ///
  /// [json] 为包含池、成员列表、请求列表的映射。
  /// 返回解析后的 [_PoolAggregate] 实例。
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

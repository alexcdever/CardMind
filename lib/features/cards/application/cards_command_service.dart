/// # 卡片命令服务
///
/// 提供创建、更新、删除、恢复卡片的命令服务。
/// 接收 create/update/delete/restore 卡片命令参数并调用写仓，
/// 在 Loro 写侧创建或更新 [CardNote]，维护 deleted 与更新时间语义。
///
/// ⚠️ 仅保留给旧测试与迁移过渡使用；主页面流不得再直接依赖它。
/// 待 Flutter 主流程完全切换到 Rust 后端后删除。
///
/// ## 外部依赖
/// - 依赖 [CardsWriteRepository] 执行写侧数据持久化。
/// - 依赖 [CardNote] 领域实体。
library cards_command_service;

import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';

/// 卡片命令服务。
///
/// ⚠️ 临时兼容服务，提供对卡片的 CRUD 操作。
/// 仅用于旧测试和迁移过渡，新项目应使用 Rust 后端 API。
class CardsCommandService {
  /// 创建卡片命令服务实例。
  ///
  /// [writeRepository] 卡片写仓库，用于执行写操作。
  CardsCommandService(this._writeRepository);

  /// 卡片写仓库实例。
  final CardsWriteRepository _writeRepository;

  /// 创建新卡片笔记。
  ///
  /// [id] 卡片唯一标识符。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  ///
  /// 返回异步操作结果，创建时自动设置 [deleted] 为 false 并记录当前时间。
  Future<void> createNote(String id, String title, String body) {
    return _writeRepository.upsert(
      CardNote(
        id: id,
        title: title,
        body: body,
        deleted: false,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  /// 更新现有卡片笔记。
  ///
  /// [id] 要更新的卡片标识符。
  /// [title] 新的卡片标题。
  /// [body] 新的卡片内容。
  ///
  /// 如果卡片不存在则不执行任何操作。
  /// 更新时自动刷新 [updatedAtMicros] 为当前时间。
  Future<void> updateNote(String id, String title, String body) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsert(
      existing.copyWith(
        title: title,
        body: body,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  /// 软删除卡片笔记。
  ///
  /// [id] 要删除的卡片标识符。
  ///
  /// 如果卡片不存在则不执行任何操作。
  /// 删除操作通过设置 [deleted] 为 true 实现，不会物理删除数据。
  Future<void> deleteNote(String id) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsert(
      existing.copyWith(deleted: true, updatedAtMicros: _nowMicros()),
    );
  }

  /// 恢复已删除的卡片笔记。
  ///
  /// [id] 要恢复的卡片标识符。
  ///
  /// 如果卡片不存在则不执行任何操作。
  /// 恢复操作通过设置 [deleted] 为 false 实现。
  Future<void> restoreNote(String id) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsert(
      existing.copyWith(deleted: false, updatedAtMicros: _nowMicros()),
    );
  }

  /// 获取当前时间的微秒级时间戳。
  ///
  /// 返回自 Unix 纪元以来的微秒数。
  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}

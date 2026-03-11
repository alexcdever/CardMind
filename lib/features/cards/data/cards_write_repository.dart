// input: 接收卡片写模型读取与写入参数（id、标题、内容、删除标记等）。
// output: 定义旧 Loro 写侧仓接口，提供卡片 upsert 与按 id 查询能力。
// pos: 卡片写模型仓储抽象，当前仅保留给测试与短期兼容路径使用；主页面流不得再直接依赖它。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：临时兼容接口，待 Flutter 主流程完全切换到 Rust 后端后删除。
import 'package:cardmind/features/cards/domain/card_note.dart';

abstract class CardsWriteRepository {
  Future<void> upsert(CardNote note);

  Future<CardNote?> getById(String id);
}

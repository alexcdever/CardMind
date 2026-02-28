// input: 接收卡片写模型读取与写入参数（id、标题、内容、删除标记等）。
// output: 定义 Loro 写侧仓接口，提供卡片 upsert 与按 id 查询能力。
// pos: 卡片写模型仓储抽象，负责隔离命令服务与具体写存储实现。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/domain/card_note.dart';

abstract class CardsWriteRepository {
  Future<void> upsert(CardNote note);

  Future<CardNote?> getById(String id);
}

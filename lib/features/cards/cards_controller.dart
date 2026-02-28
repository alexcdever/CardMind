// input: 当前实现无外部入参，按默认构造创建控制器。
// output: 通过 items 暴露只读卡片摘要列表（当前为空列表）。
// pos: 卡片列表控制器，负责提供卡片摘要集合读取接口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/card_summary.dart';

class CardsController {
  const CardsController();

  List<CardSummary> get items => const <CardSummary>[];
}

// input: 构造函数接收必填 title 字符串。
// output: 生成不可变 CardSummary 实例供卡片列表展示。
// pos: 卡片摘要数据模型，负责承载卡片标题信息。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
class CardSummary {
  const CardSummary({
    required this.id,
    required this.title,
    required this.deleted,
  });

  final String id;
  final String title;
  final bool deleted;
}

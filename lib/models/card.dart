
// 卡片数据模型

class Card {
  final String id;
  final String title;
  final String content;
  final int createdAt;
  final int updatedAt;

  Card({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Card.fromJson(Map<String, dynamic> json) :
    id = json['id'] as String,
    title = json['title'] as String,
    content = json['content'] as String,
    createdAt = json['created_at'] as int,
    updatedAt = json['updated_at'] as int;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Card &&
    runtimeType == other.runtimeType &&
    id == other.id;

  @override
  int get hashCode => id.hashCode;
}
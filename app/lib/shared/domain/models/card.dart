import 'dart:convert';

/// 卡片领域模型
class Card {
  /// 卡片ID
  final int id;
  
  /// 卡片标题
  final String title;
  
  /// 卡片内容
  final String content;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 更新时间
  final DateTime updatedAt;
  
  /// 同步ID，用于与服务器同步
  final String? syncId;

  /// 构造函数
  Card({
    required this.id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 将卡片转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_id': syncId,
    };
  }

  /// 从Map创建卡片
  factory Card.fromMap(Map<String, dynamic> map) {
    return Card(
      id: map['id'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncId: map['sync_id'] as String?,
    );
  }

  /// 将卡片转换为JSON字符串
  String toJson() => json.encode(toMap());

  /// 从JSON字符串创建卡片
  factory Card.fromJson(String source) => Card.fromMap(json.decode(source));

  /// 创建卡片副本并更新指定字段
  Card copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncId,
  }) {
    return Card(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncId: syncId ?? this.syncId,
    );
  }
}

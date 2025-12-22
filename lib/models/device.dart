
// 设备数据模型

class Device {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;

  Device({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  Device.fromJson(Map<String, dynamic> json) :
    id = json['id'] as String,
    name = json['name'] as String,
    createdAt = json['created_at'] as int,
    updatedAt = json['updated_at'] as int;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Device &&
    runtimeType == other.runtimeType &&
    id == other.id;

  @override
  int get hashCode => id.hashCode;
}
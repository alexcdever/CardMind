
// 协作网络数据模型

class Network {
  final String id;
  final String name;
  final String password;
  final int createdAt;
  final int updatedAt;
  final List<String> deviceIds;

  Network({
    required this.id,
    required this.name,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceIds,
  });

  Network.fromJson(Map<String, dynamic> json) :
    id = json['id'] as String,
    name = json['name'] as String,
    password = json['password'] as String,
    createdAt = json['created_at'] as int,
    updatedAt = json['updated_at'] as int,
    deviceIds = List<String>.from(json['device_ids'] as List<dynamic>);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'password': password,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'device_ids': deviceIds,
  };

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Network &&
    runtimeType == other.runtimeType &&
    id == other.id;

  @override
  int get hashCode => id.hashCode;
}
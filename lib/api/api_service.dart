// 与Rust后端通信的API服务

import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// 导入生成的桥接代码和类型
import './frb_generated.dart';
import './api/ir.dart';

// 导入本地模型并使用命名导入避免冲突
import '../models/card.dart' as LocalCard;
import '../models/network.dart' as LocalNetwork;
import '../models/device.dart' as LocalDevice;

// 导入日志工具
import '../utils/logger.dart';

// 导入设备服务
import '../services/device_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // API实例和Rust库
  late final dynamic apiService;
  bool _isInitialized = false;

  // 设备服务实例
  final DeviceService _deviceService = DeviceService();

  // 缓存的设备ID和名称
  String? _currentDeviceId;
  String? _currentDeviceName;

  // 初始化Rust库
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      // 初始化Rust库
      await RustLib.init();
      AppLogger().d('Rust库初始化完成');

      // 获取设备ID和名称
      _currentDeviceId = await _deviceService.getDeviceId();
      _currentDeviceName = await _deviceService.getDeviceName();
      AppLogger().i('设备ID: $_currentDeviceId, 设备名称: $_currentDeviceName');

      // 获取应用数据目录
      final appDir = await getApplicationSupportDirectory();
      final dbPath = path.join(appDir.path, 'cardmind.db');
      AppLogger().i('数据库路径: $dbPath');

      // 创建API服务实例，使用持久化数据库
      apiService = await RustLib.instance.api.crateApiImplApiServiceNew(
        dbPath: dbPath,
      );
      AppLogger().d('API服务实例创建成功');

      // 自动创建默认协作网络和设备
      await _initDefaultNetwork();

      _isInitialized = true;
      AppLogger().i('API服务初始化成功');
    } catch (e) {
      AppLogger().e('Rust库初始化失败', e);
      rethrow;
    }
  }

  // 自动创建默认协作网络和设备
  Future<void> _initDefaultNetwork() async {
    try {
      // 使用真实设备ID和名称创建设备
      final deviceRequest = CreateDeviceRequest(name: _currentDeviceName!);
      await RustLib.instance.api.crateApiImplApiServiceCreateDevice(
        that: apiService,
        request: deviceRequest,
      );
      AppLogger().d('默认设备创建成功: $_currentDeviceName');

      // 创建默认网络
      final networkRequest = CreateNetworkRequest(
        name: '默认网络',
        password: '123456',
      );
      await RustLib.instance.api.crateApiImplApiServiceCreateNetwork(
        that: apiService,
        request: networkRequest,
      );

      AppLogger().i('默认协作网络和设备创建成功');
    } catch (e) {
      AppLogger().e('创建默认协作网络和设备失败', e);
    }
  }

  /// 获取当前设备ID
  String? get currentDeviceId => _currentDeviceId;

  /// 获取当前设备名称
  String? get currentDeviceName => _currentDeviceName;

  // 卡片管理

  /// 创建一个新卡片
  Future<LocalCard.Card> createCard(String title, String content) async {
    try {
      AppLogger().d('开始创建卡片: $title');
      // 确保有设备ID
      if (_currentDeviceId == null) {
        throw Exception('当前设备ID未初始化');
      }
      // 直接使用frb_generated.dart中定义的CreateCardRequest类型
      final request = CreateCardRequest(
        title: title,
        content: content,
        deviceId: _currentDeviceId!, // 传递设备ID
      );
      final result = await RustLib.instance.api
          .crateApiImplApiServiceCreateCard(that: apiService, request: request);

      // 直接访问result的属性，不需要类型转换
      final card = LocalCard.Card(
        id: result.id,
        title: result.title,
        content: result.content,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
      AppLogger().i('卡片创建成功: ${card.id}');
      return card;
    } catch (e) {
      AppLogger().e('创建卡片失败', e);
      rethrow;
    }
  }

  /// 更新现有卡片
  Future<LocalCard.Card> updateCard(
    String id,
    String title,
    String content,
  ) async {
    try {
      AppLogger().d('开始更新卡片: $id, 新标题: $title');
      // 直接使用frb_generated.dart中定义的UpdateCardRequest类型
      final request = UpdateCardRequest(id: id, title: title, content: content);
      final result = await RustLib.instance.api
          .crateApiImplApiServiceUpdateCard(that: apiService, request: request);

      // 直接访问result的属性，不需要类型转换
      final card = LocalCard.Card(
        id: result.id,
        title: result.title,
        content: result.content,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
      AppLogger().i('卡片更新成功: ${card.id}');
      return card;
    } catch (e) {
      AppLogger().e('更新卡片失败: $id', e);
      rethrow;
    }
  }

  /// 删除卡片
  Future<bool> deleteCard(String id) async {
    try {
      AppLogger().d('开始删除卡片: $id');
      await RustLib.instance.api.crateApiImplApiServiceDeleteCard(
        that: apiService,
        id: id,
      );
      AppLogger().i('卡片删除成功: $id');
      return true;
    } catch (e) {
      AppLogger().e('删除卡片失败: $id', e);
      rethrow;
    }
  }

  /// 获取所有卡片
  Future<List<LocalCard.Card>> getCards() async {
    try {
      AppLogger().d('开始获取所有卡片');
      final results = await RustLib.instance.api.crateApiImplApiServiceGetCards(
        that: apiService,
      );

      // 将结果转换为List<dynamic>，然后映射到LocalCard.Card
      final cards = (results as List<dynamic>)
          .map(
            (card) => LocalCard.Card(
              id: card.id,
              title: card.title,
              content: card.content,
              createdAt: card.createdAt,
              updatedAt: card.updatedAt,
            ),
          )
          .toList();
      AppLogger().i('获取卡片列表成功，共 ${cards.length} 张卡片');
      return cards;
    } catch (e) {
      AppLogger().e('获取卡片列表失败', e);
      return [];
    }
  }

  /// 通过ID获取单个卡片
  Future<LocalCard.Card?> getCard(String id) async {
    try {
      AppLogger().d('开始获取卡片: $id');
      // 暂时未实现，通过获取所有卡片然后过滤
      final cards = await getCards();
      try {
        final card = cards.firstWhere((card) => card.id == id);
        AppLogger().i('获取卡片成功: $id');
        return card;
      } catch (e) {
        AppLogger().w('未找到卡片: $id');
        return null;
      }
    } catch (e) {
      AppLogger().e('获取卡片失败: $id', e);
      rethrow;
    }
  }

  /// 将卡片添加到网络
  Future<bool> addCardToNetwork(String cardId, String networkId) async {
    try {
      AppLogger().d('开始将卡片添加到网络: 卡片 $cardId 到网络 $networkId');
      // 直接使用frb_generated.dart中定义的AddCardToNetworkRequest类型
      final request = AddCardToNetworkRequest(
        cardId: cardId,
        networkId: networkId,
      );
      await RustLib.instance.api.crateApiImplApiServiceAddCardToNetwork(
        that: apiService,
        request: request,
      );
      AppLogger().i('卡片添加到网络成功: 卡片 $cardId 到网络 $networkId');
      return true;
    } catch (e) {
      AppLogger().e('添加卡片到网络失败: 卡片 $cardId 到网络 $networkId', e);
      rethrow;
    }
  }

  /// 将卡片从网络中移除
  Future<bool> removeCardFromNetwork(String cardId, String networkId) async {
    try {
      AppLogger().d('开始从网络移除卡片: 卡片 $cardId 从网络 $networkId');
      // 直接使用frb_generated.dart中定义的RemoveCardFromNetworkRequest类型
      final request = RemoveCardFromNetworkRequest(
        cardId: cardId,
        networkId: networkId,
      );
      await RustLib.instance.api.crateApiImplApiServiceRemoveCardFromNetwork(
        that: apiService,
        request: request,
      );
      AppLogger().i('卡片从网络移除成功: 卡片 $cardId 从网络 $networkId');
      return true;
    } catch (e) {
      AppLogger().e('从网络移除卡片失败: 卡片 $cardId 从网络 $networkId', e);
      rethrow;
    }
  }

  // 网络管理

  /// 创建新网络
  Future<LocalNetwork.Network> createNetwork(
    String name,
    String password,
  ) async {
    try {
      AppLogger().d('开始创建网络: $name');
      // 验证参数
      if (name.isEmpty) {
        throw ArgumentError('网络名称不能为空');
      }
      if (password.isEmpty) {
        throw ArgumentError('密码不能为空');
      }

      // 直接使用frb_generated.dart中定义的CreateNetworkRequest类型
      final request = CreateNetworkRequest(name: name, password: password);
      final result = await RustLib.instance.api
          .crateApiImplApiServiceCreateNetwork(
            that: apiService,
            request: request,
          );

      // 直接访问result的属性，不需要类型转换
      final network = LocalNetwork.Network(
        id: result.id,
        name: result.name,
        password: result.password,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
        deviceIds: [],
      );
      AppLogger().i('网络创建成功: ${network.id}');
      return network;
    } catch (e) {
      AppLogger().e('创建网络失败', e);
      rethrow;
    }
  }

  /// 加入现有网络
  Future<LocalNetwork.Network> joinNetwork(String id, String password) async {
    try {
      AppLogger().d('开始加入网络: $id');
      // 验证参数
      if (id.isEmpty) {
        throw ArgumentError('网络ID不能为空');
      }
      if (password.isEmpty) {
        throw ArgumentError('密码不能为空');
      }
      if (_currentDeviceId == null) {
        throw Exception('当前设备ID未初始化');
      }

      // 直接使用frb_generated.dart中定义的JoinNetworkRequest类型
      final request = JoinNetworkRequest(
        networkId: id,
        deviceId: _currentDeviceId!,
        password: password, // 传递密码用于验证
      );
      await RustLib.instance.api.crateApiImplApiServiceJoinNetwork(
        that: apiService,
        request: request,
      );
      AppLogger().i('设备加入网络成功: $id');

      // 获取网络信息
      final networks = await getNetworks();
      return networks.firstWhere((network) => network.id == id);
    } catch (e) {
      AppLogger().e('加入网络失败: $id', e);
      rethrow;
    }
  }

  /// 退出网络
  Future<bool> leaveNetwork(String id) async {
    try {
      AppLogger().d('开始退出网络: $id');
      // 验证参数
      if (id.isEmpty) {
        throw ArgumentError('网络ID不能为空');
      }

      // 直接使用frb_generated.dart中定义的LeaveNetworkRequest类型
      final request = LeaveNetworkRequest(
        networkId: id,
        deviceId: _currentDeviceId!,
      );
      await RustLib.instance.api.crateApiImplApiServiceLeaveNetwork(
        that: apiService,
        request: request,
      );
      AppLogger().i('设备退出网络成功: $id');

      return true;
    } catch (e) {
      AppLogger().e('退出网络失败: $id', e);
      rethrow;
    }
  }

  /// 获取所有网络
  Future<List<LocalNetwork.Network>> getNetworks() async {
    try {
      AppLogger().d('开始获取所有网络');
      final results = await RustLib.instance.api
          .crateApiImplApiServiceGetNetworks(that: apiService);

      // 将结果转换为List<dynamic>，然后映射到LocalNetwork.Network
      final networks = (results as List<dynamic>)
          .map(
            (network) => LocalNetwork.Network(
              id: network.id,
              name: network.name,
              password: network.password,
              createdAt: network.createdAt,
              updatedAt: network.updatedAt,
              deviceIds: [],
            ),
          )
          .toList();
      AppLogger().i('获取网络列表成功，共 ${networks.length} 个网络');
      return networks;
    } catch (e) {
      AppLogger().e('获取网络列表失败', e);
      return [];
    }
  }

  /// 重命名网络
  Future<LocalNetwork.Network> renameNetwork(String id, String name) async {
    try {
      AppLogger().d('开始重命名网络: $id 为 $name');
      // 验证参数
      if (id.isEmpty) {
        throw ArgumentError('网络ID不能为空');
      }
      if (name.isEmpty) {
        throw ArgumentError('网络名称不能为空');
      }

      // 获取现有网络信息
      final networks = await getNetworks();
      final existingNetwork = networks.firstWhere(
        (network) => network.id == id,
      );

      // 直接使用frb_generated.dart中定义的UpdateNetworkRequest类型
      final request = UpdateNetworkRequest(
        id: id,
        name: name,
        password: existingNetwork.password,
      );
      final result = await RustLib.instance.api
          .crateApiImplApiServiceUpdateNetwork(
            that: apiService,
            request: request,
          );

      // 直接访问result的属性，不需要类型转换
      final network = LocalNetwork.Network(
        id: result.id,
        name: result.name,
        password: result.password,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
        deviceIds: [],
      );
      AppLogger().i('网络重命名成功: ${network.id}');
      return network;
    } catch (e) {
      AppLogger().e('重命名网络失败: $id', e);
      rethrow;
    }
  }

  /// 设置网络为常驻网络或取消
  Future<bool> setResidentNetwork(String networkId, bool isResident) async {
    try {
      AppLogger().d('开始设置常驻网络: $networkId, isResident: $isResident');
      // 验证参数
      if (networkId.isEmpty) {
        throw ArgumentError('网络ID不能为空');
      }

      if (isResident) {
        // 直接使用frb_generated.dart中定义的SetResidentNetworkRequest类型
        final request = SetResidentNetworkRequest(
          networkId: networkId,
          deviceId: _currentDeviceId!,
        );
        await RustLib.instance.api.crateApiImplApiServiceSetResidentNetwork(
          that: apiService,
          request: request,
        );
        AppLogger().i('设置常驻网络成功: $networkId');
      } else {
        await RustLib.instance.api.crateApiImplApiServiceUnsetResidentNetwork(
          that: apiService,
          deviceId: _currentDeviceId!,
        );
        AppLogger().i('取消常驻网络成功');
      }

      return true;
    } catch (e) {
      AppLogger().e('设置常驻网络失败', e);
      rethrow;
    }
  }

  // 设备管理

  /// 获取所有设备
  Future<List<LocalDevice.Device>> getDevices() async {
    try {
      AppLogger().d('开始获取所有设备');
      final results = await RustLib.instance.api
          .crateApiImplApiServiceGetDevices(that: apiService);

      // 将结果转换为List<dynamic>，然后映射到LocalDevice.Device
      final devices = (results as List<dynamic>)
          .map(
            (device) => LocalDevice.Device(
              id: device.id,
              name: device.name,
              createdAt: device.createdAt,
              updatedAt: device.updatedAt,
            ),
          )
          .toList();
      AppLogger().i('获取设备列表成功，共 ${devices.length} 个设备');
      return devices;
    } catch (e) {
      AppLogger().e('获取设备列表失败', e);
      return [];
    }
  }

  /// 更新设备名称
  Future<LocalDevice.Device> updateDeviceName(String id, String name) async {
    try {
      AppLogger().d('开始更新设备名称: $id 为 $name');
      // 验证参数
      if (id.isEmpty) {
        throw ArgumentError('设备ID不能为空');
      }
      if (name.isEmpty) {
        throw ArgumentError('设备名称不能为空');
      }

      // 暂时未实现
      throw UnimplementedError('更新设备名称功能尚未实现');
    } catch (e) {
      AppLogger().e('更新设备名称失败: $id', e);
      rethrow;
    }
  }
}

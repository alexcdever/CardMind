// 与Rust后端通信的API服务

import 'dart:async';

// 导入生成的桥接代码和类型
import './frb_generated.dart';
import './api/ir.dart';

// 导入本地模型并使用命名导入避免冲突
import '../models/card.dart' as LocalCard;
import '../models/network.dart' as LocalNetwork;
import '../models/device.dart' as LocalDevice;

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // API实例和Rust库
  late final dynamic apiService;
  bool _isInitialized = false;

  // 初始化Rust库
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      // 初始化Rust库
      await RustLib.init();

      // 创建API服务实例，使用内存数据库进行测试
      apiService = await RustLib.instance.api.crateApiImplApiServiceNew(
        dbPath: ":memory:",
      );

      // 自动创建默认协作网络和设备
      await _initDefaultNetwork();

      _isInitialized = true;
      print('Rust库初始化成功');
    } catch (e) {
      print('Rust库初始化失败: $e');
      rethrow;
    }
  }

  // 自动创建默认协作网络和设备
  Future<void> _initDefaultNetwork() async {
    try {
      // 创建设备 - 直接使用frb_generated.dart中定义的CreateDeviceRequest类型
      final deviceRequest = CreateDeviceRequest(name: '默认设备');
      await RustLib.instance.api.crateApiImplApiServiceCreateDevice(
        that: apiService,
        request: deviceRequest,
      );

      // 创建默认网络 - 直接使用frb_generated.dart中定义的CreateNetworkRequest类型
      final networkRequest = CreateNetworkRequest(
        name: '默认网络',
        password: '123456',
      );
      await RustLib.instance.api.crateApiImplApiServiceCreateNetwork(
        that: apiService,
        request: networkRequest,
      );

      print('默认协作网络和设备创建成功');
    } catch (e) {
      print('创建默认协作网络和设备失败: $e');
    }
  }

  // 卡片管理

  /// 创建一个新卡片
  Future<LocalCard.Card> createCard(String title, String content) async {
    try {
      // 直接使用frb_generated.dart中定义的CreateCardRequest类型
      final request = CreateCardRequest(title: title, content: content);
      final result = await RustLib.instance.api
          .crateApiImplApiServiceCreateCard(that: apiService, request: request);

      // 直接访问result的属性，不需要类型转换
      return LocalCard.Card(
        id: result.id,
        title: result.title,
        content: result.content,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
    } catch (e) {
      print('创建卡片失败: $e');
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
      // 直接使用frb_generated.dart中定义的UpdateCardRequest类型
      final request = UpdateCardRequest(id: id, title: title, content: content);
      final result = await RustLib.instance.api
          .crateApiImplApiServiceUpdateCard(that: apiService, request: request);

      // 直接访问result的属性，不需要类型转换
      return LocalCard.Card(
        id: result.id,
        title: result.title,
        content: result.content,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
    } catch (e) {
      print('更新卡片失败: $e');
      rethrow;
    }
  }

  /// 删除卡片
  Future<bool> deleteCard(String id) async {
    try {
      await RustLib.instance.api.crateApiImplApiServiceDeleteCard(
        that: apiService,
        id: id,
      );
      return true;
    } catch (e) {
      print('删除卡片失败: $e');
      rethrow;
    }
  }

  /// 获取所有卡片
  Future<List<LocalCard.Card>> getCards() async {
    try {
      final results = await RustLib.instance.api.crateApiImplApiServiceGetCards(
        that: apiService,
      );

      // 将结果转换为List<dynamic>，然后映射到LocalCard.Card
      return (results as List<dynamic>)
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
    } catch (e) {
      print('获取卡片列表失败: $e');
      return [];
    }
  }

  /// 通过ID获取单个卡片
  Future<LocalCard.Card?> getCard(String id) async {
    try {
      // 暂时未实现，通过获取所有卡片然后过滤
      final cards = await getCards();
      try {
        return cards.firstWhere((card) => card.id == id);
      } catch (e) {
        return null;
      }
    } catch (e) {
      print('获取卡片失败: $e');
      rethrow;
    }
  }

  /// 将卡片添加到网络
  Future<bool> addCardToNetwork(String cardId, String networkId) async {
    try {
      // 直接使用frb_generated.dart中定义的AddCardToNetworkRequest类型
      final request = AddCardToNetworkRequest(
        cardId: cardId,
        networkId: networkId,
      );
      await RustLib.instance.api.crateApiImplApiServiceAddCardToNetwork(
        that: apiService,
        request: request,
      );
      return true;
    } catch (e) {
      print('添加卡片到网络失败: $e');
      rethrow;
    }
  }

  /// 将卡片从网络中移除
  Future<bool> removeCardFromNetwork(String cardId, String networkId) async {
    try {
      // 直接使用frb_generated.dart中定义的RemoveCardFromNetworkRequest类型
      final request = RemoveCardFromNetworkRequest(
        cardId: cardId,
        networkId: networkId,
      );
      await RustLib.instance.api.crateApiImplApiServiceRemoveCardFromNetwork(
        that: apiService,
        request: request,
      );
      return true;
    } catch (e) {
      print('从网络移除卡片失败: $e');
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
      return LocalNetwork.Network(
        id: result.id,
        name: result.name,
        password: result.password,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
        deviceIds: [],
      );
    } catch (e) {
      print('创建网络失败: $e');
      rethrow;
    }
  }

  /// 加入现有网络
  Future<LocalNetwork.Network> joinNetwork(String id, String password) async {
    try {
      // 验证参数
      if (id.isEmpty) {
        throw ArgumentError('网络ID不能为空');
      }
      if (password.isEmpty) {
        throw ArgumentError('密码不能为空');
      }

      // 直接使用frb_generated.dart中定义的JoinNetworkRequest类型
      final request = JoinNetworkRequest(networkId: id, deviceId: '默认设备');
      await RustLib.instance.api.crateApiImplApiServiceJoinNetwork(
        that: apiService,
        request: request,
      );

      // 获取网络信息
      final networks = await getNetworks();
      return networks.firstWhere((network) => network.id == id);
    } catch (e) {
      print('加入网络失败: $e');
      rethrow;
    }
  }

  /// 退出网络
  Future<bool> leaveNetwork(String id) async {
    try {
      // 验证参数
      if (id.isEmpty) {
        throw ArgumentError('网络ID不能为空');
      }

      // 直接使用frb_generated.dart中定义的LeaveNetworkRequest类型
      final request = LeaveNetworkRequest(networkId: id, deviceId: '默认设备');
      await RustLib.instance.api.crateApiImplApiServiceLeaveNetwork(
        that: apiService,
        request: request,
      );

      return true;
    } catch (e) {
      print('退出网络失败: $e');
      rethrow;
    }
  }

  /// 获取所有网络
  Future<List<LocalNetwork.Network>> getNetworks() async {
    try {
      final results = await RustLib.instance.api
          .crateApiImplApiServiceGetNetworks(that: apiService);

      // 将结果转换为List<dynamic>，然后映射到LocalNetwork.Network
      return (results as List<dynamic>)
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
    } catch (e) {
      print('获取网络列表失败: $e');
      return [];
    }
  }

  /// 重命名网络
  Future<LocalNetwork.Network> renameNetwork(String id, String name) async {
    try {
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
      return LocalNetwork.Network(
        id: result.id,
        name: result.name,
        password: result.password,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
        deviceIds: [],
      );
    } catch (e) {
      print('重命名网络失败: $e');
      rethrow;
    }
  }

  /// 设置网络为常驻网络或取消
  Future<bool> setResidentNetwork(String networkId, bool isResident) async {
    try {
      // 验证参数
      if (networkId.isEmpty) {
        throw ArgumentError('网络ID不能为空');
      }

      if (isResident) {
        // 直接使用frb_generated.dart中定义的SetResidentNetworkRequest类型
        final request = SetResidentNetworkRequest(
          networkId: networkId,
          deviceId: '默认设备',
        );
        await RustLib.instance.api.crateApiImplApiServiceSetResidentNetwork(
          that: apiService,
          request: request,
        );
      } else {
        await RustLib.instance.api.crateApiImplApiServiceUnsetResidentNetwork(
          that: apiService,
          deviceId: '默认设备',
        );
      }

      return true;
    } catch (e) {
      print('设置常驻网络失败: $e');
      rethrow;
    }
  }

  // 设备管理

  /// 获取所有设备
  Future<List<LocalDevice.Device>> getDevices() async {
    try {
      final results = await RustLib.instance.api
          .crateApiImplApiServiceGetDevices(that: apiService);

      // 将结果转换为List<dynamic>，然后映射到LocalDevice.Device
      return (results as List<dynamic>)
          .map(
            (device) => LocalDevice.Device(
              id: device.id,
              name: device.name,
              createdAt: device.createdAt,
              updatedAt: device.updatedAt,
            ),
          )
          .toList();
    } catch (e) {
      print('获取设备列表失败: $e');
      return [];
    }
  }

  /// 更新设备名称
  Future<LocalDevice.Device> updateDeviceName(String id, String name) async {
    try {
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
      print('更新设备名称失败: $e');
      rethrow;
    }
  }
}

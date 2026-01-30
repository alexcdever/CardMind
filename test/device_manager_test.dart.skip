import 'package:flutter/material.dart';
import 'package:cardmind/screens/device_manager_page.dart';

/// 设备管理页面测试应用
///
/// 用于测试第二阶段的桌面端 UI 组件
void main() {
  runApp(const DeviceManagerTestApp());
}

class DeviceManagerTestApp extends StatelessWidget {
  const DeviceManagerTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '设备管理测试',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DeviceManagerTestScreen(),
    );
  }
}

class DeviceManagerTestScreen extends StatefulWidget {
  const DeviceManagerTestScreen({super.key});

  @override
  State<DeviceManagerTestScreen> createState() =>
      _DeviceManagerTestScreenState();
}

class _DeviceManagerTestScreenState extends State<DeviceManagerTestScreen> {
  bool _hasJoinedPool = true;
  late Device _currentDevice;
  late List<Device> _pairedDevices;

  @override
  void initState() {
    super.initState();
    _initTestData();
  }

  void _initTestData() {
    // 当前设备
    _currentDevice = Device(
      id: '12D3KooWRBhwfeP8p3FcGkVXqLzFSvLkNXXmKJNZqKqKqKqKqKqK',
      name: '我的笔记本',
      type: DeviceType.laptop,
      status: DeviceStatus.online,
      lastSeen: DateTime.now(),
      multiaddrs: [
        '/ip4/192.168.1.100/tcp/4001',
        '/ip4/192.168.1.100/udp/4001/quic',
        '/ip6/::1/tcp/4001',
      ],
    );

    // 已配对设备
    _pairedDevices = [
      Device(
        id: '12D3KooWABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ABCDEF',
        name: '我的手机',
        type: DeviceType.phone,
        status: DeviceStatus.online,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
        multiaddrs: [
          '/ip4/192.168.1.101/tcp/4001',
          '/ip4/192.168.1.101/udp/4001/quic',
        ],
      ),
      Device(
        id: '12D3KooW1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEF',
        name: '办公室电脑',
        type: DeviceType.laptop,
        status: DeviceStatus.offline,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        multiaddrs: [
          '/ip4/192.168.1.102/tcp/4001',
        ],
      ),
      Device(
        id: '12D3KooWXYZ1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZABC',
        name: 'iPad Pro',
        type: DeviceType.tablet,
        status: DeviceStatus.online,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
        multiaddrs: [
          '/ip4/192.168.1.103/tcp/4001',
          '/ip4/192.168.1.103/udp/4001/quic',
          '/ip6/fe80::1/tcp/4001',
        ],
      ),
    ];
  }

  void _handleDeviceNameChange(String newName) {
    setState(() {
      _currentDevice = Device(
        id: _currentDevice.id,
        name: newName,
        type: _currentDevice.type,
        status: _currentDevice.status,
        lastSeen: _currentDevice.lastSeen,
        multiaddrs: _currentDevice.multiaddrs,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('设备名称已更新为: $newName')),
    );
  }

  Future<bool> _handlePairDevice(String deviceId, String verificationCode) async {
    // 模拟配对过程
    await Future.delayed(const Duration(seconds: 1));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('配对设备: $deviceId\n验证码: $verificationCode'),
      ),
    );

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理测试'),
        actions: [
          // 切换加入池状态
          Switch(
            value: _hasJoinedPool,
            onChanged: (value) {
              setState(() {
                _hasJoinedPool = value;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(_hasJoinedPool ? '已加入池' : '未加入池'),
          const SizedBox(width: 16),

          // 切换设备列表
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'empty':
                    _pairedDevices = [];
                    break;
                  case 'one':
                    _pairedDevices = [_pairedDevices.first];
                    break;
                  case 'full':
                    _initTestData();
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'empty',
                child: Text('空设备列表'),
              ),
              const PopupMenuItem(
                value: 'one',
                child: Text('单个设备'),
              ),
              const PopupMenuItem(
                value: 'full',
                child: Text('完整设备列表'),
              ),
            ],
          ),
        ],
      ),
      body: DeviceManagerPage(
        hasJoinedPool: _hasJoinedPool,
        currentDevice: _currentDevice,
        pairedDevices: _pairedDevices,
        onDeviceNameChange: _handleDeviceNameChange,
        onPairDevice: _handlePairDevice,
      ),
    );
  }
}

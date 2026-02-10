/// 同步详情对话框
///
/// 显示同步状态详情的对话框
///
/// 规格编号: SP-FLUT-010
/// 功能：
/// - 显示当前同步状态和描述
/// - 显示对等设备列表
/// - 显示同步统计信息
/// - 显示同步历史记录
/// - 提供重试按钮（failed 状态）
library;

import 'dart:async';

import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sync_details_dialog/sections/device_list_section.dart';
import 'sync_details_dialog/sections/sync_history_section.dart';
import 'sync_details_dialog/sections/sync_statistics_section.dart';
import 'sync_details_dialog/sections/sync_status_section.dart';
import 'sync_details_dialog/utils/sync_dialog_constants.dart';

/// 同步详情对话框
class SyncDetailsDialog extends StatefulWidget {
  const SyncDetailsDialog({super.key, required this.initialStatus});

  /// 初始同步状态
  final api.SyncStatus initialStatus;

  /// 显示对话框
  static Future<void> show(BuildContext context, api.SyncStatus status) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      requestFocus: true,
      builder: (context) => SyncDetailsDialog(initialStatus: status),
    );
  }

  @override
  State<SyncDetailsDialog> createState() => _SyncDetailsDialogState();
}

class _SyncDetailsDialogState extends State<SyncDetailsDialog>
    with SingleTickerProviderStateMixin {
  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late FocusScopeNode _focusScopeNode;

  // 数据状态
  late api.SyncStatus _currentStatus;
  List<api.DeviceInfo> _devices = [];
  api.SyncStatistics? _statistics;
  List<api.SyncHistoryEvent> _history = [];

  // 加载状态
  bool _isLoadingDevices = true;
  bool _isLoadingStatistics = true;
  bool _isLoadingHistory = true;

  // 错误状态
  String? _devicesError;
  String? _statisticsError;
  String? _historyError;

  // Stream 订阅
  StreamSubscription<api.SyncStatus>? _statusSubscription;

  // 定时器
  Timer? _devicePollingTimer;

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _closeDialog();
      return true;
    }
    return false;
  }

  // 上一个同步状态（用于检测 syncing → synced 转换）
  api.SyncUiState? _previousSyncState;

  @override
  void initState() {
    super.initState();

    // 初始化状态
    _currentStatus = widget.initialStatus;
    _previousSyncState = widget.initialStatus.state;

    _focusScopeNode = FocusScopeNode();

    // 初始化动画
    _animationController = AnimationController(
      duration: SyncDialogDuration.dialogOpen,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: SyncDialogCurve.dialogOpen,
      ),
    );

    _scaleAnimation =
        Tween<double>(
          begin: SyncDialogScale.dialogOpenStart,
          end: SyncDialogScale.dialogOpenEnd,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: SyncDialogCurve.dialogOpen,
          ),
        );

    // 启动动画
    _animationController.forward();

    // 订阅同步状态流
    _subscribeToStatusStream();

    // 加载初始数据
    _loadDeviceList();
    _loadStatistics();
    _loadHistory();

    // 启动设备列表轮询（每 5 秒）
    _devicePollingTimer = Timer.periodic(
      SyncDialogPolling.deviceList,
      (_) => _loadDeviceList(),
    );

    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusScopeNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _statusSubscription?.cancel();
    _devicePollingTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _focusScopeNode.dispose();
    super.dispose();
  }

  /// 订阅同步状态流
  void _subscribeToStatusStream() {
    _statusSubscription?.cancel();

    try {
      final stream = api.getSyncStatusStream();
      _statusSubscription = stream.listen(
        (status) {
          if (!mounted) return;

          setState(() {
            // 检测 syncing → synced 转换
            final isCompletedSync =
                _previousSyncState == api.SyncUiState.syncing &&
                status.state == api.SyncUiState.synced;

            _previousSyncState = _currentStatus.state;
            _currentStatus = status;

            // 同步完成时刷新统计和历史
            if (isCompletedSync) {
              _loadStatistics();
              _loadHistory();
            }
          });
        },
        onError: (Object error) {
          debugPrint('同步状态流错误: $error');
        },
      );
    } on Exception catch (e) {
      debugPrint('订阅同步状态流失败: $e');
    }
  }

  /// 加载设备列表
  Future<void> _loadDeviceList() async {
    try {
      final devices = await api.getDeviceList();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoadingDevices = false;
          _devicesError = null;
        });
      }
    } on Exception catch (e) {
      debugPrint('加载设备列表失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingDevices = false;
          _devicesError = '加载设备列表失败';
        });
      }
    }
  }

  /// 加载统计信息
  Future<void> _loadStatistics() async {
    try {
      final statistics = await api.getSyncStatistics();
      if (mounted) {
        setState(() {
          _statistics = statistics;
          _isLoadingStatistics = false;
          _statisticsError = null;
        });
      }
    } on Exception catch (e) {
      debugPrint('加载统计信息失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingStatistics = false;
          _statisticsError = '加载统计信息失败';
        });
      }
    }
  }

  /// 加载同步历史
  Future<void> _loadHistory() async {
    try {
      final history = await api.getSyncHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _isLoadingHistory = false;
          _historyError = null;
        });
      }
    } on Exception catch (e) {
      debugPrint('加载同步历史失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _historyError = '加载同步历史失败';
        });
      }
    }
  }

  /// 关闭对话框（带动画）
  Future<void> _closeDialog() async {
    // 反向播放动画
    _animationController.duration = SyncDialogDuration.dialogClose;
    unawaited(_animationController.reverse());

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _closeDialog();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '同步详情对话框',
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: FocusScope(
        node: _focusScopeNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AlertDialog(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SyncDialogSize.borderRadius,
                ),
              ),
              content: Container(
                width: SyncDialogSize.width,
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      SyncDialogSize.maxHeightRatio,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题栏
                    _buildHeader(),
                    // 内容区域（可滚动）
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(SyncDialogSize.padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 同步状态区域
                            SyncStatusSection(status: _currentStatus),
                            const SizedBox(
                              height: SyncDialogSize.sectionSpacing,
                            ),

                            // 设备列表区域
                            DeviceListSection(
                              devices: _devices,
                              isLoading: _isLoadingDevices,
                              error: _devicesError,
                              onRetry: _loadDeviceList,
                            ),
                            const SizedBox(
                              height: SyncDialogSize.sectionSpacing,
                            ),

                            // 统计信息区域
                            if (_statistics != null || _statisticsError != null)
                              SyncStatisticsSection(
                                statistics:
                                    _statistics ??
                                    const api.SyncStatistics(
                                      syncedCards: 0,
                                      syncedDataSize: 0,
                                      successfulSyncs: 0,
                                      failedSyncs: 0,
                                    ),
                                isLoading: _isLoadingStatistics,
                                error: _statisticsError,
                                onRetry: _loadStatistics,
                              ),
                            if (_statistics != null || _statisticsError != null)
                              const SizedBox(
                                height: SyncDialogSize.sectionSpacing,
                              ),

                            // 同步历史区域
                            SyncHistorySection(
                              history: _history,
                              isLoading: _isLoadingHistory,
                              error: _historyError,
                              onRetry: _loadHistory,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(SyncDialogSize.padding),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SyncDialogColor.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text('同步详情', style: SyncDialogTextStyle.title),
          const Spacer(),
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _closeDialog,
            tooltip: '关闭 (ESC)',
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:cardmind/adaptive/layouts/three_column_layout.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/adaptive/widgets/adaptive_fab.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/utils/toast_utils.dart';
import 'package:cardmind/widgets/device_manager_panel.dart';
import 'package:cardmind/widgets/mobile_nav.dart';
import 'package:cardmind/widgets/note_card.dart';
import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:cardmind/widgets/settings_panel.dart';
import 'package:cardmind/widgets/sync_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 主屏幕 - 自适应移动端和桌面端布局
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.syncStatusStream});

  /// 可选的同步状态流（用于测试）
  final Stream<SyncStatus>? syncStatusStream;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<SyncStatus>? _syncStatusStream;
  StreamSubscription<SyncStatus>? _syncSubscription;
  Timer? _initTimer;

  // 移动端标签页状态
  NavTab _activeTab = NavTab.notes;

  // 搜索状态
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 全屏编辑器状态
  bridge.Card? _editingCard;
  bool _isEditorOpen = false;

  // 主题状态
  bool _isDarkMode = false;

  // 当前设备信息（模拟）
  final String _currentDeviceName = '我的设备';

  @override
  void initState() {
    super.initState();
    // Delay sync status stream initialization to ensure sync service is ready
    _initTimer = Timer(
      const Duration(milliseconds: 500),
      _initSyncStatusStream,
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _syncSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _initSyncStatusStream() {
    // Temporarily disable sync status stream due to threading issues
    // TODO: Fix Tokio runtime context issue
    _syncStatusStream = Stream.value(SyncStatus.notYetSynced());
    return;

    // Original code (disabled)
    /*
    if (widget.syncStatusStream != null) {
      _syncStatusStream = widget.syncStatusStream;
      return;
    }

    try {
      _syncStatusStream = sync_api
          .getSyncStatusStream()
          .map(_convertRustStatus)
          .distinct(
            (prev, next) =>
                prev.state == next.state &&
                prev.syncingPeers == next.syncingPeers &&
                prev.errorMessage == next.errorMessage,
          )
          .debounceTime(const Duration(milliseconds: 500))
          .handleError((Object error) {
            debugPrint('同步状态 Stream 错误: $error');
            return SyncStatus.notYetSynced();
          });
    } catch (e) {
      debugPrint('初始化同步状态 Stream 失败: $e');
      _syncStatusStream = Stream.value(SyncStatus.notYetSynced());
    }
    */
  }

  void _handleCreateCard() {
    // 移动端直接打开新的全屏编辑器
    if (PlatformDetector.isMobile) {
      setState(() {
        _editingCard = null; // null 表示新建模式
        _isEditorOpen = true;
      });
      return;
    }

    // 桌面端保持原有逻辑
    final cardProvider = context.read<CardProvider>();

    // 创建新卡片
    cardProvider
        .createCard('', '')
        .then((card) {
          if (card != null) {
            ToastUtils.showSuccess('创建新笔记');
          }
        })
        .catchError((Object error) {
          ToastUtils.showError('创建失败: $error');
        });
  }

  void _handleSaveCard(bridge.Card card) {
    final cardProvider = context.read<CardProvider>();

    if (_editingCard == null) {
      // 新建模式：创建新卡片
      cardProvider
          .createCard(card.title, card.content)
          .then((createdCard) {
            if (createdCard != null) {
              ToastUtils.showSuccess('笔记已创建');
            }
          })
          .catchError((Object error) {
            ToastUtils.showError('创建失败: $error');
          });
    } else {
      // 编辑模式：更新现有卡片
      cardProvider
          .updateCard(card.id, title: card.title, content: card.content)
          .then((_) {
            ToastUtils.showSuccess('笔记已更新');
          })
          .catchError((Object error) {
            ToastUtils.showError('更新失败: $error');
          });
    }
  }

  void _handleCloseEditor() {
    setState(() {
      _isEditorOpen = false;
      _editingCard = null;
    });
  }

  void _handleUpdateCard(bridge.Card card) {
    final cardProvider = context.read<CardProvider>();

    cardProvider
        .updateCard(card.id, title: card.title, content: card.content)
        .then((_) {
          ToastUtils.showSuccess('笔记已更新');

          // 关闭编辑器
          if (_isEditorOpen) {
            setState(() {
              _isEditorOpen = false;
              _editingCard = null;
            });
          }
        })
        .catchError((Object error) {
          ToastUtils.showError('更新失败: $error');
        });
  }

  void _handleDeleteCard(String id) {
    final cardProvider = context.read<CardProvider>();

    cardProvider
        .deleteCard(id)
        .then((_) {
          ToastUtils.showSuccess('笔记已删除');
        })
        .catchError((Object error) {
          ToastUtils.showError('删除失败: $error');
        });
  }

  List<bridge.Card> _getFilteredCards(List<bridge.Card> cards) {
    if (_searchQuery.isEmpty) {
      return cards;
    }

    final query = _searchQuery.toLowerCase();
    return cards.where((card) {
      return card.title.toLowerCase().contains(query) ||
          card.content.toLowerCase().contains(query) ||
          card.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformDetector.isMobile;

    return Scaffold(
      body: Stack(
        children: [
          // 主内容
          Column(
            children: [
              // 顶部导航栏
              _buildAppBar(),

              // 内容区域
              Expanded(
                child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
              ),
            ],
          ),

          // 全屏编辑器（移动端）
          if (_isEditorOpen)
            NoteEditorFullscreen(
              card: _editingCard, // null = 新建模式，非 null = 编辑模式
              currentDevice: _currentDeviceName,
              isOpen: _isEditorOpen,
              onClose: _handleCloseEditor,
              onSave: _handleSaveCard,
            ),
        ],
      ),

      // 浮动操作按钮（移动端）
      floatingActionButton: AdaptiveFab(
        onPressed: _handleCreateCard,
        tooltip: '新建笔记',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // 底部导航栏（移动端）
      bottomNavigationBar: PlatformDetector.isMobile
          ? Consumer<CardProvider>(
              builder: (context, cardProvider, _) {
                return MobileNav(
                  currentTab: _activeTab,
                  onTabChange: (tab) {
                    setState(() {
                      _activeTab = tab;
                    });
                  },
                  notesCount: cardProvider.cards.length,
                  devicesCount: 0, // TODO: 从实际数据获取
                );
              },
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.note,
                size: PlatformDetector.isMobile ? 24 : 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('分布式笔记', style: theme.textTheme.titleLarge),
                  if (!PlatformDetector.isMobile)
                    Text('多设备协同 · 局域网同步', style: theme.textTheme.bodySmall),
                ],
              ),
              const Spacer(),

              // 同步状态指示器
              StreamBuilder<SyncStatus>(
                stream: _syncStatusStream,
                initialData: SyncStatus.notYetSynced(),
                builder: (context, snapshot) {
                  final status = snapshot.hasError
                      ? SyncStatus.notYetSynced()
                      : (snapshot.data ?? SyncStatus.notYetSynced());
                  return SyncStatusIndicator(status: status);
                },
              ),

              // 桌面端新建按钮
              if (!PlatformDetector.isMobile) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _handleCreateCard,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('新建笔记'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ThreeColumnLayout(
        leftColumnWidth: 320,
        leftColumn: SingleChildScrollView(
          child: Column(
            children: [
              DeviceManagerPanel(
                currentDevice: DeviceInfo(
                  id: 'current',
                  name: _currentDeviceName,
                  type: DeviceType.laptop,
                  isOnline: true,
                  lastSeen: DateTime.now(),
                ),
                pairedDevices: const [], // TODO: 从实际数据获取
                onDeviceNameChange: (name) {
                  // TODO: 实现设备重命名
                },
                onAddDevice: (device) {
                  // TODO: 实现添加设备
                },
                onRemoveDevice: (id) {
                  // TODO: 实现移除设备
                },
              ),
              const SizedBox(height: 16),
              SettingsPanel(
                isDarkMode: _isDarkMode,
                onThemeChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                  // TODO: 实现主题切换
                },
              ),
            ],
          ),
        ),
        rightColumn: Column(
          children: [
            // 搜索栏
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索笔记标题、内容或标签...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 笔记网格
            Expanded(
              child: Consumer<CardProvider>(
                builder: (context, cardProvider, _) {
                  if (cardProvider.isLoading && cardProvider.cards.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final filteredCards = _getFilteredCards(cardProvider.cards);

                  if (filteredCards.isEmpty) {
                    return _buildEmptyState();
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: filteredCards.length,
                    itemBuilder: (context, index) {
                      return NoteCard(
                        card: filteredCards[index],
                        onEdit: _handleUpdateCard,
                        onDelete: _handleDeleteCard,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return IndexedStack(
      index: _activeTab.index,
      children: [
        // 笔记标签页
        _buildNotesTab(),

        // 设备标签页
        Padding(
          padding: const EdgeInsets.all(16),
          child: DeviceManagerPanel(
            currentDevice: DeviceInfo(
              id: 'current',
              name: _currentDeviceName,
              type: DeviceType.phone,
              isOnline: true,
              lastSeen: DateTime.now(),
            ),
            pairedDevices: const [], // TODO: 从实际数据获取
            onDeviceNameChange: (name) {
              // TODO: 实现设备重命名
            },
            onAddDevice: (device) {
              // TODO: 实现添加设备
            },
            onRemoveDevice: (id) {
              // TODO: 实现移除设备
            },
          ),
        ),

        // 设置标签页
        Padding(
          padding: const EdgeInsets.all(16),
          child: SettingsPanel(
            isDarkMode: _isDarkMode,
            onThemeChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
              // TODO: 实现主题切换
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索笔记...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // 笔记列表
        Expanded(
          child: Consumer<CardProvider>(
            builder: (context, cardProvider, _) {
              if (cardProvider.isLoading && cardProvider.cards.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredCards = _getFilteredCards(cardProvider.cards);

              if (filteredCards.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredCards.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NoteCard(
                      card: filteredCards[index],
                      onEdit: _handleUpdateCard,
                      onDelete: _handleDeleteCard,
                      onTap: () {
                        setState(() {
                          _editingCard = filteredCards[index];
                          _isEditorOpen = true;
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '还没有笔记' : '没有找到匹配的笔记',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleCreateCard,
              icon: const Icon(Icons.add),
              label: const Text('创建第一条笔记'),
            ),
          ],
        ],
      ),
    );
  }
}

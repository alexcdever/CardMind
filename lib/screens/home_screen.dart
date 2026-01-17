import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/screens/card_editor_screen.dart';
import 'package:cardmind/screens/settings_screen.dart';
import 'package:cardmind/bridge/api/sync.dart' as rust_sync;
import 'package:cardmind/bridge/third_party/cardmind_rust/api/sync.dart' as sync_api;
import 'package:cardmind/utils/responsive_utils.dart';
import 'package:cardmind/widgets/card_list_item.dart';
import 'package:cardmind/widgets/sync_status_indicator.dart';

/// Home screen showing the list of cards
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<SyncStatus>? _syncStatusStream;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _initSyncStatusStream();
  }

  /// 将 Rust SyncStatus 转换为 Flutter SyncStatus
  SyncStatus _convertRustStatus(rust_sync.SyncStatus rustStatus) {
    switch (rustStatus.state) {
      case rust_sync.SyncState.disconnected:
        return SyncStatus.disconnected();
      case rust_sync.SyncState.syncing:
        return SyncStatus.syncing(syncingPeers: rustStatus.syncingPeers);
      case rust_sync.SyncState.synced:
        final lastSyncTime = rustStatus.lastSyncTime != null
            ? DateTime.fromMillisecondsSinceEpoch(rustStatus.lastSyncTime!)
            : DateTime.now();
        return SyncStatus.synced(lastSyncTime: lastSyncTime);
      case rust_sync.SyncState.failed:
        return SyncStatus.failed(
          errorMessage: rustStatus.errorMessage ?? 'Unknown error',
        );
    }
  }

  void _initSyncStatusStream() {
    try {
      // 订阅同步状态 Stream
      // 应用 distinct() 过滤重复状态
      // 应用 debounceTime 避免 UI 闪烁
      _syncStatusStream = sync_api
          .getSyncStatusStream()
          .map(_convertRustStatus)
          .distinct((prev, next) =>
              prev.state == next.state &&
              prev.syncingPeers == next.syncingPeers &&
              prev.errorMessage == next.errorMessage)
          .debounceTime(const Duration(milliseconds: 500))
          .handleError((error) {
        debugPrint('同步状态 Stream 错误: $error');
        // 错误时返回 disconnected 状态
        return SyncStatus.disconnected();
      });
    } catch (e) {
      debugPrint('初始化同步状态 Stream 失败: $e');
      // 如果初始化失败，创建一个只发送 disconnected 状态的 Stream
      _syncStatusStream = Stream.value(SyncStatus.disconnected());
    }
  }

  @override
  void dispose() {
    // 取消 Stream 订阅
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CardMind'),
        actions: [
          // 同步状态指示器 - 使用 StreamBuilder 订阅真实的 Stream
          StreamBuilder<SyncStatus>(
            stream: _syncStatusStream,
            initialData: SyncStatus.disconnected(),
            builder: (context, snapshot) {
              // 错误处理：fallback 到 disconnected 状态
              final status = snapshot.hasError
                  ? SyncStatus.disconnected()
                  : (snapshot.data ?? SyncStatus.disconnected());

              return SyncStatusIndicator(status: status);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CardProvider>().loadCards();
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<CardProvider>(
        builder: (context, cardProvider, child) {
          if (cardProvider.isLoading && cardProvider.cards.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (cardProvider.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${cardProvider.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => cardProvider.loadCards(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (cardProvider.cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_add_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No cards yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to create your first card',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => cardProvider.loadCards(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use GridView for larger screens
                if (ResponsiveUtils.isTablet(context) ||
                    ResponsiveUtils.isDesktop(context)) {
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveUtils.getGridColumns(context),
                      childAspectRatio: 3.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    padding: ResponsiveUtils.getSafePadding(context),
                    itemCount: cardProvider.cards.length,
                    itemBuilder: (context, index) {
                      final card = cardProvider.cards[index];
                      return CardListItem(card: card);
                    },
                  );
                }

                // Use ListView for mobile
                return ListView.builder(
                  itemCount: cardProvider.cards.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final card = cardProvider.cards[index];
                    return CardListItem(card: card);
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const CardEditorScreen(),
            ),
          );
        },
        tooltip: 'Create Card',
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/card_provider.dart';
import '../../shared/widgets/card_list_item.dart';

/// 桌面端卡片列表界面
class CardListScreen extends ConsumerWidget {
  /// 构造函数
  const CardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听过滤后的卡片列表
    final cards = ref.watch(filteredCardsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的卡片'),
        actions: [
          // 搜索框
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索卡片...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(searchTextProvider.notifier).state = value;
                },
              ),
            ),
          ),
          // 节点管理按钮
          IconButton(
            icon: const Icon(Icons.device_hub),
            tooltip: '节点管理',
            onPressed: () => context.go('/nodes'),
          ),
        ],
      ),
      body: cards.isEmpty
          ? const Center(
              child: Text('还没有卡片，点击右下角的加号创建一个吧！'),
            )
          : ListView.builder(
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return CardListItem(
                  title: card.title,
                  content: card.content,
                  onTap: () => context.go('/cards/${card.id}'),
                  onEdit: () => context.go('/cards/${card.id}/edit'),
                  onDelete: () async {
                    // 显示删除确认对话框
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: const Text('确定要删除这张卡片吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );

                    // 只有当用户明确确认删除（confirm 为 true）时才执行删除操作
                    if (confirm == true) {
                      try {
                        // 删除卡片
                        await ref.read(cardListProvider.notifier).deleteCard(card.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('卡片已删除')),
                          );
                        }
                      } catch (e) {
                        // 处理删除失败的情况
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('删除失败: $e')),
                          );
                        }
                      }
                    }
                    // 不再需要在取消删除时刷新列表，因为列表状态不应该在确认前改变
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/cards/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

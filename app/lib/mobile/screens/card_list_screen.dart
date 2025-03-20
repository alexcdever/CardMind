import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/card_provider.dart';

/// 移动端卡片列表界面
class CardListScreen extends ConsumerWidget {
  /// 构造函数
  const CardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听卡片列表
    final cards = ref.watch(filteredCardListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的卡片'),
        actions: [
          // 新建卡片按钮
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/new');
            },
          ),
        ],
      ),
      // 搜索栏
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索卡片...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(searchTextProvider.notifier).state = value;
              },
            ),
          ),
          // 卡片列表
          Expanded(
            child: cards.isEmpty
                ? const Center(child: Text('没有卡片'))
                : ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Dismissible(
                        key: Key('card-${card.id}'),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16.0),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('删除卡片'),
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
                          ) ?? false;
                        },
                        onDismissed: (direction) async {
                          await ref.read(cardListProvider.notifier).deleteCard(card.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('卡片已删除')),
                            );
                          }
                        },
                        child: ListTile(
                          title: Text(card.title),
                          subtitle: Text(
                            card.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/edit/${card.id}',
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

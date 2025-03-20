import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/card_provider.dart';
import '../../shared/widgets/card_list_item.dart';  // 共享的列表项组件
import '../../shared/screens/card_edit_screen.dart';  // 共享的编辑页面
import '../../shared/screens/card_detail_screen.dart';  // 共享的详情页面

/// 移动端卡片列表界面
class CardListScreen extends ConsumerWidget {
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
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _CardSearchDelegate(ref),
              );
            },
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
                  card: card,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CardDetailScreen(card: card),
                      ),
                    );
                  },
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CardEditScreen(card: card),
                      ),
                    );
                  },
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

                    if (confirm == true) {
                      // 删除卡片
                      await ref.read(cardListProvider.notifier).deleteCard(card.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('卡片已删除')),
                        );
                      }
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CardEditScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 卡片搜索代理类
class _CardSearchDelegate extends SearchDelegate<void> {
  final WidgetRef ref;

  _CardSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    ref.read(searchTextProvider.notifier).state = query;
    final cards = ref.watch(filteredCardListProvider);

    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return CardListItem(
          card: card,
          onTap: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CardDetailScreen(card: card),
              ),
            );
          },
          onEdit: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CardEditScreen(card: card),
              ),
            );
          },
          onDelete: () async {
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

            if (confirm == true) {
              await ref.read(cardListProvider.notifier).deleteCard(card.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('卡片已删除')),
                );
              }
            }
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    ref.read(searchTextProvider.notifier).state = query;
    final cards = ref.watch(filteredCardListProvider);

    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return CardListItem(
          card: card,
          onTap: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CardDetailScreen(card: card),
              ),
            );
          },
          onEdit: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CardEditScreen(card: card),
              ),
            );
          },
          onDelete: () async {
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

            if (confirm == true) {
              await ref.read(cardListProvider.notifier).deleteCard(card.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('卡片已删除')),
                );
              }
            }
          },
        );
      },
    );
  }
}

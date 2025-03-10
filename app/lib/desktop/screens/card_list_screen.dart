import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../shared/domain/models/card.dart' as domain;
import '../providers/card_provider.dart';

/// 桌面端卡片列表页面
class CardListScreen extends ConsumerWidget {
  const CardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchText = ref.watch(searchTextProvider);
    final cards = ref.watch(filteredCardsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题和搜索栏
            Row(
              children: [
                // 标题
                Text(
                  '我的卡片',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 32),
                // 搜索框
                Expanded(
                  child: TextField(
                    onChanged: (value) => ref.read(searchTextProvider.notifier).state = value,
                    decoration: InputDecoration(
                      hintText: '搜索卡片...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => ref.read(searchTextProvider.notifier).state = '',
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 添加按钮
                FilledButton.icon(
                  onPressed: () => context.go('/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('新建卡片'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 卡片列表
            Expanded(
              child: cards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 96,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            searchText.isEmpty ? '还没有添加任何卡片' : '没有找到匹配的卡片',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          if (searchText.isEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              '点击右上角的按钮添加新卡片',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) => _buildCardItem(context, ref, cards[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, WidgetRef ref, domain.Card card) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/add', extra: card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和操作按钮
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 编辑按钮
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.go('/add', extra: card),
                  ),
                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      ref.read(cardListProvider.notifier).deleteCard(card.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('卡片已删除')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 内容预览
              Expanded(
                child: MarkdownBody(
                  data: card.content,
                  shrinkWrap: true,
                  softLineBreak: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

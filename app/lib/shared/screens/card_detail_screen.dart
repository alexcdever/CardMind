import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/card.dart' as domain;
import '../services/card_service.dart';

/// 卡片详情界面
/// 用于查看卡片的完整内容
class CardDetailScreen extends ConsumerStatefulWidget {
  /// 要显示的卡片ID
  final int cardId;

  /// 构造函数
  const CardDetailScreen({
    super.key,
    required this.cardId,
  });

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

/// 卡片详情界面状态
class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  /// 是否正在加载
  bool _isLoading = false;
  /// 当前显示的卡片
  domain.Card? _card;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  /// 加载卡片数据
  Future<void> _loadCard() async {
    setState(() => _isLoading = true);
    try {
      _card = await CardService.instance.getCardById(widget.cardId);
      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_card == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('卡片不存在'),
        ),
        body: const Center(
          child: Text('找不到该卡片'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_card!.title),
        actions: [
          // 编辑按钮
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/edit/${_card!.id}',
              ).then((_) => _loadCard());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              _card!.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            // 时间信息
            Row(
              children: [
                Text(
                  '创建于：${_formatDate(_card!.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Text(
                  '更新于：${_formatDate(_card!.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 内容
            MarkdownBody(
              data: _card!.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyLarge,
                h1: Theme.of(context).textTheme.headlineLarge,
                h2: Theme.of(context).textTheme.headlineMedium,
                h3: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

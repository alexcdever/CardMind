import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/service_provider.dart';
import '../domain/models/card.dart' as domain;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCard();
  }

  /// 加载卡片数据
  Future<void> _loadCard() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      // 使用异步方式获取卡片服务
      final cardService = await ref.read(cardServiceProvider.future);
      // 根据 ID 获取卡片
      final card = await cardService.getCardById(widget.cardId);
      
      if (mounted) {
        setState(() {
          _card = card;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 处理加载过程中的错误
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载卡片失败: $e')),
        );
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
              // 使用 go_router 导航到编辑页面
              context.go('/cards/${_card!.id}/edit');
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

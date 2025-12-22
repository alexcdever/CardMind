// 卡片列表组件，用于显示所有卡片

import 'package:flutter/material.dart';
import '../models/card.dart' as app_card;
import '../api/api_service.dart';

class CardList extends StatefulWidget {
  const CardList({super.key});

  @override
  State<CardList> createState() => _CardListState();
}

class _CardListState extends State<CardList> {
  final ApiService _apiService = ApiService();
  List<app_card.Card> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  // 从API加载卡片
  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 这将在API准备好后实现
      // _cards = await _apiService.getCards();
      _cards = [];
    } catch (e) {
      // 显示错误消息
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载卡片失败: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 删除卡片
  Future<void> _deleteCard(String id) async {
    try {
      await _apiService.deleteCard(id);
      _loadCards();
    } catch (e) {
      // 显示错误消息
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除卡片失败: $e')));
    }
  }

  // 显示删除确认对话框
  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这张卡片吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCard(id);
              },
              child: const Text('删除'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _cards.isEmpty
        ? const Center(child: Text('暂无卡片，点击右下角添加按钮创建'))
        : RefreshIndicator(
            onRefresh: _loadCards,
            child: ListView.builder(
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(card.title),
                    subtitle: Text(
                      card.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatDate(card.updatedAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      _showCardDetails(card);
                    },
                    onLongPress: () {
                      // 显示操作菜单
                      _showCardMenu(card);
                    },
                  ),
                );
              },
            ),
          );
  }

  // 显示卡片详情对话框
  void _showCardDetails(app_card.Card card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(card.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.content),
              const SizedBox(height: 16),
              Text(
                '创建时间: ${_formatDate(card.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '更新时间: ${_formatDate(card.updatedAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  // 显示卡片操作菜单
  void _showCardMenu(app_card.Card card) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑'),
                onTap: () {
                  Navigator.of(context).pop();
                  // 导航到编辑卡片界面
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('删除'),
                textColor: Colors.red,
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteDialog(card.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 将时间戳格式化为可读日期
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

import 'package:cardmind/bridge/models/card.dart' as models;
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/screens/card_editor_screen.dart';
import 'package:cardmind/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

/// Card detail screen showing full card content
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({required this.cardId, super.key});

  final String cardId;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  models.Card? _card;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  Future<void> _loadCard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final cardProvider = context.read<CardProvider>();
    final card = await cardProvider.getCard(widget.cardId);

    setState(() {
      _card = card;
      _error = card == null ? 'Card not found' : null;
      _isLoading = false;
    });
  }

  Future<void> _deleteCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text('Are you sure you want to delete this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final cardProvider = context.read<CardProvider>();
    final success = await cardProvider.deleteCard(widget.cardId);

    if (mounted) {
      if (success) {
        SnackBarUtils.showSuccess(context, 'Card deleted successfully');
        Navigator.pop(context);
      } else {
        setState(() {
          _isLoading = false;
          _error = cardProvider.error ?? 'Failed to delete card';
        });
        SnackBarUtils.showError(context, _error!);
      }
    }
  }

  String _formatDateTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Details'),
        actions: [
          if (_card != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const CardEditorScreen(),
                  ),
                );
                await _loadCard();
              },
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteCard,
              tooltip: 'Delete',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _card == null
          ? const Center(child: Text('Card not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _card!.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${_formatDateTime(_card!.createdAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  Text(
                    'Updated: ${_formatDateTime(_card!.updatedAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const Divider(height: 32),
                  if (_card!.content.isEmpty)
                    const Text(
                      'No content',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    MarkdownBody(data: _card!.content, selectable: true),
                ],
              ),
            ),
    );
  }
}

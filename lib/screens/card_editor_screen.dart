import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

/// Card editor screen for creating and editing cards
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({
    this.cardId,
    super.key,
  });

  final String? cardId;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  bool _showPreview = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.cardId != null) {
      _loadCard();
    }
  }

  Future<void> _loadCard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final cardProvider = context.read<CardProvider>();
    final card = await cardProvider.getCard(widget.cardId!);

    if (card != null) {
      setState(() {
        _titleController.text = card.title;
        _contentController.text = card.content;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = 'Failed to load card';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCard() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      SnackBarUtils.showWarning(context, 'Title cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final cardProvider = context.read<CardProvider>();
    bool success;

    if (widget.cardId != null) {
      success = await cardProvider.updateCard(
        widget.cardId!,
        title: title,
        content: content,
      );
    } else {
      final card = await cardProvider.createCard(title, content);
      success = card != null;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        SnackBarUtils.showSuccess(
          context,
          widget.cardId != null ? 'Card updated successfully' : 'Card created successfully',
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _error = cardProvider.error ?? 'Failed to save card';
        });
        SnackBarUtils.showError(context, _error!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId != null ? 'Edit Card' : 'New Card'),
        actions: [
          IconButton(
            icon: Icon(_showPreview ? Icons.edit : Icons.visibility),
            onPressed: () {
              setState(() {
                _showPreview = !_showPreview;
              });
            },
            tooltip: _showPreview ? 'Edit' : 'Preview',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveCard,
            tooltip: 'Save',
          ),
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
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _showPreview
                            ? Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Markdown(
                                    data: _contentController.text.isEmpty
                                        ? '*Preview will appear here*'
                                        : _contentController.text,
                                  ),
                                ),
                              )
                            : TextField(
                                controller: _contentController,
                                decoration: const InputDecoration(
                                  labelText: 'Content (Markdown supported)',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

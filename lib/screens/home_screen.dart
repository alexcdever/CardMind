import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/screens/card_editor_screen.dart';
import 'package:cardmind/widgets/card_list_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Home screen showing the list of cards
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CardMind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CardProvider>().loadCards();
            },
            tooltip: 'Refresh',
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
            child: ListView.builder(
              itemCount: cardProvider.cards.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final card = cardProvider.cards[index];
                return CardListItem(card: card);
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

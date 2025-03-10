import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/card_provider.dart';
import '../../domain/models/card.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  bool _showAnswer = false;
  int _currentIndex = 0;
  List<FlashCard> _studyCards = [];

  @override
  void initState() {
    super.initState();
    _initializeStudySession();
  }

  void _initializeStudySession() {
    final allCards = ref.read(cardListProvider);
    if (allCards.isEmpty) return;

    // 根据复习时间和难度排序卡片
    _studyCards = List.from(allCards)
      ..sort((a, b) {
        final aPriority = _calculateReviewPriority(a);
        final bPriority = _calculateReviewPriority(b);
        return bPriority.compareTo(aPriority);
      });
  }

  double _calculateReviewPriority(FlashCard card) {
    final daysSinceLastReview =
        DateTime.now().difference(card.lastReviewed).inDays;
    // 优先复习：最近没复习的、难度高的、复习次数少的
    return (daysSinceLastReview * card.difficulty) / (card.reviewCount + 1);
  }

  void _handleReview(double performance) {
    if (_studyCards.isEmpty) return;

    final currentCard = _studyCards[_currentIndex];
    ref.read(cardListProvider.notifier).reviewCard(
          currentCard.id,
          performance,
        );

    setState(() {
      _showAnswer = false;
      if (_currentIndex < _studyCards.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
        _initializeStudySession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardListProvider);

    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('学习'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: const Center(
          child: Text(
            '还没有添加任何卡片\n请先添加一些卡片再开始学习',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final currentCard = _studyCards[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _studyCards.length,
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: Card(
                  elevation: 4,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_showAnswer),
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _showAnswer ? '答案' : '问题',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _showAnswer ? currentCard.back : currentCard.front,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!_showAnswer) ...[
                            const SizedBox(height: 24),
                            const Text(
                              '点击卡片查看答案',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showAnswer) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRatingButton(
                    label: '困难',
                    color: Colors.red,
                    onPressed: () => _handleReview(0.3),
                  ),
                  _buildRatingButton(
                    label: '一般',
                    color: Colors.orange,
                    onPressed: () => _handleReview(0.7),
                  ),
                  _buildRatingButton(
                    label: '简单',
                    color: Colors.green,
                    onPressed: () => _handleReview(1.0),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(label),
    );
  }
}

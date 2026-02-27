import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => const CardsPage()),
                  );
                },
                child: const Text('先本地使用'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const PoolPage(state: PoolState.notJoined()),
                    ),
                  );
                },
                child: const Text('创建或加入数据池'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

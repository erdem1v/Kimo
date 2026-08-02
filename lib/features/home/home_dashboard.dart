import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/game_progress.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/game_widgets.dart';
import '../practice/practice_screen.dart';

/// "Bugün" sekmesi: günlük hedef, hızlı başlama ve konular.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  void _startPractice(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PracticeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('AI YKS Coach'),
      ),
      body: ListenableBuilder(
        listenable: gameProgress,
        builder: (BuildContext context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              const TopStatsBar(),
              const SizedBox(height: 20),
              const Text(
                'Bugünkü hedefine hazır mısın? 💪',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _dailyGoalCard(),
              const SizedBox(height: 14),
              GameButton(
                label: gameProgress.dailyDone == 0
                    ? 'GÜNE BAŞLA'
                    : 'PRATİĞE DEVAM ET',
                icon: Icons.play_arrow_rounded,
                onPressed: () => _startPractice(context),
              ),
              const SizedBox(height: 28),
              const SectionTitle('Konular'),
              const SizedBox(height: 12),
              for (final TopicCard t in MockData.topics)
                _TopicTile(topic: t, onTap: () => _startPractice(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _dailyGoalCard() {
    final bool done = gameProgress.dailyDone >= gameProgress.dailyGoal;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.greenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: gameProgress.dailyProgress,
                    strokeWidth: 7,
                    backgroundColor: Colors.white,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.green),
                  ),
                ),
                Text(
                  '${gameProgress.dailyDone}/${gameProgress.dailyGoal}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.greenDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Günlük Hedef',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  done
                      ? 'Hedefi tamamladın! 🎉'
                      : '${gameProgress.dailyGoal - gameProgress.dailyDone} soru kaldı',
                  style: const TextStyle(color: AppColors.greenDark, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.onTap});

  final TopicCard topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(topic.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    topic.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.subtitle,
                    style:
                        const TextStyle(color: AppColors.inkLight, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  RoundedProgressBar(value: topic.progress, height: 10),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkLight),
          ],
        ),
      ),
    );
  }
}

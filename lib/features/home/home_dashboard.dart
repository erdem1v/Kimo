import 'package:flutter/material.dart';

import '../../data/mistake_repository.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/game_widgets.dart';
import '../practice/practice_screen.dart';

/// "Bugün" sekmesi: günlük hedef, hızlı başlama ve konular.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final bool _remote = SupabaseConfig.isConfigured;

  @override
  void initState() {
    super.initState();
    _loadDue();
  }

  /// Bugün planı gelmiş (kalan) tekrar sayısını yükleyip hedefe yansıtır.
  Future<void> _loadDue() async {
    if (!_remote) return;
    try {
      final List<MistakeEntry> due = await mistakeRepository.dueReviews();
      gameProgress.setDueRemaining(due.length);
    } catch (_) {
      // Sessiz geç; hedef sonra tekrar yüklenebilir.
    }
  }

  Future<void> _startPractice(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PracticeScreen()),
    );
    // Pratikten dönünce hedefi/kalanı tazele.
    await _loadDue();
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
                label: 'HATALARINI ÇÖZ',
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
    final int doneCount = gameProgress.dailyReviewsDone;
    final int target = gameProgress.dailyTarget;
    // "Bugün için iş yok" durumu: kalan da yapılan da yoksa.
    final bool nothingToday = target == 0 && !gameProgress.dailyGoalReached;
    final bool done = gameProgress.dailyGoalReached ||
        (target > 0 && doneCount >= target);
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
                    value: nothingToday ? 1 : gameProgress.dailyProgress,
                    strokeWidth: 7,
                    backgroundColor: Colors.white,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.green),
                  ),
                ),
                (done || nothingToday)
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.greenDark, size: 28)
                    : Text(
                        '$doneCount',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
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
                  'Günlük Tekrar Hedefi',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  done
                      ? 'Tamamladın! 🎉'
                      : nothingToday
                          ? 'Bugün için tekrar yok'
                          : '$doneCount / $target tekrar',
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

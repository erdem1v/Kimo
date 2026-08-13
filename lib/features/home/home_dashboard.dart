import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/mistake_repository.dart';
import '../../data/question_pool_repository.dart';
import '../../data/yks_subjects.dart';
import '../../models/mascot.dart';
import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/mistake_style.dart';
import '../map/curriculum_map_screen.dart';
import '../pool/received_questions_screen.dart';
import '../practice/practice_screen.dart';

/// "Bugün" sekmesi: günlük hedef + sınav (TYT/AYT) ve ders seçimi. Kullanıcı
/// önce sınavı, sonra dersi seçer; o dersin bugünkü tekrarlarını çözer. Günlük
/// 20 hedefi tüm derslerdeki çözümlerin toplamıdır.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final bool _remote = SupabaseConfig.isConfigured;

  List<MistakeEntry> _due = <MistakeEntry>[];
  bool _loading = true;
  String _exam = 'TYT';
  // Arkadaşlarından gelen, henüz çözülmemiş soru sayısı.
  int _incomingCount = 0;

  Color _colorFor(String subject) => subjectColor(subject);

  @override
  void initState() {
    super.initState();
    _loadDue();
    refreshBus.addListener(_onRefresh);
  }

  @override
  void dispose() {
    refreshBus.removeListener(_onRefresh);
    super.dispose();
  }

  /// Sekmeye dönüldüğünde tazele (gelen sorular anında görünsün).
  void _onRefresh() {
    if (mounted && !_loading) _loadDue();
  }

  /// Bugün planı gelmiş TÜM tekrarları yükler (gruplama + günlük hedef için).
  Future<void> _loadDue() async {
    if (!_remote) {
      setState(() => _loading = false);
      return;
    }
    try {
      final List<MistakeEntry> due = await mistakeRepository.dueReviews();
      // Bugün yapılanları DB'den geri yükle (uygulama kapanmışsa sayaç dönsün).
      final int doneToday = await mistakeRepository.reviewedTodayCount();
      final int incoming = await questionPoolRepository.unsolvedCount();
      if (!mounted) return;
      _incomingCount = incoming;
      gameProgress.syncDailyDone(doneToday);
      gameProgress.setDueRemaining(due.length);
      // Günün hatırlatma planını gerçek verilerle kur.
      unawaited(notifications.planDay(
        enabled: userProfile.notifyEnabled,
        mascot: userProfile.mascot ?? Mascot.evHanimi,
        reviewHour: userProfile.reviewHour,
        streakHour: userProfile.streakHour,
        dueCount: due.length,
        streak: gameProgress.currentStreak,
        activeToday: gameProgress.activeToday,
      ));
      setState(() {
        _due = due;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _practice({String? exam, String? subject}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(exam: exam, subject: subject),
      ),
    );
    await _loadDue(); // dönünce hedefi/sayıları tazele
  }

  /// Seçili sınav için ders → bekleyen soru sayısı (sınavı boş kayıtlar dahil).
  Map<String, int> _countsForExam(String exam) {
    final Map<String, int> counts = <String, int>{};
    for (final MistakeEntry e in _due) {
      if (MistakeRepository.matchesFilter(e, exam: exam, subject: e.subject)) {
        counts[e.subject] = (counts[e.subject] ?? 0) + 1;
      }
    }
    return counts;
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
        listenable: Listenable.merge(<Listenable>[gameProgress, userProfile]),
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
              const SizedBox(height: 12),
              _streakCard(),
              if (_remote) ...<Widget>[
                if (_incomingCount > 0) ...<Widget>[
                  const SizedBox(height: 12),
                  _incomingCard(),
                ],
                const SizedBox(height: 12),
                _mapCard(),
              ],
              const SizedBox(height: 24),
              if (!_remote)
                _mockNotice()
              else ...<Widget>[
                _examSelector(),
                const SizedBox(height: 16),
                _subjectsSection(),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Seri kartı: kaç gündür üst üste çözüyorsun, bugün sürdürüldü mü.
  Widget _streakCard() {
    final int streak = gameProgress.currentStreak;
    final bool doneToday = gameProgress.activeToday;
    final bool atRisk = gameProgress.streakAtRisk;

    final Color color = doneToday
        ? AppColors.orange
        : (atRisk ? AppColors.red : AppColors.inkLight);
    final String title = streak == 0
        ? 'Serini başlat'
        : '$streak günlük seri${doneToday ? '' : ' tehlikede'}';
    final String subtitle = streak == 0
        ? 'Bugün bir soru çöz, seri başlasın.'
        : (doneToday
            ? 'Bugünü tamamladın, seri devam ediyor 💪'
            : 'Bugün çözmezsen sıfırlanır.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.5),
      ),
      child: Row(
        children: <Widget>[
          // Seri sönükse alev de sönük.
          Opacity(
            opacity: doneToday || streak == 0 ? 1 : 0.55,
            child: Text(streak == 0 ? '🕯️' : '🔥',
                style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: TextStyle(
                        color: color == AppColors.inkLight
                            ? AppColors.ink
                            : color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.inkLight, fontSize: 12.5)),
              ],
            ),
          ),
          if (doneToday)
            const Icon(Icons.check_circle_rounded, color: AppColors.orange),
        ],
      ),
    );
  }

  /// Arkadaşlarından gelen sorular (yalnızca çözülmemiş varken görünür).
  Widget _incomingCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
              builder: (_) => const ReceivedQuestionsScreen()),
        );
        await _loadDue();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.orange, AppColors.gold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Text('📨', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Arkadaşından $_incomingCount soru',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  const Text('Sana gönderilen soruları çöz.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// Konu haritası girişi.
  Widget _mapCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const CurriculumMapScreen()),
        );
        await _loadDue();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.teal, AppColors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Text('🗺️', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Konu Haritan',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Konu seç, soru çöz, haritanı doldur.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _examSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          for (final String e in const <String>['TYT', 'AYT'])
            Expanded(child: _examTab(e)),
        ],
      ),
    );
  }

  Widget _examTab(String exam) {
    final bool selected = _exam == exam;
    final int total = _countsForExam(exam).values.fold(0, (int a, int b) => a + b);
    // TYT ve AYT'ye ayrı canlı gradyanlar.
    final List<Color> grad = exam == 'TYT'
        ? <Color>[AppColors.blue, AppColors.indigo]
        : <Color>[AppColors.pink, AppColors.purple];
    return GestureDetector(
      onTap: () => setState(() => _exam = exam),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: grad)
              : null,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                      color: grad.last.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              exam,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: selected ? Colors.white : AppColors.inkLight,
              ),
            ),
            if (total > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.30)
                      : AppColors.line,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: selected ? Colors.white : AppColors.inkLight,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subjectsSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final Map<String, int> counts = _countsForExam(_exam);
    // Tüm dersler sabit sırada; listede olmayan (ör. AI'nın ürettiği) ekstra
    // dersler varsa sona eklenir. Soru olmasa da hepsi gösterilir.
    final List<String> subjects =
        List<String>.of(YksSubjects.forExam(userProfile.curriculum, _exam));
    for (final String s in counts.keys) {
      if (!subjects.contains(s)) subjects.add(s);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionTitle('Ders seç'),
        const SizedBox(height: 12),
        for (final String s in subjects) _subjectTile(s, counts[s] ?? 0),
      ],
    );
  }

  Widget _subjectTile(String subject, int count) {
    final bool active = count > 0;
    final Color color = _colorFor(subject);
    return GestureDetector(
      onTap: active ? () => _practice(exam: _exam, subject: subject) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.09) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.30) : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.20)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(subjectEmoji(subject),
                  style: TextStyle(
                      fontSize: 24,
                      color: active ? null : Colors.black.withValues(alpha: 0.35))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    subject,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: active ? AppColors.ink : AppColors.inkLight),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active ? '$count soru seni bekliyor' : 'Bekleyen soru yok',
                    style: TextStyle(
                        color: active ? color : AppColors.inkLight,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
            _subjectTrailing(count, active, color),
          ],
        ),
      ),
    );
  }

  Widget _subjectTrailing(int count, bool active, Color color) {
    if (!active) {
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF0F0F0),
          shape: BoxShape.circle,
        ),
        child: const Text('0',
            style: TextStyle(
                color: AppColors.inkLight,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Çöz',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          SizedBox(width: 2),
          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
        ],
      ),
    );
  }

  /// Supabase yapılandırılmadığında (mock) basit giriş.
  Widget _mockNotice() {
    return Column(
      children: <Widget>[
        const Text('Demo modunda tüm hatalar birlikte çözülür.',
            style: TextStyle(color: AppColors.inkLight, fontSize: 13)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _practice(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('HATALARINI ÇÖZ',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
      ],
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

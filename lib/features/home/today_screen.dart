import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/daily_state_repository.dart';
import '../../data/mistake_repository.dart';
import '../../data/question_send_repository.dart';
import '../../data/yks_subjects.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/mascot.dart';
import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/mistake_style.dart';
import '../capture/capture_screen.dart';
import '../inbox/inbox_screen.dart';
import '../practice/practice_screen.dart';

/// 3c + 3d — "Bugün".
///
/// Tek ekran iki durumu karşılıyor: arşiv boşsa (3c) tek bir davet, doluysa
/// (3d) HUD + günün çemberi + ders listesi. İkisini ayrı ekran yapmak, boş
/// durumdan dolu duruma geçişte navigasyonu değiştirmek demekti.
///
/// **Havuz kartı yok.** Mockup'ta sıfır-veri ekranında "Havuzdan 5 soru çöz"
/// diye ikinci bir yol vardı; havuz bu sürümde arayüzden çıktığı için tek yol
/// kaldı: kendi yanlışını çek.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final bool _remote = SupabaseConfig.isConfigured;
  final KimoController _kimo = KimoController();

  List<MistakeEntry> _due = <MistakeEntry>[];
  bool _loading = true;
  bool _failed = false;
  String _exam = 'TYT';

  /// Arkadaşlarından gelen, henüz çözülmemiş soru sayısı.
  int _incoming = 0;

  /// Sunucudaki günlük durum (can, elmas, XP, seri). `null` = okunamadı;
  /// o zaman ilgili HUD hapı GÖSTERİLMİYOR.
  DailyState? _state;

  /// Arşivde hiç kayıt var mı. `_due` boş olabilir ama arşiv dolu olabilir
  /// (bugün tekrarı olmayan sorular); ikisi farklı ekran.
  bool _archiveEmpty = false;

  @override
  void initState() {
    super.initState();
    _load();
    refreshBus.addListener(_onRefresh);
  }

  @override
  void dispose() {
    refreshBus.removeListener(_onRefresh);
    _kimo.dispose();
    super.dispose();
  }

  void _onRefresh() {
    if (mounted && !_loading) _load();
  }

  Future<void> _load() async {
    if (!_remote) {
      setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _failed = false);
    try {
      // Beş bağımsız sorgu PARALEL. Sırayla beklemek uygulamanın ilk ekranını
      // beş gidiş-dönüş kadar geciktiriyordu; aralarında hiçbir bağımlılık yok.
      // `Future.wait` hepsini bekliyor: biri patlarsa diğerleri sahipsiz
      // kalmıyor (elle zincirlenmiş `await`lerde yakalanmamış hata olurdu).
      final List<Object?> parts = await Future.wait<Object?>(<Future<Object?>>[
        mistakeRepository.dueReviews(),
        mistakeRepository.reviewedTodayCount(),
        questionSendRepository.unsolvedCount(),
        dailyStateRepository.read(),
        mistakeRepository.totalCount(),
      ]);
      final List<MistakeEntry> due = parts[0]! as List<MistakeEntry>;
      final int doneToday = parts[1]! as int;
      final int incoming = parts[2]! as int;
      final DailyState? state = parts[3] as DailyState?;
      final int archived = parts[4]! as int;
      if (!mounted) return;

      gameProgress.syncDailyDone(doneToday);
      gameProgress.setDueRemaining(due.length);
      if (state != null) {
        gameProgress.applyServerTotals(<String, dynamic>{
          'xp': state.xp,
          'weekly_xp': state.weeklyXp,
          'streak': state.streak,
          'league': state.league.dbValue,
        });
      }

      unawaited(
        notifications.planDay(
          enabled: userProfile.notifyEnabled,
          mascot: userProfile.mascot ?? Mascot.evHanimi,
          dueCount: due.length,
          streak: gameProgress.currentStreak,
          activeToday: gameProgress.activeToday,
        ),
      );

      setState(() {
        _due = due;
        _incoming = incoming;
        _state = state;
        _archiveEmpty = archived == 0;
        _loading = false;
      });
    } catch (e) {
      // Sessizce boş bir panoya düşmüyoruz: yüklenemediğini kullanıcı görüyor
      // ve yeniden deneyebiliyor. Aksi hâlde "bugün hiç tekrarın yok" ile
      // "veri gelmedi" ayırt edilemez olurdu.
      debugPrint('bugün yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _practice({String? exam, String? subject}) async {
    sound.tap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(exam: exam, subject: subject),
      ),
    );
    await _load();
  }

  Future<void> _capture() async {
    sound.tap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
    );
    await _load();
  }

  Future<void> _openInbox() async {
    sound.tap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const InboxScreen()),
    );
    await _load();
  }

  /// Seçili sınav için ders → bekleyen soru sayısı.
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
    final KimoColors c = context.c;
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          // Dinleyici DAR: yalnızca ilerleme ve profil. Tema değişimi
          // (AppSettings) bu ağacı yeniden kurmuyor.
          listenable: Listenable.merge(<Listenable>[gameProgress, userProfile]),
          builder: (BuildContext context, _) => _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final L10n l = L10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            message: l.errorGeneric,
            action: KimoButton(
              label: l.actionRetry,
              expand: false,
              onPressed: _load,
            ),
          ),
        ),
      );
    }
    if (_remote && _archiveEmpty) return _emptyArchive(context, l);
    return _dashboard(context, l);
  }

  // ------------------------------------------------------------------- 3c

  /// Sıfır veri: tek yol var, o da kendi yanlışını çekmek.
  Widget _emptyArchive(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Kimo(
                    size: 150,
                    controller: _kimo,
                    onTap: () => _kimo.trigger(KimoReaction.tap),
                    semanticLabel: 'Kimo',
                  ),
                  const SizedBox(height: Gap.xl),
                  Text(
                    l.todayEmptyTitle,
                    textAlign: TextAlign.center,
                    style: t.title,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    l.todayEmptyBody,
                    textAlign: TextAlign.center,
                    style: t.body,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Gap.screen, Gap.md, Gap.screen, Gap.screen),
          child: KimoButton(
            label: l.todayEmptyAction,
            icon: const KimoIcon(KimoIcons.camera, size: 20),
            onPressed: _capture,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- 3d

  Widget _dashboard(BuildContext context, L10n l) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Gap.screen, Gap.sm, Gap.screen, Gap.section),
        children: <Widget>[
          _hud(context, l),
          const SizedBox(height: Gap.xl),
          _goalRing(context, l),
          if (gameProgress.streakAtRisk) ...<Widget>[
            const SizedBox(height: Gap.md),
            _streakWarning(context, l),
          ],
          if (_incoming > 0) ...<Widget>[
            const SizedBox(height: Gap.md),
            _incomingCard(context, l),
          ],
          if (!_remote) ...<Widget>[
            const SizedBox(height: Gap.xl),
            _mockNotice(context, l),
          ] else ...<Widget>[
            const SizedBox(height: Gap.xl),
            SegmentedTabs(
              labels: const <String>['TYT', 'AYT'],
              selectedIndex: _exam == 'AYT' ? 1 : 0,
              onChanged: (int i) {
                sound.tap();
                setState(() => _exam = i == 1 ? 'AYT' : 'TYT');
              },
            ),
            const SizedBox(height: Gap.lg),
            _subjects(context, l),
          ],
        ],
      ),
    );
  }

  /// Üst şerit: seri · can · elmas.
  ///
  /// Can ve elmas yalnızca sunucudan OKUNABİLDİYSE görünüyor. Okunamadığında
  /// sıfır göstermek, gerçekten sıfır olmasıyla ayırt edilemezdi.
  Widget _hud(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final DailyState? s = _state;
    final int streak = gameProgress.currentStreak;
    final bool warm = gameProgress.activeToday || streak == 0;

    return Row(
      children: <Widget>[
        HudPill(
          icon: const KimoIcon(KimoIcons.flame),
          background: c.actionTint,
          foreground: warm ? c.actionText : c.inkMuted,
          value: '$streak',
          semanticLabel: l.hudStreakLabel(streak),
        ),
        if (s != null) ...<Widget>[
          const SizedBox(width: Gap.sm),
          HudPill(
            icon: const KimoIcon(KimoIcons.heart),
            background: c.honeyTint,
            foreground: c.honeyText,
            value: '${s.aiLeft}',
            onTap: () => _showCreditSheet(context, l, s),
            semanticLabel: l.creditLeft(s.aiLeft),
          ),
          const SizedBox(width: Gap.sm),
          HudPill(
            icon: const KimoIcon(KimoIcons.gem),
            background: c.mintTint,
            foreground: c.mintText,
            value: '${s.gems}',
            semanticLabel: l.hudGemsLabel(s.gems),
          ),
        ],
        const Spacer(),
        if (s != null)
          Text(l.sessionLevel(s.level), style: t.caption.copyWith(color: c.inkMuted)),
      ],
    );
  }

  /// Can hapına dokununca açılan açıklama. Geri sayım YOK.
  void _showCreditSheet(BuildContext context, L10n l, DailyState s) {
    sound.tap();
    final KimoTypography t = context.t;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.screen,
          Gap.screen,
          Gap.screen + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.creditLeft(s.aiLeft), style: t.section),
            const SizedBox(height: Gap.sm),
            Text(
              s.hasAi ? l.creditExplain(s.aiQuota) : l.creditExhaustedBody,
              style: t.body,
            ),
          ],
        ),
      ),
    );
  }

  /// Günün çemberi: 20 dilim, ortada Kimo.
  Widget _goalRing(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int done = gameProgress.dailyReviewsDone;
    final int target = gameProgress.dailyTarget;
    final bool nothing = target == 0 && !gameProgress.dailyGoalReached;
    final bool reached = gameProgress.dailyGoalReached || (target > 0 && done >= target);

    return KimoCard(
      padding: const EdgeInsets.all(Gap.screen),
      child: Row(
        children: <Widget>[
          SegmentRing(
            // Dilim sayısı GERÇEK hedefe eşit; tasarımdaki 20 rakamı
            // `GameProgress.dailyReviewCap` ile aynı ama hedef günün gerçek
            // yüküne göre daha küçük olabiliyor.
            total: target == 0 ? GameProgress.dailyReviewCap : target,
            filled: done,
            size: 92,
            filledColor: reached ? c.mint : c.action,
            child: Kimo(
              size: 58,
              controller: _kimo,
              onTap: () => _kimo.trigger(KimoReaction.tap),
            ),
          ),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nothing
                      ? l.todayNothingDue
                      : reached
                          ? l.todayGoalDone
                          : l.todayGoalTitle,
                  style: t.section,
                ),
                const SizedBox(height: Gap.xxs),
                Text(
                  nothing
                      ? l.todayNothingDueBody
                      : l.practiceProgress(done, target),
                  style: t.body.copyWith(color: c.inkSecondary),
                ),
                if (!nothing && !reached) ...<Widget>[
                  const SizedBox(height: Gap.md),
                  KimoButton(
                    label: l.todayStart,
                    expand: false,
                    minHeight: Sizes.rowMin,
                    onPressed: () => _practice(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seri uyarısı — yalnızca gerçekten risk varken.
  Widget _streakWarning(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      color: c.honeyTint,
      elevated: false,
      child: Row(
        children: <Widget>[
          KimoIcon(KimoIcons.flame, size: 22, color: c.honey),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              l.todayStreakAtRisk(gameProgress.currentStreak),
              style: t.body.copyWith(color: c.honeyText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomingCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      color: c.actionTint,
      elevated: false,
      onTap: _openInbox,
      child: Row(
        children: <Widget>[
          KimoIcon(KimoIcons.notebook, size: 22, color: c.actionText),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              l.todayIncoming(_incoming),
              style: t.bodyStrong.copyWith(color: c.actionText),
            ),
          ),
          KimoIcon(KimoIcons.back, size: 18, color: c.actionText),
        ],
      ),
    );
  }

  Widget _subjects(BuildContext context, L10n l) {
    final Map<String, int> counts = _countsForExam(_exam);
    final List<String> subjects = List<String>.of(
      YksSubjects.forExam(userProfile.curriculum, _exam),
    );
    for (final String s in counts.keys) {
      if (!subjects.contains(s)) subjects.add(s);
    }
    // Bekleyeni olan dersler üstte; eşitlikte müfredat sırası korunuyor.
    // `List.sort` KARARLI DEĞİL: eşitlikte 0 döndürmek, sıfır bekleyenli
    // dersleri her yeniden çizimde farklı sıraya sokabilirdi.
    final Map<String, int> order = <String, int>{
      for (int i = 0; i < subjects.length; i++) subjects[i]: i,
    };
    subjects.sort((String a, String b) {
      final int cmp = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      return cmp != 0 ? cmp : order[a]!.compareTo(order[b]!);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: l.todaySubjects),
        const SizedBox(height: Gap.md),
        for (final String s in subjects) ...<Widget>[
          _subjectTile(context, s, counts[s] ?? 0),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }

  Widget _subjectTile(BuildContext context, String subject, int count) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool active = count > 0;
    final Color accent = subjectColor(subject);

    return KimoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.md),
      radius: Radii.tile,
      elevated: active,
      color: active ? null : c.sunken,
      onTap: active ? () => _practice(exam: _exam, subject: subject) : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: active ? accent : c.border,
              borderRadius: Radii.all(4),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              subject,
              style: active
                  ? t.label
                  : t.label.copyWith(color: c.inkMuted),
            ),
          ),
          if (active)
            StatusBadge(label: '$count', tone: BadgeTone.pending)
          else
            Text(l10nDash, style: t.caption.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }

  Widget _mockNotice(BuildContext context, L10n l) {
    return Column(
      children: <Widget>[
        EmptyState(
          message: l.todayMockNotice,
          action: KimoButton(
            label: l.todayStart,
            expand: false,
            onPressed: () => _practice(),
          ),
        ),
      ],
    );
  }
}

/// Sayı yerine geçen tire — çeviriye gerek yok, her dilde aynı.
const String l10nDash = '—';

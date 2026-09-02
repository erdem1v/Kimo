import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mistake_repository.dart';
import '../../data/progress_repository.dart';
import '../../data/submission_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/mistake_store.dart';
import '../reviews/domain/review_scheduler.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/drawing_canvas.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/mistake_photo.dart';
import 'answer_reveal.dart';
import 'session_end_screen.dart';
import 'session_result.dart';

/// 3g — Pratik.
///
/// Soru büyük; kalem ve silgi doğrudan sorunun üstünde. Şıkkı olan sorularda
/// harfe dokunulur ve **doğruyu sunucu belirler**; şıksız (elle girilmiş,
/// eski) sorularda öz-değerlendirme yolu korunur.
///
/// Cevaptan sonra ekran DEĞİŞMİYOR: soru yerinde kalıyor, altından [AnswerReveal]
/// paneli açılıyor. Mockup burada ayrı bir tam ekran gösteriyordu; soruyu
/// ekrandan kaldırmak, "neden yanlış yaptım" sorusunu cevaplamayı imkânsız
/// kılıyordu.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.exam, this.subject});

  /// Seçili sınav (TYT/AYT) ve ders. Verilirse yalnızca o dersin tekrarları
  /// çözdürülür; null ise tüm tekrarlar gelir.
  final String? exam;
  final String? subject;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final bool _remote = SupabaseConfig.isConfigured;

  List<MistakeEntry> _items = <MistakeEntry>[];
  bool _loading = true;
  bool _failed = false;
  int _index = 0;
  int? _selectedOption;

  /// Cevap verildiyse sonucu; `null` ise soru hâlâ açık.
  AnswerOutcome? _revealed;

  /// Bu oturuma başlarken bugün zaten yapılmış tekrar sayısı (kaldığın yerden
  /// devam için sayaç oturuma değil, günün geneline bağlanır).
  int _doneAtStart = 0;
  bool _goalClaimed = false;

  // ----------------------------------------------------------- oturum tahtası
  int _solved = 0;
  int _correct = 0;
  int _longestCombo = 0;
  int _xpGained = 0;
  int _gemsAwarded = 0;
  int _comboNow = 0;
  final int _streakAtStart = gameProgress.streak;

  /// Gönderilmeyi bekleyen cevap sayısı (çevrimdışıyken birikir).
  ///
  /// Sessiz bir kuyruk, bu task'ın baştan beri kaçındığı kalıp: kullanıcı
  /// cevabının bir yerde beklediğini görebilmeli.
  int _pendingSubmissions = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshPending();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      List<MistakeEntry> items =
          _remote ? await mistakeRepository.dueReviews() : mistakeStore.items;
      final String? subject = widget.subject;
      final String? exam = widget.exam;
      if (subject != null) {
        items = items
            .where((MistakeEntry e) => MistakeRepository.matchesFilter(
                  e,
                  exam: exam ?? '',
                  subject: subject,
                ))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      if (_remote) {
        _doneAtStart = gameProgress.dailyReviewsDone;
        // Günlük hedef TÜM derslerin toplamıdır; filtreli girişte kalan sayısını
        // ezmeyelim (onu ana ekran tüm tekrarlara göre belirler).
        if (subject == null) gameProgress.setDueRemaining(items.length);
        _goalClaimed = gameProgress.dailyTarget > 0 &&
            _doneAtStart >= gameProgress.dailyTarget;
      } else {
        _doneAtStart = 0;
      }
    } catch (e) {
      debugPrint('tekrarlar yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  MistakeEntry get _current => _items[_index];
  bool get _isLast => _index >= _items.length - 1;
  int get _target => _remote ? gameProgress.dailyTarget : _items.length;
  int get _base => _remote ? _doneAtStart : 0;
  bool _hasPhoto(MistakeEntry e) => e.imageBytes != null || e.photoPath != null;

  // ------------------------------------------------------------------ cevap

  void _pickOption(int i) {
    if (_revealed != null) return;
    setState(() => _selectedOption = i);
    _answer(correct: i == _current.correctIndex, choice: i);
  }

  void _selfGrade(bool correct) {
    if (_revealed != null) return;
    _answer(correct: correct, choice: null);
  }

  /// Cevabı işler.
  ///
  /// Panel HEMEN açılıyor (ödül rozetleri olmadan), sunucunun döndüğü gerçek
  /// XP ve çarpan gelince rozetler ekleniyor. Ağı beklemek, çevrimdışında
  /// ekranı süresiz kilitlerdi; ödülü tahmin etmek ise verilmemiş bir XP'yi
  /// verilmiş gibi göstermek olurdu.
  Future<void> _answer({required bool correct, required int? choice}) async {
    final MistakeEntry entry = _current;

    if (correct) {
      sound.correct();
      HapticFeedback.mediumImpact();
    } else {
      sound.wrong();
      HapticFeedback.heavyImpact();
    }

    // Yerel plan hesabı her durumda yapılıyor: panelin "yarın yeniden
    // soracağım" metni ağdan bağımsız.
    ReviewOutcome plan = const ReviewScheduler().review(
      step: entry.step,
      lapses: entry.lapses,
      correct: correct,
      reviewedOn: DateTime.now(),
    );
    bool scheduleFailed = false;

    setState(() {
      _solved++;
      if (correct) _correct++;
      _revealed = AnswerOutcome(
        correct: correct,
        nextIntervalDays: _daysUntil(plan.nextReviewDate),
        mastered: plan.mastered,
      );
    });

    gameProgress.recordReview();

    if (!_remote) {
      // Yerel (mock) mod: tek gerçek XP kaynağı GameProgress.
      gameProgress.addXp(GameProgress.xpPerCorrect);
      if (correct) _xpGained += GameProgress.xpPerCorrect;
      return;
    }

    try {
      plan = await mistakeRepository.submitReview(entry, correct);
    } catch (e) {
      debugPrint('tekrar planı yazılamadı: $e');
      scheduleFailed = true;
    }

    final String? id = entry.id;
    Map<String, dynamic>? totals;
    if (id != null) {
      totals = await progressRepository.submitReview(
        mistakeId: id,
        correct: correct,
        choice: choice,
      );
      // mounted KONTROLU YOK: gameProgress küresel bir tekil, BuildContext
      // kullanmıyor. Kullanıcı ekrandan çıkınca sunucunun döndüğü gerçek
      // toplamları atmak, iyimser yerel değeri düzeltilmeden bırakırdı.
      gameProgress.applyServerTotals(totals);
    }

    final int? awarded = (totals?['xp_awarded'] as num?)?.toInt();
    final int? combo = (totals?['combo'] as num?)?.toInt();
    final int? multiplier = (totals?['multiplier'] as num?)?.toInt();
    // Sunucu doğruluğu kendisi hesaplamış olabilir (şıklı sorular). Panelin
    // başlığı bu yüzden sunucunun sözüne göre düzeltiliyor.
    final bool serverCorrect = (totals?['correct'] as bool?) ?? correct;

    _xpGained += awarded ?? 0;
    if (combo != null && combo > _longestCombo) _longestCombo = combo;
    _comboNow = combo ?? _comboNow;

    await _refreshPending();
    if (!mounted) return;
    setState(() {
      if (serverCorrect != correct) {
        _correct += serverCorrect ? 1 : -1;
      }
      _revealed = AnswerOutcome(
        correct: serverCorrect,
        nextIntervalDays: _daysUntil(plan.nextReviewDate),
        mastered: plan.mastered,
        xpAwarded: awarded,
        multiplier: multiplier,
        scheduleFailed: scheduleFailed,
      );
    });
  }

  int _daysUntil(DateTime date) {
    final DateTime today = DateTime.now();
    final int days = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return days < 1 ? 1 : days;
  }

  /// Bekleyen gönderim sayısını tazeler (kuyruk diskten okunur).
  Future<void> _refreshPending() async {
    if (!_remote) return;
    final int n = await submissionQueue.loadPendingCount();
    if (!mounted || n == _pendingSubmissions) return;
    setState(() => _pendingSubmissions = n);
  }

  // ---------------------------------------------------------------- ilerleme

  Future<void> _advance() async {
    final int next = _index + 1;
    final bool allDone = next >= _items.length;
    final bool reachedGoal =
        !_goalClaimed && _target > 0 && (_base + next) >= _target;

    if (reachedGoal) {
      _goalClaimed = true;
      // Ödülü asıl veren sunucu; günde bir kez olduğunu daily_goal_date
      // garanti ediyor. Ağ yoksa kuyruğa alınır.
      final bool awarded =
          gameProgress.claimDailyGoal(GameProgress.dailyGoalBonus);
      if (awarded && _remote) {
        final Map<String, dynamic>? totals =
            await progressRepository.claimDailyGoal();
        gameProgress.applyServerTotals(totals);
        _xpGained += (totals?['xp_awarded'] as num?)?.toInt() ?? 0;
        _gemsAwarded = (totals?['gems_awarded'] as num?)?.toInt() ?? 0;
        await _refreshPending();
      }
      if (!mounted) return;
      setState(() => _index = next);
      await _openSessionEnd(goalReached: true);
      return;
    }

    if (allDone) {
      setState(() => _index = next);
      await _openSessionEnd(goalReached: false);
      return;
    }

    setState(() {
      _index = next;
      _selectedOption = null;
      _revealed = null;
    });
  }

  Future<void> _openSessionEnd({required bool goalReached}) async {
    final int remaining = _items.length - _index;
    final SessionResult result = SessionResult(
      solved: _solved,
      correct: _correct,
      firstTryCorrect: _correct,
      longestCombo: _longestCombo,
      xpGained: _xpGained,
      gemsAwarded: _gemsAwarded,
      streak: gameProgress.streak,
      streakGrew: gameProgress.streak > _streakAtStart,
      totalXp: gameProgress.xp,
      remaining: remaining,
      goalReached: goalReached,
    );

    // Ekran kendi rotasını `true` ile kapatıyor. Kapanışı buradan yönetmek,
    // pratik ekranının context'iyle yanlış rotayı kapatma riskini doğururdu.
    final bool extra = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => SessionEndScreen(
              result: result,
              canContinue: remaining > 0,
            ),
          ),
        ) ??
        false;
    if (!mounted) return;
    if (extra) {
      setState(() {
        _selectedOption = null;
        _revealed = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // -------------------------------------------------------------------- yapı

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(bottom: false, child: _body(context)),
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
            message: l.practiceLoadFailed,
            action: KimoButton(
              label: l.actionRetry,
              expand: false,
              onPressed: _load,
            ),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      final String? subject = widget.subject;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            illustration: const Kimo(size: 120, mood: KimoMood.calm),
            message: subject == null
                ? '${l.practiceEmptyTitle}\n${l.practiceEmptyBody}'
                : l.practiceEmptySubjectBody(subject),
            action: KimoButton(
              label: l.actionClose,
              expand: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      );
    }
    // _index listeyi aştıysa oturum sonu ekranı açılmış demektir; bir kare
    // boyunca boş göster, aşım hatası vermesin.
    if (_index >= _items.length) return const SizedBox.shrink();
    return _practiceView(context, l);
  }

  Widget _practiceView(BuildContext context, L10n l) {
    final MistakeEntry e = _current;
    return Column(
      children: <Widget>[
        _topBar(context, l),
        if (_pendingSubmissions > 0) _pendingBanner(context, l),
        _questionHeader(context, l, e),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.screen, Gap.sm),
            child: DrawingCanvas(
              key: ValueKey<int>(_index),
              background: _questionBackground(e),
            ),
          ),
        ),
        if (_revealed != null)
          AnswerReveal(
            outcome: _revealed!,
            isLast: _isLast,
            onContinue: _advance,
          )
        else
          Padding(
            padding: EdgeInsets.fromLTRB(
              Gap.screen,
              Gap.sm,
              Gap.screen,
              Gap.md + MediaQuery.of(context).padding.bottom,
            ),
            child: _answerSection(context, l, e),
          ),
      ],
    );
  }

  Widget _topBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int done = _base + _index;
    final double value =
        _target == 0 ? 1 : (done / _target).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.screen, Gap.sm),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: KimoIcon(KimoIcons.close, color: c.ink),
            tooltip: l.actionClose,
          ),
          Expanded(child: KimoProgressBar(value: value)),
          const SizedBox(width: Gap.md),
          Text(
            _goalClaimed
                ? l.practiceExtra(done - _target + 1)
                : l.practiceProgress(done + 1, _target),
            style: t.numberSmall,
          ),
          // Çarpan rozeti yalnızca sunucu gerçekten >1 döndürdüğünde.
          if (_comboNow > 1) ...<Widget>[
            const SizedBox(width: Gap.sm),
            StatusBadge(
              label: l.practiceCombo(_comboNow > 5 ? 5 : _comboNow),
              tone: BadgeTone.pending,
            ),
          ],
        ],
      ),
    );
  }

  /// "Cevapların bekliyor" şeridi. Kuyruk sessiz kalmamalı.
  Widget _pendingBanner(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      width: double.infinity,
      color: c.honeyTint,
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.screen, vertical: Gap.sm),
      child: Row(
        children: <Widget>[
          KimoIcon(KimoIcons.lock, size: 16, color: c.honeyText),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              l.practiceQueuedCount(_pendingSubmissions),
              style: t.caption.copyWith(color: c.honeyText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionHeader(BuildContext context, L10n l, MistakeEntry e) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.xs, Gap.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${e.subject} · ${e.concept}',
                  overflow: TextOverflow.ellipsis,
                  style: t.label,
                ),
                // "Kaçıncı kez karşında" — `step` alanından türüyor, yeni bir
                // sayaç eklenmedi.
                Text(
                  l.practiceTimesSeen(e.step + 1),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          if (e.isLeech)
            StatusBadge(label: l.mistakeLeechBadge, tone: BadgeTone.alert),
          if (e.note.isNotEmpty)
            IconButton(
              onPressed: () => _showNote(context, l, e),
              icon: KimoIcon(KimoIcons.notebook, size: 20, color: c.inkMuted),
              tooltip: l.practiceNote,
            ),
          if (_hasPhoto(e))
            IconButton(
              onPressed: () => _showPhoto(context, e),
              icon: KimoIcon(KimoIcons.play, size: 20, color: c.inkMuted),
              tooltip: l.practiceFullscreen,
            ),
        ],
      ),
    );
  }

  /// Çizim katmanının arka planı: soru fotoğrafı (yoksa metin).
  Widget _questionBackground(MistakeEntry e) {
    if (e.imageBytes != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Image.memory(e.imageBytes!, fit: BoxFit.contain),
        ),
      );
    }
    if (e.photoPath != null) {
      return MistakePhoto(path: e.photoPath!, fit: BoxFit.contain);
    }
    return _noPhotoText(e);
  }

  Widget _noPhotoText(MistakeEntry e) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(e.concept, textAlign: TextAlign.center, style: t.heading),
            if (e.note.isNotEmpty) ...<Widget>[
              const SizedBox(height: Gap.sm),
              Text(
                e.note,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: c.inkSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showNote(BuildContext context, L10n l, MistakeEntry e) {
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
            Text(l.practiceNote, style: t.section),
            const SizedBox(height: Gap.sm),
            Text(e.note, style: t.body),
          ],
        ),
      ),
    );
  }

  void _showPhoto(BuildContext context, MistakeEntry e) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: e.imageBytes != null
                        ? Image.memory(e.imageBytes!, fit: BoxFit.contain)
                        : MistakePhoto(path: e.photoPath!, fit: BoxFit.contain),
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const KimoIcon(KimoIcons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerSection(BuildContext context, L10n l, MistakeEntry e) {
    if (e.hasOptions && e.correctIndex != null) return _options(context, e);
    return _selfGradeButtons(context, l);
  }

  Widget _selfGradeButtons(BuildContext context, L10n l) {
    return Row(
      children: <Widget>[
        Expanded(
          child: KimoButton(
            label: l.practiceSelfWrong,
            kind: KimoButtonKind.tertiary,
            onPressed: () => _selfGrade(false),
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: KimoButton(
            label: l.practiceSelfCorrect,
            onPressed: () => _selfGrade(true),
          ),
        ),
      ],
    );
  }

  Widget _options(BuildContext context, MistakeEntry e) {
    final int n = e.options!.length;
    return Row(
      children: <Widget>[
        for (int i = 0; i < n; i++) ...<Widget>[
          Expanded(child: _letterButton(context, e, i)),
          if (i != n - 1) const SizedBox(width: Gap.sm),
        ],
      ],
    );
  }

  Widget _letterButton(BuildContext context, MistakeEntry e, int i) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final String label = e.options![i].label.isNotEmpty
        ? e.options![i].label
        : String.fromCharCode(65 + i);

    Color bg = c.sunken;
    Color fg = c.ink;
    if (_revealed != null) {
      if (i == e.correctIndex) {
        bg = c.mint;
        fg = c.onAction;
      } else if (i == _selectedOption) {
        // Seçilen yanlış şık BAL rengiyle işaretleniyor, mercanla değil:
        // yanlış cevap bu üründe bir hata bildirimi değil.
        bg = c.honey;
        fg = c.onAction;
      } else {
        fg = c.inkMuted;
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealed != null ? null : () => _pickOption(i),
      child: AnimatedContainer(
        duration: Motion.press,
        height: Sizes.buttonMin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.all(Radii.pill),
        ),
        child: Text(label, style: t.numberMedium.copyWith(color: fg)),
      ),
    );
  }
}

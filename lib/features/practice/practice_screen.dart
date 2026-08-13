import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mistake_repository.dart';
import '../../data/progress_repository.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/mistake_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/drawing_canvas.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_photo.dart';

/// Günlük pratik: kullanıcının eklediği hatalı soruları tek tek çözdürür.
/// Soru büyük gösterilir; kalem/silgi doğrudan sorunun üstünde kullanılır.
/// Öğrenci çözüp kendini "Doğru çözdüm / Bilemedim" ile değerlendirir.
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
  String? _error;
  int _index = 0;
  int _correct = 0;
  // Bu oturuma başlarken bugün zaten yapılmış tekrar sayısı (kaldığın yerden
  // devam için sayaç oturuma değil, günün geneline bağlanır).
  int _doneAtStart = 0;
  bool _completed = false;
  int? _selectedOption;
  bool _answered = false;
  bool _showGoal = false;
  bool _goalClaimed = false;
  int _bonusAwarded = 0;

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));

  static const List<Color> _confettiColors = <Color>[
    AppColors.green,
    AppColors.gold,
    AppColors.blue,
    AppColors.purple,
    AppColors.red,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<MistakeEntry> items =
          _remote ? await mistakeRepository.dueReviews() : mistakeStore.items;
      // Sınav/ders filtresi verildiyse yalnızca o dersin tekrarları.
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
      if (_global) {
        // Bugün zaten yapılanları koru (kaldığın yerden devam).
        _doneAtStart = gameProgress.dailyReviewsDone;
        // Günlük hedef TÜM derslerin toplamıdır; filtreli girişte kalan sayısını
        // ezmeyelim (onu dashboard tüm tekrarlara göre belirler).
        if (subject == null) gameProgress.setDueRemaining(items.length);
        // Bugünkü hedef zaten dolmuşsa (ör. yeniden açılış) tekrar kutlama ve
        // bonus verme; "Ekstra" modunda devam et.
        _goalClaimed = gameProgress.dailyTarget > 0 &&
            _doneAtStart >= gameProgress.dailyTarget;
      } else {
        _doneAtStart = 0;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Sorular yüklenemedi.';
        _loading = false;
      });
    }
  }

  MistakeEntry get _current => _items[_index];
  bool get _isLast => _index >= _items.length - 1;
  // Gerçek (uzak) modda günün genel hedefini kullan; mock'ta yalnızca yüklenen
  // listeye göre say.
  bool get _global => _remote;
  int get _target => _global ? gameProgress.dailyTarget : _items.length;
  // Bu oturuma başlarken tamamlanmış tekrar sayısı (kaldığın yer).
  int get _base => _global ? _doneAtStart : 0;
  bool _hasPhoto(MistakeEntry e) => e.imageBytes != null || e.photoPath != null;

  void _feedback(bool correct) {
    if (correct) {
      _correct++;
      sound.correct();
      HapticFeedback.mediumImpact();
      _confetti.play();
      gameProgress.addXp(GameProgress.xpPerCorrect);
    } else {
      sound.wrong();
      HapticFeedback.heavyImpact();
    }
    gameProgress.recordReview();
    // Tekrar planını güncelle (1→3→7→30; yanlışta 1 güne sıfırla).
    if (_remote) {
      mistakeRepository.submitReview(_current, correct);
      // Konu haritası için ölçüm kaydı.
      progressRepository.recordAttempt(
        subject: _current.subject,
        concept: _current.concept,
        exam: _current.exam,
        correct: correct,
        mistakeId: _current.id,
        extraConcepts: _current.extraConcepts,
      );
    }
  }

  void _advance() {
    final int next = _index + 1;
    final bool allDone = next >= _items.length;
    // Günün geneline göre hedefe ulaşıldı mı (kaldığın yer + bu oturum).
    final bool reachedGoal =
        !_goalClaimed && _target > 0 && (_base + next) >= _target;

    if (reachedGoal) {
      final bool awarded =
          gameProgress.claimDailyGoal(GameProgress.dailyGoalBonus);
      sound.levelUp();
      _confetti.play();
      setState(() {
        _index = next;
        _selectedOption = null;
        _answered = false;
        _goalClaimed = true;
        _showGoal = true;
        _bonusAwarded = awarded ? GameProgress.dailyGoalBonus : 0;
      });
      return;
    }
    if (allDone) {
      sound.levelUp();
      _confetti.play();
      setState(() {
        _index = next;
        _completed = true;
      });
      return;
    }
    setState(() {
      _index = next;
      _selectedOption = null;
      _answered = false;
    });
  }

  void _selfGrade(bool correct) {
    _feedback(correct);
    _advance();
  }

  void _pickOption(int i) {
    if (_answered) return;
    _feedback(i == _current.correctIndex);
    setState(() {
      _selectedOption = i;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          SafeArea(child: _body()),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 8,
              gravity: 0.25,
              emissionFrequency: 0.06,
              colors: _confettiColors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _messageView(_error!, retry: true);
    if (_items.isEmpty) {
      return _messageView(
        widget.subject != null
            ? '${widget.subject} dersinde bugünlük tekrar kalmadı! 🎉\n'
                'Başka bir ders seçebilir ya da yarın gelebilirsin.'
            : 'Bugünlük tekrar kalmadı! 🎉\n'
                'Yeni hata ekleyebilir ya da yarın tekrar gelebilirsin.',
        emoji: '🎉',
      );
    }
    if (_completed) return _completionView();
    if (_showGoal) return _goalView();
    return _practiceView();
  }

  Widget _practiceView() {
    final MistakeEntry e = _current;
    return Column(
      children: <Widget>[
        // Üst şerit: kapat + ilerleme
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.inkLight),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _goalClaimed || _target == 0
                        ? 1.0
                        : ((_base + _index) / _target).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.line,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.green),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _goalClaimed
                    ? 'Ekstra ${_base + _index - _target + 1}'
                    : '${_base + _index + 1}/$_target',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        // Konu etiketi + (varsa) not / tam ekran
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: <Widget>[
              Expanded(child: _conceptChip(e)),
              if (e.note.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.sticky_note_2_outlined,
                      color: AppColors.inkLight),
                  tooltip: 'Notun',
                  onPressed: () => _showNote(e),
                ),
              if (_hasPhoto(e))
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded,
                      color: AppColors.inkLight),
                  tooltip: 'Tam ekran',
                  onPressed: () => _showPhoto(e),
                ),
            ],
          ),
        ),
        // Soru + çizim (büyük alan)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: DrawingCanvas(
              key: ValueKey<int>(_index),
              background: _questionBackground(e),
            ),
          ),
        ),
        // Değerlendirme: şık varsa şıklar, yoksa öz-değerlendirme
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: _bottomSection(e),
        ),
      ],
    );
  }

  /// Çizim katmanının arka planı: soru fotoğrafı (yoksa metin).
  Widget _questionBackground(MistakeEntry e) {
    if (e.imageBytes != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.help_outline_rounded,
                size: 48, color: AppColors.inkLight),
            const SizedBox(height: 12),
            Text(
              e.concept,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            if (e.note.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                e.note,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkLight, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showNote(MistakeEntry e) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Notun'),
        content: Text(e.note),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showPhoto(MistakeEntry e) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: <Widget>[
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: e.imageBytes != null
                    ? Image.memory(e.imageBytes!, fit: BoxFit.contain)
                    : MistakePhoto(path: e.photoPath!, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conceptChip(MistakeEntry e) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blueBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${e.subject} · ${e.concept}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.blueDark,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _bottomSection(MistakeEntry e) {
    if (e.hasOptions && e.correctIndex != null) return _optionsSection(e);
    return _selfGradeButtons();
  }

  Widget _selfGradeButtons() {
    return Row(
      children: <Widget>[
        Expanded(
          child: GameButton(
            label: 'Bilemedim',
            color: AppColors.red,
            icon: Icons.close_rounded,
            onPressed: () => _selfGrade(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GameButton(
            label: 'Doğru çözdüm',
            color: AppColors.green,
            icon: Icons.check_rounded,
            onPressed: () => _selfGrade(true),
          ),
        ),
      ],
    );
  }

  Widget _optionsSection(MistakeEntry e) {
    final int n = e.options!.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            for (int i = 0; i < n; i++) _letterButton(e, i),
          ],
        ),
        if (_answered) ...<Widget>[
          const SizedBox(height: 10),
          GameButton(label: _isLast ? 'BİTİR' : 'DEVAM', onPressed: _advance),
        ],
      ],
    );
  }

  Widget _letterButton(MistakeEntry e, int i) {
    final String label = e.options![i].label.isNotEmpty
        ? e.options![i].label
        : String.fromCharCode(65 + i);
    Color bg = Colors.white;
    Color border = AppColors.line;
    Color fg = AppColors.ink;
    if (_answered) {
      if (i == e.correctIndex) {
        bg = AppColors.green;
        border = AppColors.green;
        fg = Colors.white;
      } else if (i == _selectedOption) {
        bg = AppColors.red;
        border = AppColors.red;
        fg = Colors.white;
      } else {
        fg = AppColors.inkLight;
      }
    }
    return GestureDetector(
      onTap: _answered ? null : () => _pickOption(i),
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2.5),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: fg),
        ),
      ),
    );
  }

  void _continuePastGoal() {
    setState(() {
      _showGoal = false;
      _selectedOption = null;
      _answered = false;
    });
  }

  Widget _goalView() {
    final int remaining = _items.length - _index;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('🎯', style: TextStyle(fontSize: 84)),
          const SizedBox(height: 12),
          const Text('Günlük hedefini tamamladın!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('$_correct / $_index doğru',
              style: const TextStyle(color: AppColors.inkLight, fontSize: 15)),
          if (_bonusAwarded > 0) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('+$_bonusAwarded XP 🎉',
                  style: const TextStyle(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ),
          ],
          const SizedBox(height: 28),
          if (remaining > 0) ...<Widget>[
            GameButton(
              label: 'DEVAM ET ($remaining soru daha)',
              onPressed: _continuePastGoal,
            ),
            const SizedBox(height: 12),
            GameButton(
              label: 'Bugünlük bitir',
              color: AppColors.blue,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ] else
            GameButton(
              label: 'HARİKA, BİTİR',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }

  Widget _completionView() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('🏆', style: TextStyle(fontSize: 88)),
          const SizedBox(height: 12),
          const Text('Tekrar bitti!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '$_correct / ${_items.length} soruyu doğru çözdün.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkLight, fontSize: 15),
          ),
          const SizedBox(height: 32),
          GameButton(
            label: 'DEVAM',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _messageView(String message, {String emoji = '⚠️', bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkLight, fontSize: 15),
            ),
            const SizedBox(height: 24),
            GameButton(
              label: retry ? 'Tekrar dene' : 'TAMAM',
              onPressed: retry ? _load : () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/progress_repository.dart';
import '../../data/question_pool_repository.dart';
import '../../models/public_question.dart';
import '../../services/sound_service.dart';
import '../../state/game_progress.dart';
import '../../theme/app_colors.dart';
import '../../widgets/drawing_canvas.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_photo.dart';
import 'report_question_sheet.dart';
import 'send_question_sheet.dart';

/// Soru havuzu: başka öğrencilerin paylaştığı hataları rastgele çözdürür.
/// Her sorunun üstünde sahibinin takma adı ve havuz istatistikleri görünür.
class SolvePoolScreen extends StatefulWidget {
  const SolvePoolScreen({super.key, this.subject, this.concept});

  /// Verilirse yalnızca bu ders/konudan soru gelir (haritadan konu testi).
  final String? subject;
  final String? concept;

  @override
  State<SolvePoolScreen> createState() => _SolvePoolScreenState();
}

class _SolvePoolScreenState extends State<SolvePoolScreen> {
  List<PublicQuestion> _items = <PublicQuestion>[];
  bool _loading = true;
  String? _error;
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _answered = false;

  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 900),
  );

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
      final List<PublicQuestion> items = await questionPoolRepository
          .fetchRandom(subject: widget.subject, concept: widget.concept);
      if (!mounted) return;
      setState(() {
        _items = items;
        _index = 0;
        _correct = 0;
        _selected = null;
        _answered = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Sorular yüklenemedi.';
        _loading = false;
      });
    }
  }

  PublicQuestion get _current => _items[_index];
  bool get _isLast => _index >= _items.length - 1;

  void _pick(int i) {
    if (_answered) return;
    final bool correct = i == _current.correctIndex;
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
    gameProgress.registerActivity(); // havuzda çözmek de seriyi sürdürür
    questionPoolRepository.recordAttempt(_current.id, correct);
    progressRepository.recordAttempt(
      subject: _current.subject,
      concept: _current.concept,
      exam: _current.exam,
      correct: correct,
      source: 'pool',
      mistakeId: _current.id,
    );
    setState(() {
      _selected = i;
      _answered = true;
    });
  }

  /// Soruyu bildir; gönderilirse listeden çıkarıp sıradakine geç.
  Future<void> _report() async {
    final String id = _current.id;
    final bool sent = await showReportQuestionSheet(context, questionId: id);
    if (!sent || !mounted) return;
    setState(() {
      _items.removeWhere((PublicQuestion q) => q.id == id);
      if (_index >= _items.length) _index = 0;
      _selected = null;
      _answered = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildirildi, teşekkürler 🙏'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (_items.isEmpty) _load();
  }

  void _next() {
    if (_isLast) {
      _load(); // yeni bir tur getir
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _answered = false;
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
    if (_error != null) return _message(_error!, retry: true);
    if (_items.isEmpty) {
      return _message(
        widget.concept != null
            ? '"${widget.concept}" konusunda havuzda henüz soru yok.\n'
                  'Havuz doldukça burası da dolacak.'
            : 'Havuzda şu an çözebileceğin soru yok.\n'
                  'Sen de sorularını paylaşarak havuzu büyütebilirsin.',
        emoji: '🫙',
      );
    }
    return _questionView();
  }

  Widget _questionView() {
    final PublicQuestion q = _current;
    return Column(
      children: <Widget>[
        // Üst şerit
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.inkLight,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  '${_index + 1} / ${_items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkLight,
                  ),
                ),
              ),
              Text(
                '$_correct doğru',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.purple),
                tooltip: 'Arkadaşına gönder',
                onPressed: () => showSendQuestionSheet(
                  context,
                  mistakeId: _current.id,
                  title: '${_current.subject} · ${_current.concept}',
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.inkLight,
                ),
                tooltip: 'Bu soruyu bildir',
                onPressed: _report,
              ),
            ],
          ),
        ),
        _attributionCard(q),
        // Soru + çizim
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: DrawingCanvas(
              key: ValueKey<String>(q.id),
              background: MistakePhoto(path: q.photoPath, fit: BoxFit.contain),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: _options(q),
        ),
      ],
    );
  }

  /// "Bu soru X'in bir hatası" + havuz istatistikleri.
  Widget _attributionCard(PublicQuestion q) {
    final int? rate = q.successRate;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🐻', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  // Çıkmış soruya "birinin hatası" demek yanlış olur.
                  q.isOfficial
                      ? TextSpan(
                          children: <TextSpan>[
                            TextSpan(
                              text: q.officialLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(text: ' çıkmış sorusu'),
                          ],
                        )
                      : TextSpan(
                          children: <TextSpan>[
                            const TextSpan(text: 'Bu soru '),
                            TextSpan(
                              text: q.ownerNickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(text: '\'in bir hatası'),
                          ],
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.purpleDark,
                    fontSize: 13,
                  ),
                ),
              ),
              if (q.exam != null || q.subject.isNotEmpty)
                Text(
                  <String>[
                    if (q.exam != null) q.exam!,
                    if (q.subject.isNotEmpty) q.subject,
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.inkLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _stat(
                Icons.check_circle_rounded,
                AppColors.green,
                '${q.solvedCorrect} kişi doğru',
              ),
              const SizedBox(width: 12),
              _stat(
                Icons.cancel_rounded,
                AppColors.red,
                '${q.solvedWrong} kişi yanlış',
              ),
              if (rate != null) ...<Widget>[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (rate >= 50 ? AppColors.green : AppColors.red)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '%$rate başarı',
                    style: TextStyle(
                      color: rate >= 50
                          ? AppColors.greenDark
                          : AppColors.redDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.inkLight, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _options(PublicQuestion q) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            for (int i = 0; i < q.options.length; i++) _letter(q, i),
          ],
        ),
        if (_answered) ...<Widget>[
          const SizedBox(height: 10),
          GameButton(
            label: _isLast ? 'YENİ SORULAR' : 'DEVAM',
            onPressed: _next,
          ),
        ],
      ],
    );
  }

  Widget _letter(PublicQuestion q, int i) {
    final String label = q.options[i].label.isNotEmpty
        ? q.options[i].label
        : String.fromCharCode(65 + i);
    Color bg = Colors.white;
    Color border = AppColors.line;
    Color fg = AppColors.ink;
    if (_answered) {
      if (i == q.correctIndex) {
        bg = AppColors.green;
        border = AppColors.green;
        fg = Colors.white;
      } else if (i == _selected) {
        bg = AppColors.red;
        border = AppColors.red;
        fg = Colors.white;
      } else {
        fg = AppColors.inkLight;
      }
    }
    return GestureDetector(
      onTap: _answered ? null : () => _pick(i),
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _message(String text, {String emoji = '⚠️', bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              text,
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

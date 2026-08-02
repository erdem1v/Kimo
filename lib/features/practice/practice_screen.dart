import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../state/game_progress.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/game_widgets.dart';

/// Oyunlaştırılmış günlük pratik ekranı. Çoktan seçmeli sorular; doğru cevapta
/// konfeti + ses + titreşim + XP animasyonu, yanlışta sallanma + can kaybı.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TickerProviderStateMixin {
  final List<PracticeQuestion> _questions = MockData.practiceQuestions;

  int _index = 0;
  int? _selected;
  bool _answered = false;
  int _correctCount = 0;
  bool _completed = false;

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _xp =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  static const List<Color> _confettiColors = <Color>[
    AppColors.green,
    AppColors.gold,
    AppColors.blue,
    AppColors.purple,
    AppColors.red,
  ];

  @override
  void dispose() {
    _confetti.dispose();
    _shake.dispose();
    _xp.dispose();
    super.dispose();
  }

  PracticeQuestion get _q => _questions[_index];
  bool get _isCorrect => _selected == _q.correctIndex;
  bool get _isLast => _index >= _questions.length - 1;

  void _check() {
    setState(() => _answered = true);
    if (_isCorrect) {
      _correctCount++;
      gameProgress.answer(correct: true);
      sound.correct();
      HapticFeedback.mediumImpact();
      _confetti.play();
      _xp.forward(from: 0);
    } else {
      gameProgress.answer(correct: false);
      sound.wrong();
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  void _next() {
    if (_isLast) {
      setState(() => _completed = true);
      sound.levelUp();
      _confetti.play();
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
          SafeArea(
            child: _completed ? _buildCompletion() : _buildQuestion(),
          ),
          // Konfeti tüm ekranın üstünden patlar.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 22,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.25,
              emissionFrequency: 0.06,
              colors: _confettiColors,
            ),
          ),
          // Doğru cevapta yükselip kaybolan "+10 XP" balonu.
          Align(
            alignment: const Alignment(0, -0.5),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _xp,
                builder: (BuildContext context, _) {
                  final double v = _xp.value;
                  if (!_xp.isAnimating || v == 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: (1 - v).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -60 * v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+${GameProgress.xpPerCorrect} XP ⚡',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Column(
      children: <Widget>[
        // Üst şerit: kapat + ilerleme + can
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.inkLight),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: RoundedProgressBar(
                  value: _index / _questions.length,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              HeartsRow(hearts: gameProgress.hearts, maxHearts: gameProgress.maxHearts),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _conceptChip(),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (BuildContext context, Widget? child) {
                    final double dx =
                        math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 10;
                    return Transform.translate(offset: Offset(dx, 0), child: child);
                  },
                  child: Text(
                    _q.text,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (int i = 0; i < _q.options.length; i++) _optionTile(i),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _conceptChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blueBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_q.subject} · ${_q.concept}',
        style: const TextStyle(
          color: AppColors.blueDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _optionTile(int i) {
    final bool selected = _selected == i;
    Color border = AppColors.line;
    Color bg = Colors.white;
    Color textColor = AppColors.ink;

    if (_answered) {
      if (i == _q.correctIndex) {
        border = AppColors.green;
        bg = AppColors.greenBg;
        textColor = AppColors.greenDark;
      } else if (selected) {
        border = AppColors.red;
        bg = AppColors.redBg;
        textColor = AppColors.redDark;
      }
    } else if (selected) {
      border = AppColors.blue;
      bg = AppColors.blueBg;
      textColor = AppColors.blueDark;
    }

    return GestureDetector(
      onTap: _answered
          ? null
          : () {
              sound.tap();
              setState(() => _selected = i);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 2),
              ),
              child: Text(
                String.fromCharCode(65 + i),
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _q.options[i],
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            if (_answered && i == _q.correctIndex)
              const Icon(Icons.check_circle, color: AppColors.green)
            else if (_answered && selected)
              const Icon(Icons.cancel, color: AppColors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!_answered) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
        child: GameButton(
          label: 'KONTROL ET',
          enabled: _selected != null,
          onPressed: _check,
        ),
      );
    }

    final bool correct = _isCorrect;
    final Color accent = correct ? AppColors.greenDark : AppColors.redDark;
    return Container(
      width: double.infinity,
      color: correct ? AppColors.greenBg : AppColors.redBg,
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(correct ? Icons.check_circle : Icons.cancel, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct
                      ? 'Harika, doğru! 🎉'
                      : 'Doğru cevap: ${_q.options[_q.correctIndex]}',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _q.explanation,
            style: TextStyle(color: accent, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 14),
          GameButton(
            label: _isLast ? 'BİTİR' : 'DEVAM ET',
            color: correct ? AppColors.green : AppColors.red,
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletion() {
    final int earnedXp = _correctCount * GameProgress.xpPerCorrect;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('🏆', style: TextStyle(fontSize: 88)),
          const SizedBox(height: 12),
          const Text(
            'Ders tamamlandı!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bugünkü pratiğini bitirdin, harikasın!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkLight, fontSize: 15),
          ),
          const SizedBox(height: 28),
          Row(
            children: <Widget>[
              Expanded(
                child: _resultCard(
                  '⚡ $earnedXp',
                  'KAZANILAN XP',
                  AppColors.gold,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _resultCard(
                  '🎯 $_correctCount/${_questions.length}',
                  'DOĞRU',
                  AppColors.green,
                ),
              ),
            ],
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

  Widget _resultCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: <Widget>[
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkLight)),
        ],
      ),
    );
  }
}

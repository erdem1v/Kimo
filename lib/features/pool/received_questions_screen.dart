import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/question_pool_repository.dart';
import '../../models/received_question.dart';
import '../../services/sound_service.dart';
import '../../state/game_progress.dart';
import '../../theme/app_colors.dart';
import '../../widgets/drawing_canvas.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_photo.dart';

/// Arkadaşlarının sana gönderdiği sorular: liste + çözme.
class ReceivedQuestionsScreen extends StatefulWidget {
  const ReceivedQuestionsScreen({super.key});

  @override
  State<ReceivedQuestionsScreen> createState() =>
      _ReceivedQuestionsScreenState();
}

class _ReceivedQuestionsScreenState extends State<ReceivedQuestionsScreen> {
  List<ReceivedQuestion> _items = <ReceivedQuestion>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ReceivedQuestion> items =
          await questionPoolRepository.received();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _open(ReceivedQuestion q) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _SolveReceivedScreen(question: q)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Gelen sorular'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, style: const TextStyle(color: AppColors.inkLight)),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('📭', style: TextStyle(fontSize: 56)),
              SizedBox(height: 14),
              Text(
                'Henüz sana soru gönderilmemiş.\n'
                'Arkadaşların soru gönderdiğinde burada görünecek.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkLight, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int i) => _tile(_items[i]),
    );
  }

  Widget _tile(ReceivedQuestion q) {
    final Color color = q.senderMascot?.color ?? AppColors.purple;
    return GestureDetector(
      onTap: () => _open(q),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: q.solved ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: q.solved ? AppColors.line : color.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 54,
                height: 54,
                child: MistakePhoto(path: q.photoPath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${q.senderNickname} gönderdi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: q.solved ? AppColors.inkLight : AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      if (q.exam != null) q.exam!,
                      if (q.subject.isNotEmpty) q.subject,
                      if (q.concept.isNotEmpty) q.concept,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.inkLight, fontSize: 12.5),
                  ),
                  if (q.note != null && q.note!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text('“${q.note}”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (q.solved)
              Icon(
                q.correct == true
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: q.correct == true ? AppColors.green : AppColors.red,
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Çöz',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gelen tek bir soruyu çözme ekranı.
class _SolveReceivedScreen extends StatefulWidget {
  const _SolveReceivedScreen({required this.question});

  final ReceivedQuestion question;

  @override
  State<_SolveReceivedScreen> createState() => _SolveReceivedScreenState();
}

class _SolveReceivedScreenState extends State<_SolveReceivedScreen> {
  int? _selected;
  bool _answered = false;

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _pick(int i) {
    if (_answered || widget.question.solved) return;
    final bool correct = i == widget.question.correctIndex;
    if (correct) {
      sound.correct();
      HapticFeedback.mediumImpact();
      _confetti.play();
      gameProgress.addXp(GameProgress.xpPerCorrect);
    } else {
      sound.wrong();
      HapticFeedback.heavyImpact();
    }
    gameProgress.registerActivity();
    questionPoolRepository.markSolved(widget.question.sendId, correct);
    setState(() {
      _selected = i;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ReceivedQuestion q = widget.question;
    final Color color = q.senderMascot?.color ?? AppColors.purple;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.inkLight),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          <String>[
                            if (q.exam != null) q.exam!,
                            if (q.subject.isNotEmpty) q.subject,
                          ].join(' · '),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkLight),
                        ),
                      ),
                    ],
                  ),
                ),
                // Gönderen bilgisi + notu
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(q.senderMascot?.emoji ?? '🐻',
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${q.senderNickname} bu soruyu sana gönderdi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            if (q.note != null && q.note!.isNotEmpty)
                              Text('“${q.note}”',
                                  style: const TextStyle(
                                      color: AppColors.inkLight,
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: DrawingCanvas(
                      background:
                          MistakePhoto(path: q.photoPath, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (q.solved && !_answered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            q.correct == true
                                ? 'Bu soruyu daha önce doğru çözmüştün ✓'
                                : 'Bu soruyu daha önce bilememiştin',
                            style: TextStyle(
                                color: q.correct == true
                                    ? AppColors.greenDark
                                    : AppColors.redDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          for (int i = 0; i < q.options.length; i++)
                            _letter(q, i),
                        ],
                      ),
                      if (_answered) ...<Widget>[
                        const SizedBox(height: 10),
                        GameButton(
                          label: 'BİTİR',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
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
              colors: const <Color>[
                AppColors.green,
                AppColors.gold,
                AppColors.blue,
                AppColors.purple,
                AppColors.red,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _letter(ReceivedQuestion q, int i) {
    final String label = q.options[i].label.isNotEmpty
        ? q.options[i].label
        : String.fromCharCode(65 + i);
    final bool reveal = _answered || q.solved;
    Color bg = Colors.white;
    Color border = AppColors.line;
    Color fg = AppColors.ink;
    if (reveal) {
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
      onTap: reveal ? null : () => _pick(i),
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2.5),
        ),
        child: Text(label,
            style:
                TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: fg)),
      ),
    );
  }
}

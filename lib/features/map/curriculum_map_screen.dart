import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../data/yks_curriculum.dart';
import '../../models/topic_progress.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_style.dart';
import '../pool/solve_pool_screen.dart';

/// Müfredat haritası: ders → ünite → konu. Her konu bir amblem; 15 soru
/// çözülene kadar dolmaz, dolduktan sonra başarıya göre renklenir, uzun süre
/// dokunulmayan konular solar.
class CurriculumMapScreen extends StatefulWidget {
  const CurriculumMapScreen({super.key});

  @override
  State<CurriculumMapScreen> createState() => _CurriculumMapScreenState();
}

class _CurriculumMapScreenState extends State<CurriculumMapScreen> {
  Map<String, TopicProgress> _progress = <String, TopicProgress>{};
  bool _loading = true;
  String _exam = 'TYT';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final Map<String, TopicProgress> p = await progressRepository.myProgress();
      if (!mounted) return;
      setState(() {
        _progress = p;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  TopicProgress _of(String subject, String concept) =>
      _progress['$subject|$concept'] ??
      TopicProgress(subject: subject, concept: concept);

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Unit>> subjects =
        YksCurriculum.forExam(userProfile.curriculum, _exam);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Konu Haritası'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                _examSelector(),
                const SizedBox(height: 14),
                _legend(),
                const SizedBox(height: 18),
                for (final MapEntry<String, List<Unit>> e in subjects.entries)
                  _subjectBlock(e.key, e.value),
              ],
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
            Expanded(
              child: GestureDetector(
                onTap: () {
                  sound.tap();
                  setState(() => _exam = e);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _exam == e
                        ? LinearGradient(
                            colors: e == 'TYT'
                                ? <Color>[AppColors.blue, AppColors.indigo]
                                : <Color>[AppColors.pink, AppColors.purple],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    e,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: _exam == e ? Colors.white : AppColors.inkLight,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(width: 11, height: 11,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: AppColors.inkLight, fontSize: 11.5)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        item(const Color(0xFFD9D9D9), 'Hiç çözülmedi'),
        item(AppColors.blue, 'Ölçülüyor'),
        item(AppColors.green, 'Sağlam'),
        item(AppColors.orange, 'Orta'),
        item(AppColors.red, 'Zayıf'),
      ],
    );
  }

  Widget _subjectBlock(String subject, List<Unit> units) {
    final Color color = subjectColor(subject);
    // Dersin genel doluluğu: konuların ortalama doluluk oranı.
    final int total = YksCurriculum.topicCount(units);
    double sum = 0;
    for (final Unit u in units) {
      for (final String t in u.topics) {
        sum += _of(subject, t).fill;
      }
    }
    final int percent = total == 0 ? 0 : (sum / total * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Ders başlığı
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: <Widget>[
                Text(subjectEmoji(subject),
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subject,
                    style: TextStyle(
                      color: color.computeLuminance() > 0.55
                          ? AppColors.ink
                          : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('%$percent',
                      style: TextStyle(
                          color: color.computeLuminance() > 0.55
                              ? AppColors.ink
                              : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final Unit u in units) _unitBlock(subject, u),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitBlock(String subject, Unit unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            unit.name.toUpperCase(),
            style: const TextStyle(
              color: AppColors.inkLight,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: <Widget>[
              for (final String t in unit.topics) _topicNode(subject, t),
            ],
          ),
        ],
      ),
    );
  }

  /// Bir konu amblemi: dairesel doluluk halkası + durum rengi.
  Widget _topicNode(String subject, String concept) {
    final TopicProgress p = _of(subject, concept);
    return GestureDetector(
      onTap: () {
        sound.tap();
        _openTopic(p);
      },
      child: SizedBox(
        width: 76,
        child: Column(
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: const Size(56, 56),
                  painter: _NodePainter(
                    fill: p.fill,
                    color: p.displayColor,
                    complete: p.state == TopicState.measured,
                  ),
                ),
                // Ortada: yüzde (ölçüldüyse) ya da soru sayısı
                if (p.state == TopicState.measured)
                  Text('%${p.successPercent}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: p.displayColor))
                else if (p.attempts > 0)
                  Text('${p.attempts}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: p.displayColor))
                else
                  const Icon(Icons.lock_outline_rounded,
                      size: 18, color: Color(0xFFB5B5B5)),
                // Zayıf konu uyarısı
                if (p.needsAttention)
                  Positioned(
                    top: 0,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Text('!',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              concept,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: p.state == TopicState.untouched
                    ? AppColors.inkLight
                    : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTopic(TopicProgress p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => _TopicSheet(
        progress: p,
        onSolve: () async {
          Navigator.of(ctx).pop();
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => SolvePoolScreen(
                subject: p.subject,
                concept: p.concept,
              ),
            ),
          );
          await _load();
        },
      ),
    );
  }
}

/// Konu amblemi: gri taban halka + ilerleme yayı.
class _NodePainter extends CustomPainter {
  const _NodePainter({
    required this.fill,
    required this.color,
    required this.complete,
  });

  final double fill;
  final Color color;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 4;

    // İç dolgu
    canvas.drawCircle(
      c,
      r,
      Paint()..color = color.withValues(alpha: complete ? 0.20 : 0.10),
    );

    // Taban halka
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFE8E8E8),
    );

    // İlerleme yayı (tepeden saat yönünde)
    if (fill > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * fill,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_NodePainter old) =>
      old.fill != fill || old.color != color || old.complete != complete;
}

/// Konuya dokununca açılan detay: maskotun yorumu + istatistik + test.
class _TopicSheet extends StatelessWidget {
  const _TopicSheet({required this.progress, required this.onSolve});

  final TopicProgress progress;
  final VoidCallback onSolve;

  @override
  Widget build(BuildContext context) {
    final TopicProgress p = progress;
    final Color color = p.displayColor;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(p.concept,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text(p.subject,
                style: const TextStyle(
                    color: AppColors.inkLight, fontSize: 13)),
            const SizedBox(height: 16),
            // Maskotun sözü
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.30)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(userProfile.mascot?.emoji ?? '🐻',
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.coachMessage,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _stat('${p.attempts}', 'çözülen'),
                _stat('${p.correct}', 'doğru'),
                _stat(
                    p.successPercent == null ? '—' : '%${p.successPercent}',
                    'başarı'),
                if (p.attempts > 0)
                  _stat(p.daysSince == 0 ? 'bugün' : '${p.daysSince}g',
                      'son çalışma'),
              ],
            ),
            const SizedBox(height: 8),
            if (p.state != TopicState.measured)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: p.fill,
                    minHeight: 8,
                    backgroundColor: AppColors.line,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GameButton(
              label: p.attempts == 0 ? 'BU KONUYU TEST ET' : 'SORU ÇÖZ',
              onPressed: onSolve,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.inkLight, fontSize: 11)),
        ],
      ),
    );
  }
}

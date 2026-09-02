import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:ai_yks_coach/data/progress_repository.dart';
import '../pool/pool_repository.dart';
import 'package:ai_yks_coach/data/yks_curriculum.dart';
import 'package:ai_yks_coach/models/topic_progress.dart';
import 'package:ai_yks_coach/services/sound_service.dart';
import 'package:ai_yks_coach/state/user_profile.dart';
import 'package:ai_yks_coach/theme/app_colors.dart';
import 'package:ai_yks_coach/widgets/game_button.dart';
import 'package:ai_yks_coach/widgets/mistake_style.dart';
import '../pool/solve_pool_screen.dart';

/// Müfredat haritası: seçilen dersin konuları yılankavi bir yol üzerinde
/// dizilir. Her konu bir durak; 15 soru çözülene kadar amblem dolmaz,
/// dolduktan sonra başarıya göre renklenir, uzun süre uğranmayan durak solar.
class CurriculumMapScreen extends StatefulWidget {
  const CurriculumMapScreen({super.key});

  @override
  State<CurriculumMapScreen> createState() => _CurriculumMapScreenState();
}

// --- Yerleşim ölçüleri ---
const double _nodeSize = 72;
const double _nodeGap = 108; // duraklar arası dikey mesafe
const double _bannerHeight = 40; // ünite bandı
const double _amplitude = 78; // yolun yanal salınımı

class _CurriculumMapScreenState extends State<CurriculumMapScreen> {
  Map<String, TopicProgress> _progress = <String, TopicProgress>{};
  // 'Ders|Konu' → havuzda çözebileceğin soru sayısı.
  Map<String, int> _available = <String, int>{};
  bool _loading = true;
  String _exam = 'TYT';
  String? _subject;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final Map<String, TopicProgress> p = await progressRepository.myProgress();
      final Map<String, int> counts =
          await poolRepository.availableCounts();
      if (!mounted) return;
      setState(() {
        _progress = p;
        _available = counts;
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

  int _availableFor(String subject, String concept) =>
      _available['$subject|$concept'] ?? 0;

  /// Havuzdan karışık soru (konu seçmeden). Havuz seyrekken boş konulara
  /// tıklamak yerine buradan devam edilir.
  Future<void> _solveMixed() async {
    sound.tap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SolvePoolScreen()),
    );
    await _load();
  }

  Map<String, List<Unit>> get _subjects =>
      YksCurriculum.forExam(userProfile.curriculum, _exam);

  String get _activeSubject {
    final Map<String, List<Unit>> s = _subjects;
    if (_subject != null && s.containsKey(_subject)) return _subject!;
    return s.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    final String subject = _activeSubject;
    final Color color = subjectColor(subject);
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        // Başlık seçili dersi gösterir (ders emojisi + adı).
        title: Row(
          children: <Widget>[
            Text(subjectEmoji(subject), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$subject · $_exam',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        foregroundColor:
            color.computeLuminance() > 0.55 ? AppColors.ink : Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _solveMixed,
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: const Text('🎲', style: TextStyle(fontSize: 18)),
              label: const Text('Karışık çöz',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
      body: Column(
        children: <Widget>[
          _examSelector(),
          _subjectStrip(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _MapTrail(
                    key: ValueKey<String>('$_exam|$subject'),
                    subject: subject,
                    units: _subjects[subject]!,
                    progressOf: (String c) => _of(subject, c),
                    availableOf: (String c) => _availableFor(subject, c),
                    onTapTopic: _openTopic,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _examSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEFF2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            for (final String e in const <String>['TYT', 'AYT'])
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    sound.tap();
                    setState(() {
                      _exam = e;
                      _subject = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 11),
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
                        fontSize: 15,
                        color: _exam == e ? Colors.white : AppColors.inkLight,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Ders şeridi: yatay kaydırmalı, seçili ders dolu renkte.
  Widget _subjectStrip() {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        children: <Widget>[
          for (final String s in _subjects.keys) _subjectChip(s),
        ],
      ),
    );
  }

  Widget _subjectChip(String s) {
    final bool selected = s == _activeSubject;
    final Color color = subjectColor(s);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          sound.tap();
          setState(() => _subject = s);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : AppColors.line,
              width: 1.5,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(subjectEmoji(s), style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                s,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected
                      ? (color.computeLuminance() > 0.55
                          ? AppColors.ink
                          : Colors.white)
                      : AppColors.ink,
                ),
              ),
            ],
          ),
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
        available: _availableFor(p.subject, p.concept),
        onSolve: () async {
          Navigator.of(ctx).pop();
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  SolvePoolScreen(subject: p.subject, concept: p.concept),
            ),
          );
          await _load();
        },
      ),
    );
  }
}

/// Haritadaki sıra: ya bir ünite bandı ya da bir konu durağı.
class _Stop {
  const _Stop.unit(this.unitName)
      : concept = null,
        unitIndex = 0;
  const _Stop.topic(this.concept, this.unitIndex) : unitName = null;

  final String? unitName;
  final String? concept;
  final int unitIndex;

  bool get isUnit => unitName != null;
}

/// Yılankavi yol: arka plan manzarası + noktalı iz + duraklar.
class _MapTrail extends StatelessWidget {
  const _MapTrail({
    super.key,
    required this.subject,
    required this.units,
    required this.progressOf,
    required this.availableOf,
    required this.onTapTopic,
  });

  final String subject;
  final List<Unit> units;
  final TopicProgress Function(String concept) progressOf;
  final int Function(String concept) availableOf;
  final void Function(TopicProgress) onTapTopic;

  @override
  Widget build(BuildContext context) {
    // Sıra listesini kur.
    final List<_Stop> stops = <_Stop>[];
    for (int u = 0; u < units.length; u++) {
      stops.add(_Stop.unit(units[u].name));
      for (final String t in units[u].topics) {
        stops.add(_Stop.topic(t, u));
      }
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double w = c.maxWidth;
        final double cx = w / 2;

        // Her sıranın y konumunu, konu duraklarının da x konumunu hesapla.
        final List<double> ys = <double>[];
        final List<double> xs = <double>[]; // yalnızca konu durakları için
        double y = 28;
        int topicIndex = 0;
        final List<Offset> nodeCenters = <Offset>[];
        final List<int> nodeStopIndex = <int>[];

        for (int i = 0; i < stops.length; i++) {
          ys.add(y);
          if (stops[i].isUnit) {
            xs.add(0);
            y += _bannerHeight + 14;
          } else {
            final double dx =
                cx + _amplitude * math.sin(topicIndex * 0.85) - _nodeSize / 2;
            xs.add(dx);
            nodeCenters.add(Offset(dx + _nodeSize / 2, y + _nodeSize / 2));
            nodeStopIndex.add(i);
            topicIndex++;
            y += _nodeGap;
          }
        }
        final double totalHeight = y + 60;

        // İlerlenecek ilk durak (maskotun duracağı yer).
        int currentNode = -1;
        for (int n = 0; n < nodeCenters.length; n++) {
          final _Stop s = stops[nodeStopIndex[n]];
          final TopicProgress p = progressOf(s.concept!);
          if (p.state != TopicState.measured) {
            currentNode = n;
            break;
          }
        }

        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            height: totalHeight,
            child: Stack(
              children: <Widget>[
                // Manzara + noktalı yol
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrailPainter(
                      points: nodeCenters,
                      accent: subjectColor(subject),
                    ),
                  ),
                ),
                // Duraklar ve ünite bantları
                for (int i = 0; i < stops.length; i++)
                  if (stops[i].isUnit)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: ys[i],
                      child: _UnitBanner(
                        name: stops[i].unitName!,
                        color: subjectColor(subject),
                      ),
                    )
                  else
                    Positioned(
                      left: xs[i],
                      top: ys[i],
                      child: _TopicStop(
                        progress: progressOf(stops[i].concept!),
                        available: availableOf(stops[i].concept!),
                        onTap: onTapTopic,
                      ),
                    ),
                // Maskot: sıradaki durağın yanında
                if (currentNode >= 0)
                  Positioned(
                    left: (nodeCenters[currentNode].dx + _nodeSize / 2 + 6)
                        .clamp(0.0, w - 46),
                    top: nodeCenters[currentNode].dy - 20,
                    child: const _MascotMarker(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ünite bandı — Duolingo'daki bölüm başlığı gibi.
class _UnitBanner extends StatelessWidget {
  const _UnitBanner({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        color.computeLuminance() > 0.55 ? AppColors.ink : Colors.white;
    return Container(
      height: _bannerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[color, color.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.flag_rounded, color: fg.withValues(alpha: 0.85), size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3B basılabilir durak düğmesi.
class _TopicStop extends StatefulWidget {
  const _TopicStop({
    required this.progress,
    required this.available,
    required this.onTap,
  });

  final TopicProgress progress;

  /// Bu konuda havuzdan çözebileceğin soru sayısı.
  final int available;
  final void Function(TopicProgress) onTap;

  @override
  State<_TopicStop> createState() => _TopicStopState();
}

class _TopicStopState extends State<_TopicStop> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final TopicProgress p = widget.progress;
    final Color color = p.displayColor;
    final bool untouched = p.state == TopicState.untouched;
    // Gölge için koyu ton (3B his).
    final Color shade = Color.lerp(color, Colors.black, 0.28)!;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        sound.tap();
        widget.onTap(p);
      },
      child: SizedBox(
        width: _nodeSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
              width: _nodeSize,
              height: _nodeSize,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Alt gölge katmanı (butona derinlik verir)
                  Positioned(
                    top: _pressed ? 2 : 6,
                    child: Container(
                      width: _nodeSize - 8,
                      height: _nodeSize - 8,
                      decoration: BoxDecoration(
                        color: untouched ? const Color(0xFFBFBFBF) : shade,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Üst yüzey
                  Container(
                    width: _nodeSize - 8,
                    height: _nodeSize - 8,
                    decoration: BoxDecoration(
                      color: untouched ? const Color(0xFFE2E2E2) : color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: _center(p),
                  ),
                  // İlerleme halkası
                  if (!untouched)
                    CustomPaint(
                      size: const Size(_nodeSize, _nodeSize),
                      painter: _RingPainter(fill: p.fill, color: Colors.white),
                    ),
                  // Zayıf konu uyarısı
                  if (p.needsAttention)
                    Positioned(
                      top: 0,
                      right: 2,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Text('!',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12)),
                      ),
                    ),
                  // Tamamlanmış konuya taç
                  if (p.state == TopicState.measured &&
                      (p.successRate ?? 0) >= 0.7)
                    const Positioned(
                      top: -2,
                      child: Text('👑', style: TextStyle(fontSize: 16)),
                    ),
                  // Havuzda çözülebilir soru varsa: kaç tane olduğu.
                  if (widget.available > 0)
                    Positioned(
                      bottom: 0,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text('${widget.available}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.concept,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: untouched ? AppColors.inkLight : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _center(TopicProgress p) {
    switch (p.state) {
      case TopicState.untouched:
        return const Icon(Icons.lock_rounded,
            size: 22, color: Color(0xFF9E9E9E));
      case TopicState.inProgress:
        return Text('${p.attempts}',
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: Colors.white));
      case TopicState.measured:
        return Text('%${p.successPercent}',
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.white));
    }
  }
}

/// Düğüm çevresindeki ilerleme halkası.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fill, required this.color});

  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (fill <= 0) return;
    final Offset c = Offset(size.width / 2, size.height / 2);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: size.width / 2 - 2),
      -math.pi / 2,
      2 * math.pi * fill,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fill != fill || old.color != color;
}

/// Maskot işaretçisi: sıradaki durağın yanında bekler.
class _MascotMarker extends StatelessWidget {
  const _MascotMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(userProfile.mascot?.emoji ?? '🐻',
          style: const TextStyle(fontSize: 20)),
    );
  }
}

/// Arka plan manzarası + duraklar arasındaki noktalı iz.
class _TrailPainter extends CustomPainter {
  const _TrailPainter({required this.points, required this.accent});

  final List<Offset> points;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    _paintScenery(canvas, size);
    _paintTrail(canvas);
  }

  /// Yumuşak tepeler ve bulutlar — görsel dosya olmadan "dünya" hissi.
  void _paintScenery(Canvas canvas, Size size) {
    final Paint hill = Paint()..color = accent.withValues(alpha: 0.07);
    final Paint hill2 = Paint()..color = accent.withValues(alpha: 0.05);

    // Sağ ve sol kenarlarda yumuşak tepe silüetleri.
    for (double y = 0; y < size.height; y += 420) {
      final Path left = Path()
        ..moveTo(0, y + 120)
        ..quadraticBezierTo(70, y + 20, 150, y + 130)
        ..lineTo(0, y + 130)
        ..close();
      canvas.drawPath(left, hill);

      final Path right = Path()
        ..moveTo(size.width, y + 320)
        ..quadraticBezierTo(size.width - 90, y + 220, size.width - 170, y + 330)
        ..lineTo(size.width, y + 330)
        ..close();
      canvas.drawPath(right, hill2);
    }

    // Bulut benzeri lekeler.
    final Paint cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (double y = 90; y < size.height; y += 340) {
      canvas.drawCircle(Offset(size.width * 0.18, y), 16, cloud);
      canvas.drawCircle(Offset(size.width * 0.24, y + 6), 12, cloud);
      canvas.drawCircle(Offset(size.width * 0.82, y + 170), 14, cloud);
      canvas.drawCircle(Offset(size.width * 0.76, y + 176), 10, cloud);
    }
  }

  /// Duraklar arasında S kıvrımlı, noktalı iz.
  void _paintTrail(Canvas canvas) {
    if (points.length < 2) return;
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final Offset p0 = points[i - 1];
      final Offset p1 = points[i];
      final double half = (p1.dy - p0.dy) / 2;
      path.cubicTo(p0.dx, p0.dy + half, p1.dx, p1.dy - half, p1.dx, p1.dy);
    }

    final Paint dot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFDCE3EA);

    const double dash = 3;
    const double gap = 13;
    for (final ui.PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(
          m.extractPath(d, math.min(d + dash, m.length)),
          dot,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.points != points || old.accent != accent;
}

/// Konuya dokununca açılan detay: maskotun yorumu + istatistik + test.
class _TopicSheet extends StatelessWidget {
  const _TopicSheet({
    required this.progress,
    required this.available,
    required this.onSolve,
  });

  final TopicProgress progress;
  final int available;
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
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(p.subject,
                style: const TextStyle(color: AppColors.inkLight, fontSize: 13)),
            const SizedBox(height: 16),
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
                _stat(p.successPercent == null ? '—' : '%${p.successPercent}',
                    'başarı'),
                if (p.attempts > 0)
                  _stat(p.daysSince == 0 ? 'bugün' : '${p.daysSince}g',
                      'son çalışma'),
              ],
            ),
            const SizedBox(height: 10),
            if (p.state != TopicState.measured)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
            const SizedBox(height: 6),
            if (available > 0)
              GameButton(
                label: p.attempts == 0
                    ? 'BU KONUYU TEST ET ($available)'
                    : 'SORU ÇÖZ ($available)',
                onPressed: onSolve,
              )
            else
              // Boş konuya girip duvara toslamasın: durumu önden söyle.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.hourglass_empty_rounded,
                        size: 18, color: AppColors.inkLight),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu konuda havuzda henüz soru yok. Aşağıdaki '
                        '"Karışık çöz" ile başka konulardan çözebilirsin.',
                        style: TextStyle(
                            color: AppColors.inkLight,
                            fontSize: 12.5,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
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
              style: const TextStyle(color: AppColors.inkLight, fontSize: 11)),
        ],
      ),
    );
  }
}

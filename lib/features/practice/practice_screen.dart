import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mistake_repository.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/mistake_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/drawing_canvas.dart';
import '../../widgets/game_button.dart';

/// Günlük pratik: kullanıcının eklediği hatalı soruları tek tek çözdürür.
/// Soru büyük gösterilir; kalem/silgi doğrudan sorunun üstünde kullanılır.
/// Öğrenci çözüp kendini "Doğru çözdüm / Bilemedim" ile değerlendirir.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

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
  bool _completed = false;

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
      final List<MistakeEntry> items =
          _remote ? await mistakeRepository.fetch() : mistakeStore.items;
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

  MistakeEntry get _current => _items[_index];
  bool get _isLast => _index >= _items.length - 1;
  bool _hasPhoto(MistakeEntry e) => e.imageBytes != null || e.photoUrl != null;

  void _answer(bool correct) {
    if (correct) {
      _correct++;
      sound.correct();
      HapticFeedback.mediumImpact();
      _confetti.play();
    } else {
      sound.wrong();
      HapticFeedback.heavyImpact();
    }
    if (_isLast) {
      setState(() => _completed = true);
      sound.levelUp();
      _confetti.play();
    } else {
      setState(() => _index++);
    }
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
        'Henüz hata yok.\n"Hatalarım" sekmesinden hatalı soru ekleyince '
        'burada çözebilirsin.',
        emoji: '📭',
      );
    }
    if (_completed) return _completionView();
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
                    value: _index / _items.length,
                    minHeight: 8,
                    backgroundColor: AppColors.line,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.green),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_index + 1}/${_items.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
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
        // Değerlendirme
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: Row(
            children: <Widget>[
              Expanded(
                child: GameButton(
                  label: 'Bilemedim',
                  color: AppColors.red,
                  icon: Icons.close_rounded,
                  onPressed: () => _answer(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GameButton(
                  label: 'Doğru çözdüm',
                  color: AppColors.green,
                  icon: Icons.check_rounded,
                  onPressed: () => _answer(true),
                ),
              ),
            ],
          ),
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
    if (e.photoUrl != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.network(
            e.photoUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _noPhotoText(e),
          ),
        ),
      );
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
                    : Image.network(e.photoUrl!, fit: BoxFit.contain),
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

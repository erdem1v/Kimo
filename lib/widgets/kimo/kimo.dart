import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'kimo_painter.dart';
import 'kimo_pose.dart';

export 'kimo_pose.dart' show KimoMood, KimoReaction;

/// Maskotun dışarıdan sürülen durumu.
///
/// Tasarımın sözleşmesi: animasyona **komut verilmez, girdi verilir**.
/// Ekranlar `mood`/`scanning` atar ve olay anında `trigger` çağırır; hangi
/// klibin oynayacağına durum makinesi karar verir.
class KimoController extends ChangeNotifier {
  KimoMood _mood = KimoMood.calm;
  bool _scanning = false;
  KimoReaction? _reaction;
  int _reactionSeq = 0;

  KimoMood get mood => _mood;
  set mood(KimoMood value) {
    if (_mood == value) return;
    _mood = value;
    notifyListeners();
  }

  /// Fotoğraf okunurken açılır: gözler yukarı kayar.
  bool get scanning => _scanning;
  set scanning(bool value) {
    if (_scanning == value) return;
    _scanning = value;
    notifyListeners();
  }

  KimoReaction? get reaction => _reaction;

  /// Her tetikte artar; widget yeni bir tepkinin başladığını buradan anlar.
  int get reactionSeq => _reactionSeq;

  /// Tepki tetikler. Çakışmada öncelik kazanır ve **düşük öncelikli tetik
  /// kuyruğa alınmaz, atılır** — kuyruk animasyonu klip gibi gösterir.
  void trigger(KimoReaction reaction) {
    final KimoReaction? current = _reaction;
    if (current != null && current.priority > reaction.priority) return;
    _reaction = reaction;
    _reactionSeq++;
    notifyListeners();
  }

  /// Widget tepki bittiğinde çağırır. [seq] eskiyse yok sayılır: arada yeni
  /// bir tepki başlamışsa onu iptal etmemeli.
  void endReaction(int seq) {
    if (seq != _reactionSeq || _reaction == null) return;
    _reaction = null;
    notifyListeners();
  }
}

/// Maskot Kimo.
///
/// İki katman aynı anda çalışır: kesintisiz boşta döngüsü ve üstüne binen tek
/// seferlik tepkiler. Ayrıntılar [KimoPoseSolver] içinde.
///
/// **Rive notu:** tasarım üretim varlığı olarak tek bir `.riv` (≤60 KB,
/// 300×330 artboard) öngörüyor ama o varlık henüz üretilmedi. Bu yüzden Kimo
/// şimdilik kodla çiziliyor. Widget'ın dış yüzeyi (`mood`, tetikler,
/// `reduceMotion`) bilerek Rive sözleşmesiyle aynı: varlık geldiğinde yalnızca
/// bu dosyanın içi değişir, çağıran ekranlar değişmez.
class Kimo extends StatefulWidget {
  const Kimo({
    super.key,
    required this.size,
    this.controller,
    this.mood,
    this.scanning,
    this.onTap,
    this.semanticLabel,
  });

  final double size;

  /// Verilmezse widget kendi denetleyicisini kurar (durumsuz kullanım).
  final KimoController? controller;

  /// [controller] verilmediğinde ruh hâli.
  final KimoMood? mood;

  /// [controller] verilmediğinde tarama durumu.
  final bool? scanning;

  /// Dokunma tepkisi her zaman oynar; bu geri çağrı ek iş içindir.
  final VoidCallback? onTap;

  final String? semanticLabel;

  @override
  State<Kimo> createState() => _KimoState();
}

class _KimoState extends State<Kimo> with SingleTickerProviderStateMixin {
  static const KimoPoseSolver _solver = KimoPoseSolver();

  late final ValueNotifier<KimoPose> _pose =
      ValueNotifier<KimoPose>(const KimoPose());
  late final Ticker _ticker;
  KimoController? _internal;

  /// Hareketi azalt açıkken tepkiyi bitiren tek mekanizma. Ticker durduğu için
  /// `_onTick` çalışmıyor ve tepki aksi hâlde sonsuza kadar takılı kalıyordu.
  Timer? _reactionTimer;

  Duration _elapsed = Duration.zero;
  Duration? _reactionStart;
  int _seenSeq = 0;
  bool _reduceMotion = false;

  KimoController get _controller => widget.controller ?? _internal!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internal = KimoController()
        ..mood = widget.mood ?? KimoMood.calm
        ..scanning = widget.scanning ?? false;
    }
    _controller.addListener(_onControllerChanged);
    // Dışarıdan gelen denetleyici bağlanmadan önce tetiklenmiş olabilir.
    // Sıra numarasını 0 kabul etmek iki hata üretiyordu: ya `endReaction`
    // eşleşmiyor ve tepki sonsuza kadar takılı kalıyordu, ya da `_reactionStart`
    // hiç kurulmadığı için `_onTick` bitişi hiç görmüyordu.
    _seenSeq = _controller.reactionSeq;
    _reactionStart = _controller.reaction == null ? null : Duration.zero;
    // `createTicker` TickerMode'a saygı duyar: başka bir rota üstteyken
    // animasyon kendiliğinden durur.
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;

    if (reduce) {
      if (_ticker.isActive) _ticker.stop();
      // Sürerken kapatıldıysa tepkinin bitmesi artık zamanlayıcıya bağlı.
      _armStaticReactionTimer();
      _solvePose();
      return;
    }

    _reactionTimer?.cancel();
    _reactionTimer = null;
    // `Ticker.stop()` başlangıcı sıfırlar: yeniden başlatıldığında `elapsed`
    // 0'dan gelir. Eski damgayla ölçüm negatife düşüp tepkiyi hiç
    // bitirmeyeceği için zaman çizgisi de sıfırlanıyor.
    _elapsed = Duration.zero;
    _reactionStart = _controller.reaction == null ? null : Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant Kimo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _internal?.removeListener(_onControllerChanged);
      if (widget.controller != null) {
        // Dışarıdan denetleyici geldi: içerideki artık sahipsiz, bırakılmazsa
        // sızar.
        _internal?.dispose();
        _internal = null;
      } else {
        _internal ??= KimoController();
      }
      _controller.addListener(_onControllerChanged);
      // Yeni denetleyicinin sıra numarası bambaşka. Eski damgayla devam edilse
      // ya tepki hiç başlamaz ya da `endReaction` eşleşmediği için hiç bitmez.
      _seenSeq = _controller.reactionSeq;
      _reactionStart = _controller.reaction == null ? null : _elapsed;
      _armStaticReactionTimer();
      _solvePose();
    }
    if (widget.controller == null && _internal != null) {
      if (widget.mood != null) _internal!.mood = widget.mood!;
      if (widget.scanning != null) _internal!.scanning = widget.scanning!;
    }
    if (widget.size != oldWidget.size) _solvePose();
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    _ticker.dispose();
    _controller.removeListener(_onControllerChanged);
    _internal?.dispose();
    _pose.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.reactionSeq != _seenSeq) {
      _seenSeq = _controller.reactionSeq;
      _reactionStart = _elapsed;
      _armStaticReactionTimer();
    }
    if (_reduceMotion) _solvePose();
  }

  /// Hareketi azalt açıkken tepkiyi süresi dolunca kapatır. Kapalıyken hiçbir
  /// şey yapmaz: o durumda bitişi `_onTick` yürütüyor.
  void _armStaticReactionTimer() {
    _reactionTimer?.cancel();
    _reactionTimer = null;
    final KimoReaction? reaction = _controller.reaction;
    if (!_reduceMotion || reaction == null) return;
    final int seq = _seenSeq;
    _reactionTimer = Timer(reaction.duration, () {
      if (!mounted) return;
      _controller.endReaction(seq);
      _solvePose();
    });
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;

    final KimoReaction? reaction = _controller.reaction;
    if (reaction != null && _reactionStart != null) {
      final Duration since = elapsed - _reactionStart!;
      if (since >= reaction.duration) {
        _reactionStart = null;
        _controller.endReaction(_seenSeq);
      }
    }
    _solvePose();
  }

  void _solvePose() {
    final KimoReaction? reaction = _controller.reaction;
    _pose.value = _solver.solve(
      elapsed: _elapsed,
      mood: _controller.mood,
      scanning: _controller.scanning,
      reduceMotion: _reduceMotion,
      size: widget.size,
      reaction: reaction,
      reactionElapsed: reaction == null || _reactionStart == null
          ? Duration.zero
          : _elapsed - _reactionStart!,
    );
  }

  void _handleTap() {
    _controller.trigger(KimoReaction.tap);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ValueListenableBuilder<KimoPose>(
            valueListenable: _pose,
            builder: (BuildContext context, KimoPose pose, Widget? child) {
              return CustomPaint(
                size: Size.square(widget.size),
                painter: KimoPainter(pose: pose),
              );
            },
          ),
        ),
      ),
    );
  }
}

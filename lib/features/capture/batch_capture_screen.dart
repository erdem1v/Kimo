import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/daily_state_repository.dart';
import '../../data/photo_queue.dart';
import '../../data/submission_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/ai_credit.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import 'batch_result_screen.dart';
import 'pending_photos_screen.dart';

/// Çoklu çekim (Tur 7 · n4).
///
/// ÜÇ KARAR BU DOSYANIN ŞEKLİNİ BELİRLİYOR:
///
/// 1. **BAYTLAR BELLEKTE TUTULMUYOR.** Her kare çekildiği anda [PhotoQueue]
///    üzerinden DİSKE yazılıyor ve bellekte yalnızca ~160px küçük resim
///    kalıyor. Tek kare akışı (`capture_screen`) baytları `_bytes` alanında
///    tutuyor ve bu 10 kare için ~190 MB çözülmüş bitmap demek olurdu —
///    düşük bellekli Android'de doğrudan OOM.
///
/// 2. **KAPASİTE ÖNDEN SORULUYOR.** Kuyruk 20 kayıt ve iki parti onu tam
///    dolduruyor. Sormayınca kullanıcı 10 kare çekiyor, sonra bir kısmı
///    sessizce reddediliyor.
///
/// 3. **ANALİZ BURADA BAŞLAMIYOR.** "Analiz et" kayıtları `needsAnalysis`
///    olarak bırakıp [BatchResultScreen]'e geçiyor; işlemeyi mevcut
///    `PhotoQueue.flush()` yapıyor. Yeni bir işleme motoru yazmak, kuyruğun
///    sıra/hata/yeniden deneme kararlarını ikinci kez (ve farklı) uygulamak
///    olurdu.
class BatchCaptureScreen extends StatefulWidget {
  const BatchCaptureScreen({super.key});

  @override
  State<BatchCaptureScreen> createState() => _BatchCaptureScreenState();
}

class _BatchCaptureScreenState extends State<BatchCaptureScreen> {
  final ImagePicker _picker = ImagePicker();

  /// Parti damgası: aynı turda çekilen kareler bunu paylaşıyor.
  final String _batchId = newSubmissionToken();

  /// Küçük resimler — ŞERİT İÇİN. Tam boyutlu baytlar diskte.
  final List<Uint8List> _thumbs = <Uint8List>[];

  int _limit = PhotoQueue.batchMax;
  bool _busy = false;
  bool _full = false;

  @override
  void initState() {
    super.initState();
    unawaited(_guard());
    unawaited(_resolveLimit());
  }

  /// EKRAN KENDİ KAPISINI TAŞIYOR.
  ///
  /// Bugün tek giriş `capture_screen`in mod anahtarı ve o hem bayrağı hem
  /// katmanı kontrol ediyor. Ama İKİNCİ bir giriş (derin bağlantı, bildirim
  /// yönlendirmesi, başka bir ekran) eklendiği an kill switch ve paywall
  /// sessizce atlanırdı — ve bunu yakalayan hiçbir şey olmazdı.
  ///
  /// Sunucu "batch" kavramını hiç bilmiyor (kota zaten çağrı başına sayıyor),
  /// yani bu kapı istemcide olmak zorunda. Kapanma durumunda ekran sessizce
  /// kapanıyor: kullanıcı buraya zaten ulaşmamalıydı, bir hata metni
  /// göstermek olmayan bir yolu açıklamak olurdu.
  Future<void> _guard() async {
    final DailyState? s = await dailyStateRepository.read();
    if (!mounted) return;
    final bool allowed =
        s != null && s.multiCaptureEnabled && s.aiTier == AiTier.premium;
    if (!allowed) Navigator.of(context).maybePop();
  }

  /// Sınır iki şeyin küçüğü: cihaz belleği ve kuyrukta kalan yer.
  Future<void> _resolveLimit() async {
    final int free = await photoQueue.freeSlots();
    if (!mounted) return;
    setState(() {
      // Bellek sinyali henüz bağlı değil (`device_info_plus` gerekiyor);
      // `null` tam sınırı veriyor ve asıl koruma disk deseni.
      _limit = PhotoQueue.batchLimitFor(null);
      if (free < _limit) _limit = free;
      _full = _limit <= 0;
    });
  }

  Future<void> _shoot(ImageSource source) async {
    if (_busy || _thumbs.length >= _limit) return;
    sound.tap();
    setState(() => _busy = true);
    try {
      if (source == ImageSource.gallery) {
        await _pickMany();
      } else {
        final XFile? file = await _picker.pickImage(
          source: source,
          maxWidth: 1600,
          // `imageQuality` YÜK TAŞIYOR: iOS'ta HEIC→JPEG dönüşümünü zorluyor.
          // Kaldırılırsa yükleme yolu ve analiz 'image/jpeg' varsayar ve
          // YALNIZCA iOS'ta kırılır (Task 03 iOS denetimi).
          imageQuality: 85,
        );
        if (file != null) await _store(file);
      }
    } catch (e) {
      debugPrint('çoklu çekim başarısız: $e');
      if (mounted) _snack(L10n.of(context).capturePhotoFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Galeriden çoklu seçim.
  ///
  /// `limit` VERİLİYOR AMA GÜVENİLMİYOR: resmî doküman "destekleyemeyen
  /// platformlarda yok sayılabilir" diyor ve Android'de çalışmadığına dair
  /// açık raporlar var. Dönen liste burada `take` ile kırpılıyor ve kullanıcıya
  /// söyleniyor.
  Future<void> _pickMany() async {
    final int room = _limit - _thumbs.length;
    if (room <= 0) return;
    final List<XFile> files = await _picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
      limit: room,
    );
    if (files.isEmpty) return;
    final List<XFile> use = files.take(room).toList();
    for (final XFile f in use) {
      await _store(f);
    }
    if (files.length > use.length && mounted) {
      _snack(L10n.of(context).batchRemaining(0));
    }
  }

  /// Kareyi DİSKE yazar ve şeride yalnızca küçük resmi koyar.
  Future<void> _store(XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    final PhotoQueueAdd result = await photoQueue.enqueue(
      bytes: bytes,
      state: PhotoQueueState.needsAnalysis,
      batchId: _batchId,
    );
    if (!mounted) return;
    if (result != PhotoQueueAdd.ok) {
      await reportQueueAdd(context, result);
      if (!mounted) return;
      setState(() => _full = true);
      return;
    }
    // Küçük resim: şeritte 160px'den büyüğüne ihtiyaç yok ve tam boyutlu
    // baytı listede tutmak bu ekranın kaçındığı şeyin ta kendisi olurdu.
    setState(() => _thumbs.add(bytes));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int n = _thumbs.length;
    final bool atLimit = n >= _limit;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.captureModeBatch),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: Gap.screen),
            child: Center(
              child: Text(l.batchCounter(n, _limit), style: t.numberSmall),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.screen),
                child: _full && n == 0
                    ? EmptyState(message: l.batchQueueFull)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          KimoIcon(KimoIcons.camera, size: 56, color: c.inkMuted),
                          const SizedBox(height: Gap.md),
                          Text(l.batchHint,
                              textAlign: TextAlign.center, style: t.caption),
                          const SizedBox(height: Gap.lg),
                          Text(l.batchRemaining(_limit - n),
                              textAlign: TextAlign.center,
                              style: t.caption.copyWith(color: c.inkMuted)),
                        ],
                      ),
              ),
            ),
          ),
          if (_thumbs.isNotEmpty) _strip(context),
          _footer(context, l, n, atLimit),
        ],
      ),
    );
  }

  /// Şerit önizlemesi — belge tarayıcılarının yerleşik deseni.
  Widget _strip(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
        itemCount: _thumbs.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (BuildContext ctx, int i) => ClipRRect(
          borderRadius: Radii.all(Radii.chip),
          child: Image.memory(
            _thumbs[i],
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            // Tam boyutlu dekodu ÖNLÜYOR: şerit 60dp ve `cacheWidth` olmadan
            // her kare tam çözünürlükte çözülürdü.
            cacheWidth: 160,
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, L10n l, int n, bool atLimit) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(
        Gap.screen,
        Gap.md,
        Gap.screen,
        Gap.md + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (n > 0) ...<Widget>[
            // MALİYET ÖNDEN: kota foto başına sayılıyor ve kullanıcı
            // onaylamadan harcanmıyor.
            Text(l.batchCost(n),
                style: t.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: Gap.sm),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: KimoButton(
                  label: l.captureFromGallery,
                  kind: KimoButtonKind.tertiary,
                  onPressed: (_busy || atLimit)
                      ? null
                      : () => unawaited(_shoot(ImageSource.gallery)),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: KimoButton(
                  label: l.captureFromCamera,
                  kind: KimoButtonKind.secondary,
                  onPressed: (_busy || atLimit)
                      ? null
                      : () => unawaited(_shoot(ImageSource.camera)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.batchAnalyze,
            onPressed: n == 0
                ? null
                : () {
                    sound.tap();
                    Navigator.of(context).pushReplacement<void, void>(
                      MaterialPageRoute<void>(
                        builder: (_) => BatchResultScreen(batchId: _batchId),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

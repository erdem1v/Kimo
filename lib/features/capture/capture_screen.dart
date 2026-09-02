import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/daily_state_repository.dart';
import '../../data/mistake_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import 'confirm_screen.dart';

/// 3e — Yanlışını çek.
///
/// Tam ekran karartma YOK: tarama fotoğrafın üstünde yürüyor ve her an iptal
/// edilebiliyor. Yapay zekâ burada yalnızca OKUYOR — çözmüyor.
///
/// TASARIMDAN BİLİNÇLİ SAPMA: mockup tarama sırasında adım adım bir kontrol
/// listesi gösteriyor ("Metin çıkarıldı ✓ · 5 şık bulundu ✓ · Konu
/// eşleştiriliyor…"). Analiz TEK bir çağrı ve ara durum yayınlamıyor; o listeyi
/// zamanlayıcıyla doldurmak, olmayan bir ilerlemeyi varmış gibi göstermek
/// olurdu — task'ın açıkça yasakladığı şey. Onun yerine tek ve dürüst bir
/// "okuyorum" durumu var; sonuçlar geldiklerinde görünüyor.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final KimoController _kimo = KimoController();

  Uint8List? _bytes;
  double? _aspect;
  bool _analyzing = false;

  /// Bugün kalan yapay zekâ okutma hakkı. `null` = henüz okunmadı ya da
  /// okunamadı; o durumda rozet GÖSTERİLMİYOR (yanlış bir sayı göstermektense
  /// hiç göstermemek doğru).
  int? _creditLeft;

  /// Analizden vazgeçildi mi. Yanıt geldiğinde bakılıyor: kullanıcı
  /// beklemekten vazgeçtiyse sonucu ONA RAĞMEN açmıyoruz.
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _loadCredit();
  }

  @override
  void dispose() {
    _kimo.dispose();
    super.dispose();
  }

  /// Kalan hakkı okur. Geri sayım YOK — tasarım kararı: yalnızca kalan sayı,
  /// tükenince "yarın yenilenecek".
  Future<void> _loadCredit() async {
    if (!SupabaseConfig.isConfigured) return;
    final DailyState? state = await dailyStateRepository.read();
    if (!mounted || state == null) return;
    setState(() => _creditLeft = state.aiLeft);
  }

  Future<void> _pick(ImageSource source) async {
    sound.tap();
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _aspect = null;
        _cancelled = false;
      });
      unawaited(_decodeAspect(bytes));
      if (SupabaseConfig.isConfigured) {
        await _analyze(bytes);
      } else {
        _openConfirm(bytes, null);
      }
    } catch (e) {
      debugPrint('fotoğraf alınamadı: $e');
      if (!mounted) return;
      _snack(L10n.of(context).capturePhotoFailed);
    }
  }

  /// Fotoğrafın en/boy oranı — dikey sorular küçük görünmesin diye alan buna
  /// göre boyutlanıyor.
  Future<void> _decodeAspect(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final double aspect = frame.image.width / frame.image.height;
      frame.image.dispose();
      if (mounted) setState(() => _aspect = aspect);
    } catch (_) {
      // Oran çözülemezse varsayılan kullanılır — görsel bir ayrıntı, akışı
      // durdurmuyor.
    }
  }

  Future<void> _analyze(Uint8List bytes) async {
    setState(() => _analyzing = true);
    _kimo.scanning = true;

    QuestionAnalysis result;
    try {
      result = await mistakeRepository.analyzeQuestion(bytes);
    } catch (e) {
      // Ağ hatası ya da sunucu reddi. Fotoğraf DURUYOR: elle giriş yoluna
      // düşüyoruz, kaydetme yolu kapanmıyor.
      debugPrint('analiz başarısız: $e');
      result = const QuestionAnalysis(
        ok: false,
        options: <QuestionOption>[],
        reason: null,
      );
    }

    if (!mounted) return;
    _kimo.scanning = false;
    setState(() {
      _analyzing = false;
      // Sunucu her yanıtta kalan hakkı bildiriyor; istemcide ayrıca saymıyoruz.
      if (result.creditRemaining != null) _creditLeft = result.creditRemaining;
      if (result.outOfCredit) _creditLeft = 0;
    });
    if (_cancelled) return;
    _openConfirm(bytes, result);
  }

  void _cancelAnalysis() {
    sound.tap();
    setState(() {
      _cancelled = true;
      _analyzing = false;
    });
    _kimo.scanning = false;
  }

  Future<void> _openConfirm(Uint8List? bytes, QuestionAnalysis? analysis) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ConfirmMistakeScreen(
          imageBytes: bytes,
          analysis: analysis,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      Navigator.of(context).pop(true);
    } else {
      // Kullanıcı vazgeçti: fotoğrafı koruyup çekim ekranında bırakıyoruz ki
      // yeniden çekmek zorunda kalmasın.
      setState(() {});
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(context, l),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                child: _bytes == null
                    ? _emptyState(context, l)
                    : _photoArea(context, t, l),
              ),
            ),
            if (_bytes == null) _pickActions(context, l),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.xs, Gap.md),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: KimoIcon(KimoIcons.close, color: c.ink),
            tooltip: l.actionClose,
          ),
          Expanded(
            child: Text(
              l.captureTitle,
              textAlign: TextAlign.center,
              style: t.section,
            ),
          ),
          if (_bytes != null)
            TextButton(
              onPressed: _analyzing ? null : () => _pick(ImageSource.camera),
              child: Text(l.captureRetake, style: t.buttonSmall),
            )
          else
            const SizedBox(width: Sizes.iconTap),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Kimo(size: 132, controller: _kimo, semanticLabel: 'Kimo'),
            const SizedBox(height: Gap.xl),
            Text(l.captureEmptyTitle, style: t.heading, textAlign: TextAlign.center),
            const SizedBox(height: Gap.sm),
            Text(
              l.captureEmptyBody,
              style: t.body,
              textAlign: TextAlign.center,
            ),
            if (_creditLeft != null) ...<Widget>[
              const SizedBox(height: Gap.lg),
              StatusBadge(
                label: l.creditLeft(_creditLeft!),
                tone: _creditLeft! > 0 ? BadgeTone.neutral : BadgeTone.pending,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pickActions(BuildContext context, L10n l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.md, Gap.screen, Gap.screen),
      child: Column(
        children: <Widget>[
          KimoButton(
            label: l.captureFromCamera,
            icon: const KimoIcon(KimoIcons.camera, size: 20),
            onPressed: () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.captureFromGallery,
            kind: KimoButtonKind.secondary,
            onPressed: () => _pick(ImageSource.gallery),
          ),
          const SizedBox(height: Gap.sm),
          // Fotoğrafsız yol: çevrimdışıyken ya da hak bittiğinde de aynı forma
          // çıkıyor. Kaydetme yolu ASLA kapanmıyor.
          KimoButton(
            label: l.captureManualEntry,
            kind: KimoButtonKind.tertiary,
            onPressed: () => _openConfirm(null, null),
          ),
        ],
      ),
    );
  }

  Widget _photoArea(BuildContext context, KimoTypography t, L10n l) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _aspect ?? (3 / 4),
              child: ClipRRect(
                borderRadius: Radii.all(Radii.card),
                child: Image.memory(_bytes!, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        if (_analyzing) _scanPanel(context, t, l) else _offlineNote(context, l),
        const SizedBox(height: Gap.screen),
      ],
    );
  }

  /// Tarama paneli. Fotoğrafın ÜSTÜNDE değil ALTINDA duruyor: mockup'ta panel
  /// fotoğrafı kısmen örtüyor ama o düzende dikey sorularda soru metni panelin
  /// arkasında kalıyor.
  Widget _scanPanel(BuildContext context, KimoTypography t, L10n l) {
    final KimoColors c = context.c;
    return KimoCard(
      color: c.actionTint,
      elevated: false,
      child: Row(
        children: <Widget>[
          Kimo(size: 48, controller: _kimo),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.captureScanning, style: t.bodyStrong),
                const SizedBox(height: Gap.xxs),
                Text(l.captureScanningDetail, style: t.caption),
              ],
            ),
          ),
          TextButton(
            onPressed: _cancelAnalysis,
            child: Text(
              l.actionCancel,
              style: t.buttonSmall.copyWith(color: c.actionText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineNote(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    if (SupabaseConfig.isConfigured && !_cancelled) return const SizedBox.shrink();
    return Row(
      children: <Widget>[
        KimoIcon(KimoIcons.lock, size: 18, color: c.inkMuted),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(l.captureOfflineNote, style: t.caption)),
      ],
    );
  }
}

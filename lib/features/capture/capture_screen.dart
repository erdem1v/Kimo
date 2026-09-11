import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/daily_state_repository.dart';
import '../../data/mistake_repository.dart';
import '../../data/photo_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';
import '../../services/crash_service.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../credit/credit_indicator.dart';
import '../credit/credit_wall_screen.dart';
import '../../services/ads/ad_service.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import 'confirm_screen.dart';
import 'pending_photos_screen.dart';

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
  const CaptureScreen({super.key, this.deferAnalysis = false});

  /// Analiz ERTELENSİN mi (onboarding'in ilk çekimi — A-2).
  ///
  /// Onboarding sırası `firstCapture → age → …`, yani ilk fotoğraf çekildiğinde
  /// kullanıcının yaşı HENÜZ BİLİNMİYOR. 13 yaş sınırını zorlamaya başladığımız
  /// hâlde fotoğrafın yaş bilinmeden yurt dışına çıkması hukuki metinlerle
  /// çelişiyordu.
  ///
  /// ADIM SIRASI DEĞİŞMİYOR: öğrenci hâlâ ilk iş olarak fotoğraf çekiyor.
  /// Değişen tek şey analizin ne zaman başladığı — fotoğraf yerelde kuyruğa
  /// giriyor, yaş adımı tamamlanınca analiz kendiliğinden çalışıyor. 13 altı
  /// reddedilirse kayıt ve dosya siliniyor (`PhotoQueue.purgeAgeGated`).
  final bool deferAnalysis;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final KimoController _kimo = KimoController();

  Uint8List? _bytes;
  double? _aspect;
  bool _analyzing = false;

  /// Sunucudan gelen hak durumu. `null` = henüz okunmadı ya da okunamadı; o
  /// durumda gösterge HİÇ ÇİZİLMİYOR (yanlış bir sayı göstermektense hiç
  /// göstermemek doğru).
  ///
  /// İstemci bu sayıyı KENDİ ARTIRIP AZALTMIYOR: analiz yanıtından sonra
  /// görünüm yeniden okunuyor. Yerel bir sayacı yamalamak, kotanın iki yerde
  /// yaşadığı yanılsamasını üretirdi.
  DailyState? _state;

  /// Analizden vazgeçildi mi. Yanıt geldiğinde bakılıyor: kullanıcı
  /// beklemekten vazgeçtiyse sonucu ONA RAĞMEN açmıyoruz.
  bool _cancelled = false;

  /// Tamamlanmış ama henüz kullanılmamış analiz sonucu.
  ///
  /// NEDEN VAR: "Vazgeç" isteği İPTAL ETMİYOR — `functions.invoke` iptal
  /// kabul etmiyor, yani istek sunucuda tamamlanıyor ve hak ZATEN harcanmış
  /// oluyor. Sonucu çöpe atmak, aynı fotoğrafla devam eden kullanıcıya ikinci
  /// bir çağrı (ve ikinci bir ücret) çıkarırdı. Burada tutuluyor; aynı
  /// fotoğrafla devam edilirse bedava kullanılıyor. Yeni fotoğraf çekilince
  /// sıfırlanıyor.
  QuestionAnalysis? _pendingAnalysis;

  @override
  void initState() {
    super.initState();
    _loadCredit();
    // Reklamı ERKEN ısıt: kullanıcı fotoğrafı çekip analiz bitene kadar
    // doluluk için bol zaman kalıyor, yani duvar genelde hazır reklamla
    // açılıyor. Ateşle-unut; başarısızlık sessiz.
    unawaited(AdService.instance.preload());
  }

  @override
  void dispose() {
    _kimo.dispose();
    super.dispose();
  }

  /// Hak durumunu okur. Geri sayım YOK — yalnızca durum ve (varsa) sonraki
  /// hakkın saati; ikisini de sunucu söylüyor.
  Future<void> _loadCredit() async {
    final DailyState? state = await dailyStateRepository.read();
    if (!mounted || state == null) return;
    setState(() => _state = state);
  }

  Future<void> _pick(ImageSource source) async {
    sound.tap();
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        // DİKKAT — imageQuality YÜK TAŞIYOR: bu bayrak image_picker'ı iOS'ta
        // HEIC'i JPEG'e dönüştürmeye zorluyor. Kaldırılırsa iOS kamerası HEIC
        // byte'ları döndürür; yükleme yolu ve analiz 'image/jpeg' varsayar ve
        // YALNIZCA iOS'ta kırılır (Task 03 iOS denetimi).
        imageQuality: 85,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _aspect = null;
        _cancelled = false;
        _pendingAnalysis = null;
      });
      unawaited(_decodeAspect(bytes));
      // AKTARIM BİLDİRİMİ (Task 03, 4.2): fotoğraf OpenAI'ya gitmeden önce,
      // tam gerçekleşeceği bağlamda bir kez onay istenir. Onay verilmezse
      // analiz HİÇ çağrılmaz; fotoğraf korunur ve elle giriş yolu açılır —
      // kaydetme yolu asla kapanmaz.
      //
      // ERTELENMİŞ ÇEKİMDE DE SORULUYOR ve KUYRUKTAN ÖNCE soruluyor. Aktarım
      // sonraya kalıyor ama onayın yeri değişmiyor: kuyruğa alınan fotoğraf
      // yaş adımından sonra kendiliğinden analiz ediliyor ve o an kullanıcı
      // ekranda olmayabilir. Onayı oraya bırakmak, aktarımı sessizce
      // onaysız yapmak olurdu. (`PhotoQueue.flush` ayrıca ikinci bir kapı
      // olarak onayı kontrol ediyor.)
      if (!userProfile.aiConsent) {
        final bool accepted = await _askAiConsent();
        if (!mounted) return;
        if (!accepted) {
          unawaited(_openConfirm(bytes, null));
          return;
        }
      }
      if (widget.deferAnalysis) {
        // Yaş kapısı: ne analiz ne yükleme, yalnızca yerel kuyruk.
        await _queueForAgeGate(bytes);
        return;
      }
      await _analyze(bytes);
    } catch (e) {
      debugPrint('fotoğraf alınamadı: $e');
      if (!mounted) return;
      _snack(L10n.of(context).capturePhotoFailed);
    }
  }

  /// Onboarding çekimi: fotoğrafı yaş kilidiyle kuyruğa alır ve ekranı kapatır.
  ///
  /// Onay ekranı AÇILMIYOR: analiz henüz yapılmadığı için ders/konu alanları
  /// boş gelirdi ve kullanıcı, kuruluşun ortasında AI'nın dolduracağı bir formu
  /// elle doldurmak zorunda kalırdı. Kayıt yaş adımından sonra "tamamlanmayı
  /// bekliyor" olarak görünüyor.
  Future<void> _queueForAgeGate(Uint8List bytes) async {
    final PhotoQueueAdd result = await photoQueue.enqueue(
      bytes: bytes,
      state: PhotoQueueState.needsAnalysis,
      gatedByAge: true,
    );
    if (!mounted) return;
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    await reportQueueAdd(context, result, okMessage: l.captureQueuedBody);
    if (!mounted) return;
    if (result == PhotoQueueAdd.ok) nav.pop(true);
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
        // Gerçek ağ hatası artık ayırt ediliyor: onay ekranı "bağlantı yok,
        // elle doldurabilirsin" diyebiliyor (eskiden bulanık fotoğrafla aynı
        // genel metni gösteriyordu).
        failure: AnalysisFailure.network,
      );
    }

    if (!mounted) return;
    _kimo.scanning = false;
    setState(() {
      _analyzing = false;
      // Sonuç HER ZAMAN saklanıyor: iptal edildiyse ya da onay ekranından
      // geri dönülürse aynı fotoğrafla devam etmek ikinci bir çağrı
      // gerektirmesin (hak çoktan harcandı).
      _pendingAnalysis = result;
    });
    // Sunucu durumu yeniden okunuyor; istemcide sayı yamalanmıyor.
    unawaited(_loadCredit());
    if (_cancelled) return;
    // HAK BİTTİYSE ÖNCE DUVAR. Eskiden doğrudan onay ekranı açılıyordu ve
    // "hak bitti" orada bir uyarı kartıydı; üç yolu (reklam / Plus / elle
    // giriş) eşit okunurlukta göstermek için tasarım onu ayrı bir ekrana
    // çıkardı. Kaydetme yolu duvarda BİRİNCİL eylem, yani kapanmıyor.
    if (result.outOfCredit) {
      unawaited(_openWallThen(bytes, result));
      return;
    }
    // Bilinçli ateşle-unut: onay ekranının kapanışını bu fonksiyon beklemiyor;
    // dönüş değeri `_openConfirm` içinde işleniyor.
    unawaited(_openConfirm(bytes, result));
  }

  /// Aktarım onayı sayfası. `true` = onaylandı (deftere yazılır).
  Future<bool> _askAiConsent() async {
    final L10n l = L10n.of(context);
    final KimoTypography t = context.t;
    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.screen,
          Gap.screen,
          Gap.screen + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l.aiConsentTitle, style: t.section),
            const SizedBox(height: Gap.sm),
            Text(l.aiConsentBody, style: t.body),
            const SizedBox(height: Gap.lg),
            KimoButton(
              label: l.aiConsentAccept,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Gap.sm),
            KimoButton(
              label: l.aiConsentDecline,
              kind: KimoButtonKind.tertiary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      // Defter yazımı ağa bağlı; başarısız olursa onay yerelde kalır ve bir
      // sonraki açılışta loadConsents gerçeği getirir. Analizi bekletmiyoruz.
      unawaited(userProfile.setAiConsent(true).catchError((Object e, StackTrace st) {
        reportError(e, st, context: 'setAiConsent');
      }));
      return true;
    }
    return false;
  }

  void _cancelAnalysis() {
    sound.tap();
    setState(() {
      _cancelled = true;
      _analyzing = false;
    });
    _kimo.scanning = false;
  }

  /// Duvarı açar; kullanıcı elle girişi seçerse AYNI fotoğrafla forma geçer.
  ///
  /// `dismissed` dalında hiçbir şey kapanmıyor: fotoğraf ekranda kalıyor ve
  /// `_photoArea` "Devam et" düğmesini çizmeye devam ediyor (bkz. oradaki
  /// yorum — o satır bu değişmez için TAŞIYICI).
  Future<void> _openWallThen(
      Uint8List? bytes, QuestionAnalysis? analysis) async {
    final DailyState? state = _state ?? await dailyStateRepository.read();
    if (!mounted) return;
    if (state == null) {
      // Durum okunamadıysa duvarı çizemeyiz — ama kaydetme yolu kapanmamalı,
      // o yüzden doğrudan forma geçiyoruz.
      unawaited(_openConfirm(bytes, analysis));
      return;
    }
    final CreditWallOutcome? out =
        await Navigator.of(context).push<CreditWallOutcome>(
      MaterialPageRoute<CreditWallOutcome>(
        builder: (_) => CreditWallScreen(state: state),
      ),
    );
    if (!mounted) return;
    switch (out) {
      case CreditWallOutcome.manualEntry:
        unawaited(_openConfirm(bytes, analysis));
      case CreditWallOutcome.creditGranted:
        // Hak geldi: aynı fotoğrafla yeniden analiz.
        unawaited(_loadCredit());
        if (bytes != null) unawaited(_analyze(bytes));
      case CreditWallOutcome.dismissed:
      case null:
        unawaited(_loadCredit());
        setState(() {});
    }
  }

  /// Fotoğrafsız duvar (henüz kare çekilmemişken hak bitmişse).
  Future<void> _openWall() => _openWallThen(null, null);

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
            const SizedBox(height: Gap.sm),
            // Aktarım gerçeği görünür yerde: yalnızca tek seferlik onay
            // sayfasına gömülü değil (Task 03, 4.2).
            Text(
              l.captureAiNote,
              style: t.caption,
              textAlign: TextAlign.center,
            ),
            if (creditIndicatorText(l, _state) != null) ...<Widget>[
              const SizedBox(height: Gap.lg),
              CreditIndicator(
                state: _state,
                onTap: (_state?.aiState?.isWall ?? false)
                    ? () => unawaited(_openWall())
                    : null,
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
                child: Image.memory(
                  _bytes!,
                  fit: BoxFit.contain,
                  // Bozuk/çözülemeyen byte'lar kareyi ÇÖKERTMESİN: eskiden
                  // errorBuilder yoktu ve build içinde fırlayan hata yayında
                  // gri kutuya dönüşüyordu.
                  errorBuilder: (BuildContext ctx, Object e, StackTrace? st) =>
                      Center(
                    child: Text(
                      L10n.of(ctx).photoBrokenNote,
                      style: ctx.t.caption,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        if (_analyzing)
          _scanPanel(context, t, l)
        else ...<Widget>[
          _offlineNote(context, l),
          const SizedBox(height: Gap.md),
          // KAYDETME YOLU ASLA KAPANMAZ — bu dal onu deliyordu. Analiz iptal
          // edilince (ya da onay ekranından geri dönülünce) fotoğraf ekranda
          // kalıyor ama `_pickActions` artık çizilmediği için kaydetmeye/elle
          // girişe götüren HİÇBİR düğme kalmıyordu; tek çıkış "Yeniden çek"
          // yani ikinci bir hak harcamaktı.
          //
          // TASK 10'DA BU SATIR AYRICA TAŞIYICI HÂLE GELDİ: hak bitince artık
          // tam ekran bir duvar açılıyor ve kullanıcı onu KAPATABİLİYOR
          // (`CreditWallOutcome.dismissed`). O dalda forma giden tek yol bu
          // düğme. Kaldırılırsa duvarı kapatan kullanıcı çıkmazda kalır.
          KimoButton(
            label: l.actionContinue,
            onPressed: () => _openConfirm(_bytes, _pendingAnalysis),
          ),
        ],
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
    // Yalnızca kullanıcı analizi iptal ettiyse görünür (eski "mock mod" hâli
    // kaldırıldı; uygulama artık yapılandırmasız hiç açılmıyor).
    if (!_cancelled) return const SizedBox.shrink();
    return Row(
      children: <Widget>[
        KimoIcon(KimoIcons.lock, size: 18, color: c.inkMuted),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(l.captureOfflineNote, style: t.caption)),
      ],
    );
  }
}

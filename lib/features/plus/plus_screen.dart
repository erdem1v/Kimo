import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/photo_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/legal_links.dart';
import '../../services/purchase_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_rich.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import 'plus_plans.dart';

/// Kimo Plus tanıtım ve plan ekranı (tasarımın w3'ü).
///
/// GİRİŞLER: hak duvarındaki Plus satırı/kartı ve Ayarlar → Kimo Plus.
///
/// SATIN ALMA (Task 13): üç eylem de GERÇEK — satın al, geri yükle, aboneliği
/// yönet. Üçü de Apple'ın doğrudan sorduğu şeyler ve üçü de `PurchaseService`
/// üzerinden gidiyor.
///
/// MAĞAZA YANITI YOKSA EKRAN BUGÜNKÜ DÜRÜST HÂLİNDE KALIYOR:
///   * Birincil düğme GÖRÜNÜR BİÇİMDE devre dışı (`onPressed: null`) ve
///     altında nedenini söyleyen tek bir satır var. Hiçbir şey yapmayan bir
///     düğme, kullanıcının dokunarak keşfettiği bir yalan olurdu.
///   * "Satın alımları geri yükle" ve "Aboneliği yönet" satırları HİÇ
///     ÇİZİLMİYOR. `services/legal_links.dart` aynı kararı yazıyor:
///     "'Hazırlanıyor' yer tutucusu bilinçli olarak geri getirilmedi: mağaza
///     incelemesinde doğrudan sorulan şey oydu." Hiçbir şeyi geri yüklemeyen
///     bir geri-yükle satırı kanonik bir App Store reddi.
///   * VE HİÇBİR FİYAT ÇİZİLMİYOR. Eskiden `1.200`/`150` TL yer tutucuları
///     canlı gösteriliyordu; Apple 3.1.2 gösterilen fiyatın mağazanın kendi
///     yerelleştirilmiş fiyatı olmasını şart koşuyor.
///
/// RAKAMLAR PARAMETRE, VARSAYILAN YOK: eskiden `?? 8/10/300/50/1000` yedeği
/// vardı ve Ayarlar girişi ekranı parametresiz açıyordu — `app_config`
/// sınırları değişince paywall eski rakamı göstermeye devam ediyordu (Task 11
/// raporu §9.1). Artık üç girişin üçü de sunucu değerlerini geçiriyor.
///
/// "SINIRSIZ" KELİMESİ HİÇBİR YERDE GEÇMİYOR: Plus'ın da tavanı var (8 saatte
/// 50, ayda 1.000). Rakam söyleniyor, abartı söylenmiyor. CI'da bir kapı bunu
/// ARB düzeyinde zorluyor.
///
/// AI KOÇ VE RAPOR LİSTEDE YOK: v1'de yok. Deponun standardı —
/// "arayüzde gösterilen her mekanik sunucuda gerçekten çalışıyor olmalı".
class PlusScreen extends StatefulWidget {
  const PlusScreen({
    super.key,
    required this.freeWindowLimit,
    required this.freeMonthLimit,
    required this.plusWindowLimit,
    required this.plusMonthLimit,
    required this.windowHours,
  });

  /// Kıyas tablosunun rakamları — HEPSİ SUNUCUDAN, `required`.
  ///
  /// Eskiden `int?` idi ve okunamayan değer koddaki 8/10/300/50/1000
  /// yedeğine düşüyordu. Ekran "8 saatte 50 analiz" gibi bir RAKAM VAADİ
  /// taşıyor; `app_config` sınırları gevşetildiğinde yalan söylemesi kabul
  /// edilemez. Değer okunamadıysa ekranı AÇMAYAN taraf çağıran.
  final int freeWindowLimit;
  final int freeMonthLimit;
  final int plusWindowLimit;
  final int plusMonthLimit;
  final int windowHours;

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  PlusPlan? _selected = PlusPlans.defaultPlan;

  @override
  void initState() {
    super.initState();
    // MAĞAZA YANITI GEÇ GELMİŞ OLABİLİR. Ürün sorgusu açılışta başlatılıyor
    // (`main.dart`) ve `await` edilmiyor; kullanıcı paywall'ı o sorgu
    // dönmeden açarsa liste boş olurdu ve ekran "satın alma kapalı" derdi.
    // Boşsa bir kez daha soruyoruz — dolu ise ağa hiç çıkmıyoruz.
    if (PlusPlans.current.isEmpty) unawaited(_loadProducts());
  }

  Future<void> _loadProducts() async {
    final List<PlusPlan> products = await Purchases.instance.products();
    if (!mounted || products.isEmpty) return;
    PlusPlans.setProducts(products);
    setState(() => _selected = PlusPlans.defaultPlan);
  }

  /// Satın alma ya da geri yükleme sürüyor — çift dokunuş iki isteğe
  /// dönüşmesin (`friends_view`'deki `_busy` deseni).
  bool _busy = false;

  int get _hours => widget.windowHours;
  int get _freeWindow => widget.freeWindowLimit;
  int get _freeMonth => widget.freeMonthLimit;
  int get _plusWindow => widget.plusWindowLimit;
  int get _plusMonth => widget.plusMonthLimit;

  /// "Bir oturumda N kat daha fazla analiz" — TÜRETİLİYOR, yazılmıyor.
  int get _multiplier =>
      _freeWindow > 0 ? (_plusWindow / _freeWindow).round() : 5;

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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                children: <Widget>[
                  Text(l.plusTitle, style: t.display),
                  const SizedBox(height: Gap.xs),
                  Text.rich(
                    emphasize(
                      l.plusLede(_multiplier),
                      l.plusLedeEmphasis(_multiplier),
                      base: t.body.copyWith(color: c.inkSecondary),
                      strong: t.bodyStrong.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  _batchSection(context, l),
                  const SizedBox(height: Gap.lg),
                  _compare(context, l),
                  const SizedBox(height: Gap.lg),
                  _plans(context, l),
                  const SizedBox(height: Gap.screen),
                ],
              ),
            ),
            _cta(context, l),
          ],
        ),
      ),
    );
  }

  /// Çoklu çekim bölümü (Tur 7 · n4 paywall'ı).
  ///
  /// ÜÇ MADDE VE ÜÇÜ DE RAKAM SÖYLÜYOR, abartı söylemiyor: kaç fotoğraf, hangi
  /// giriş, kaç analiz. Rakamlar sunucudan geliyor (`my_daily_state`), yani
  /// `app_config` sınırları gevşetilirse metin kendiliğinden doğru kalıyor.
  ///
  /// DİPNOT BİR TAAHHÜT: "Tekli çekim ücretsiz sürümde tam olarak çalışmaya
  /// devam eder." Deponun değişmezi — kaydetme yolu hiçbir koşulda kapanmıyor —
  /// burada kullanıcıya açıkça söyleniyor.
  Widget _batchSection(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      radius: Radii.card,
      padding: const EdgeInsets.all(Gap.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.plusBatchTitle, style: t.section),
          const SizedBox(height: Gap.xs),
          Text(l.plusBatchBody,
              style: t.caption.copyWith(color: c.inkSecondary)),
          const SizedBox(height: Gap.md),
          _bullet(context, KimoIcons.camera,
              l.plusBatchPhotos(PhotoQueue.batchMax)),
          _bullet(context, KimoIcons.notebook, l.plusBatchGallery),
          _bullet(context, KimoIcons.spark,
              l.plusBatchQuota(_hours, _plusWindow, _multiplier)),
          const SizedBox(height: Gap.sm),
          Text(l.plusBatchSingleFree,
              style: t.caption.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, KimoIconData icon, String text) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: <Widget>[
          KimoIcon(icon, size: 18, color: c.actionText),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: t.body)),
        ],
      ),
    );
  }

  // ======================================================== eylemler
  //
  // ÜÇÜ DE `PurchaseService` ÜZERİNDEN. Katman mağaza yokken hiçbir şey
  // yapmayan bir gerçeklemeye düşüyor ve o durumda bu üç yol zaten
  // ÇİZİLMİYOR — yani "hiçbir şey yapmayan düğme" hiç doğmuyor.
  //
  // SONUÇ KULLANICIYA SÖYLENMİYOR, ÇÜNKÜ SUNUCU SÖYLÜYOR: satın alma
  // tamamlandığında katman `my_daily_state.ai_tier` üzerinden premium'a
  // dönüyor. İstemci "aldın" diye bir şey İDDİA ETMİYOR — deponun değişmezi.
  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('satın alma akışı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buy() async {
    final PlusPlan? plan = _selected;
    if (plan == null) return;
    await _run(() => Purchases.instance.buy(plan));
  }

  Future<void> _restore() => _run(Purchases.instance.restore);

  void _openManage() {
    final Uri? uri = Purchases.instance.manageUri();
    if (uri != null) unawaited(openLegalUrl(uri.toString()));
  }

  Widget _topBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.screen, Gap.sm),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: KimoIcon(KimoIcons.close, color: c.ink),
            tooltip: l.actionClose,
          ),
        ],
      ),
    );
  }

  Widget _compare(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    final KimoColors c = context.c;
    return KimoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
            child: Row(
              children: <Widget>[
                const Expanded(child: SizedBox.shrink()),
                SizedBox(
                  width: 70,
                  child: Text(l.plusColFree,
                      textAlign: TextAlign.center,
                      style: t.overline.copyWith(color: c.inkMuted)),
                ),
                SizedBox(
                  width: 74,
                  child: Text(l.plusColPlus,
                      textAlign: TextAlign.center,
                      style: t.overline.copyWith(color: c.actionTextStrong)),
                ),
              ],
            ),
          ),
          _divider(context),
          _row(context, l.plusRowWindow(_hours), l.plusAnalyses(_freeWindow),
              l.plusAnalyses(_plusWindow)),
          _divider(context),
          _row(context, l.plusRowMonth, '$_freeMonth', '$_plusMonth'),
          _divider(context),
          _row(context, l.plusRowExtra, l.plusExtraFree, l.plusExtraPlus,
              plusHighlighted: false),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Container(height: 1, color: context.c.border);

  Widget _row(BuildContext context, String label, String free, String plus,
      {bool plusHighlighted = true}) {
    final KimoTypography t = context.t;
    final KimoColors c = context.c;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm + 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: t.bodyStrong)),
          SizedBox(
            width: 70,
            child: Text(free,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: c.inkSecondary)),
          ),
          SizedBox(
            width: 74,
            child: Text(
              plus,
              textAlign: TextAlign.center,
              style: plusHighlighted
                  ? t.numberSmall.copyWith(color: c.actionTextStrong)
                  : t.captionStrong.copyWith(color: c.mintText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plans(BuildContext context, L10n l) {
    final List<PlusPlan> plans = PlusPlans.current;
    // `IntrinsicHeight` ŞART: iki plan kartı eşit yükseklikte durmalı
    // (`stretch`) ama bu Row bir `ListView` içinde, yani dikey kısıtı sonsuz.
    // `stretch` tek başına "BoxConstraints forces an infinite height" ile
    // ekranı çökertiyordu — widget testi yakaladı.
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < plans.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: Gap.sm),
          Expanded(
            flex: plans[i].savingPercent != null ? 115 : 100,
            child: _planCard(context, l, plans[i]),
          ),
        ],
      ],
      ),
    );
  }

  Widget _planCard(BuildContext context, L10n l, PlusPlan plan) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool sel = plan.id == _selected?.id;
    final bool yearly = plan.savingPercent != null;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        KimoCard(
          radius: Radii.chip,
          color: sel ? c.actionTint : null,
          elevated: !sel,
          border: sel ? c.action : null,
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.md, vertical: Gap.sm + 2),
          onTap: () => setState(() => _selected = plan),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? c.action : null,
                      border: sel ? null : Border.all(color: c.border, width: 2),
                    ),
                    child: sel
                        ? Center(
                            child: KimoIcon(KimoIcons.check,
                                color: c.onAction, size: 12))
                        : null,
                  ),
                  const SizedBox(width: Gap.xs),
                  Text(
                    yearly ? l.plusPlanYearly : l.plusPlanMonthly,
                    style: t.captionStrong.copyWith(
                        color: sel ? c.actionTextStrong : c.inkSecondary),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xxs),
              Text(l.plusPerMonth(plan.perMonthLabel),
                  style: t.numberMedium
                      .copyWith(color: sel ? c.actionTextStrong : c.ink)),
              Text(
                yearly ? l.plusYearlyNote(plan.priceLabel) : l.plusMonthlyNote,
                style: t.caption.copyWith(color: c.inkSecondary),
              ),
            ],
          ),
        ),
        if (plan.savingPercent != null)
          Positioned(
            top: -9,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: c.mint,
                borderRadius: Radii.all(Radii.chip),
              ),
              child: Text(l.plusSaveBadge(plan.savingPercent!),
                  style: t.overline.copyWith(color: c.onAction)),
            ),
          ),
      ],
    );
  }

  Widget _cta(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.screen, Gap.md, Gap.screen, Gap.md),
      decoration: BoxDecoration(
        color: c.page,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        children: <Widget>[
          // `onPressed: null` MEKANİZMANIN TAMAMI: KimoButton devre dışı hâli
          // zaten doğru çiziyor (soluk zemin, kabartma kapalı,
          // Semantics(enabled: false)) — yeni koda gerek yok.
          KimoButton(
            label: l.plusCta(PlusPlans.trialDays),
            onPressed: (PlusPlans.isConfigured && _selected != null && !_busy)
                ? _buy
                : null,
          ),
          const SizedBox(height: Gap.xs),
          if (!PlusPlans.isConfigured)
            Text(
              l.plusNotAvailableYet,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: c.inkMuted),
            )
          else if (_selected != null)
            // OTOMATİK YENİLEME KOŞULLARI SATIN ALMA NOKTASINDA: Apple bunu
            // ZORUNLU tutuyor ve fiyat MAĞAZANIN metni.
            Text.rich(
              emphasize(
                l.plusTerms(
                  _selected!.savingPercent != null
                      ? l.plusPlanYearly
                      : l.plusPlanMonthly,
                  PlusPlans.trialDays,
                  _selected!.priceLabel,
                ),
                l.plusAutoRenew,
                base: t.caption.copyWith(color: c.inkSecondary),
                strong: t.captionStrong.copyWith(color: c.ink),
              ),
              textAlign: TextAlign.center,
            ),
          // Satın alma açılmadan bu iki satır ÇİZİLMİYOR (bkz. sınıf yorumu).
          if (PlusPlans.isConfigured) ...<Widget>[
            const SizedBox(height: Gap.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _link(context, l.plusRestore, _busy ? null : _restore),
                if (Purchases.instance.manageUri() != null)
                  _link(context, l.plusManage, _openManage),
              ],
            ),
          ],
          _legalRow(context, l),
        ],
      ),
    );
  }

  Widget _legalRow(BuildContext context, L10n l) {
    final bool terms = LegalLinks.has(LegalLinks.terms);
    final bool privacy = LegalLinks.has(LegalLinks.privacy);
    if (!terms && !privacy) return const SizedBox.shrink();
    final KimoTypography t = context.t;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (terms)
          _link(context, l.plusLegalTermsLabel,
              () => openLegalUrl(LegalLinks.terms)),
        if (terms && privacy)
          Text(' · ', style: t.caption.copyWith(color: context.c.inkMuted)),
        if (privacy)
          _link(context, l.plusLegalPrivacyLabel,
              () => openLegalUrl(LegalLinks.privacy)),
      ],
    );
  }

  Widget _link(BuildContext context, String label, VoidCallback? onTap) {
    final KimoTypography t = context.t;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, Sizes.iconTap),
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      ),
      child: Text(
        label,
        style: t.captionStrong.copyWith(
          color: context.c.actionTextStrong,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

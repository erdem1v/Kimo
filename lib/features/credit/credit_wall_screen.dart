import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/daily_state_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/ai_credit.dart';
import '../../models/tr_suffix.dart';
import '../../services/ads/ad_service.dart';
import '../../services/sound_service.dart';
import '../../state/credit_wall_log.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_rich.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../plus/plus_plans.dart';
import '../plus/plus_screen.dart';

/// Duvardan nasıl çıkıldı.
enum CreditWallOutcome {
  /// "Kaydet, şıkları elle gir" — ÜRÜNÜN DEĞİŞMEZ YOLU.
  manualEntry,

  /// Reklam ödülü sunucuda doğrulandı; hak geldi.
  creditGranted,

  /// Kapatıldı ya da vazgeçildi. Çağıran kaydetme yolunu AÇIK TUTMAK ZORUNDA.
  dismissed,
}

/// Hak bitti ekranı. Üç yol BİRLİKTE duruyor.
///
/// NEDEN TAM EKRAN ROTA: eskiden bu bir satır içi uyarı kartıydı ve onay
/// ekranının (elle giriş formunun) üstünde duruyordu. Tasarım onu ayrı bir
/// ekrana çıkardı çünkü üç yolu yan yana, eşit okunurlukta göstermek gerekiyor.
///
/// DEĞİŞMEZ: KAYDETME YOLU HİÇBİR KOŞULDA KAPANMAZ. Burada alta sabitlenmiş,
/// tam genişlik bir düğme olarak duruyor — bir kapatma düğmesi gibi değil.
/// [CreditWallOutcome.dismissed] dönüldüğünde de çağıran forma giden bir yol
/// çizmeye devam ediyor (bkz. `capture_screen.dart` `_photoArea`).
///
/// İKİ BAĞIMSIZ EKSEN (tasarımın w1/w2'si tek eksen gibi duruyor ama değil):
///   * BAŞLIK/GÖVDE ← `aiState`. w2'nin "Bu ay analiz hakkın doldu" başlığı
///     üç tetikleyicisinden birinde YALAN olurdu: bu hafta üçüncü kez
///     PENCEREYE çarpan kullanıcı ayını bitirmemiştir.
///   * PLUS'IN AĞIRLIĞI ← tekrar sayısı / reklam tavanı. İlk çarpmada sıradan
///     bir satır, tekrarda renkli kart (brief bölüm 5).
class CreditWallScreen extends StatefulWidget {
  const CreditWallScreen({super.key, required this.state, this.onSignUp});

  final DailyState state;

  /// Anonim dalında "Hesabını oluştur" eylemi. Verilmezse satır çizilmiyor.
  final VoidCallback? onSignUp;

  @override
  State<CreditWallScreen> createState() => _CreditWallScreenState();
}

class _CreditWallScreenState extends State<CreditWallScreen> {
  final KimoController _kimo = KimoController();

  int _weekCount = 0;
  bool _verifying = false;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _kimo.mood = KimoMood.calm;
    // Son şans: duvar açılırken bir reklam ısıt. Asıl ısınma fotoğraf
    // çekilirken başlıyor (`CaptureScreen.initState`).
    unawaited(AdService.instance.preload());
    unawaited(_countArrival());
  }

  Future<void> _countArrival() async {
    final int n = await creditWallLog.bump(widget.state.weekStart);
    if (mounted) setState(() => _weekCount = n);
  }

  @override
  void dispose() {
    _kimo.dispose();
    super.dispose();
  }

  DailyState get _s => widget.state;

  bool get _anonymous => _s.aiTier == AiTier.anonymous;

  /// Plus öne çıkarılsın mı.
  bool get _promote =>
      !_anonymous &&
      (_weekCount >= CreditWallLog.promoteAt ||
          _s.aiState == AiState.monthFull ||
          (_s.adRewardsLeft ?? 0) <= 0);

  /// Reklam satırı çizilsin mi.
  ///
  /// `adOffer` kararını SUNUCU veriyor (katman, askı, günlük tavan, aylık cap,
  /// pencere). İstemci yalnızca "elimde gösterebileceğim bir reklam var mı"
  /// sorusunu ekliyor. Üç ayrı sessiz neden: desteklenmeyen platform,
  /// yapılandırılmamış birim, doluluk yok.
  ///
  /// `adRewardEnabled` KILL SWITCH'İ (göç 0079). Task 13'e kadar bu bayrağın
  /// üretim kodunda TEK BİR OKUYUCUSU YOKTU: `app_config`'e
  /// `ff_ad_reward = 'false'` yazmak hiçbir şeyi değiştirmiyordu, yani
  /// "AdMob'dan politika uyarısı geldi, reklamı sürüm beklemeden kapat"
  /// senaryosu çalışmıyordu. Sunucuda da bir kapı var (`ai_state().ad_offer`,
  /// göç 0094) — o eski istemcileri de kapsıyor; buradaki ise ağ trafiğini
  /// bile doğurmuyor.
  bool get _showAdRow =>
      _s.adRewardEnabled &&
      _s.adOffer &&
      AdService.instance.supported &&
      AdService.instance.isReady;

  /// Günlük tavan dolduğunda satır TIKLANAMAZ BİLGİYE dönüyor (kaybolmuyor).
  bool get _showAdCapRow =>
      _s.adRewardEnabled &&
      !_anonymous &&
      _s.aiTier == AiTier.free &&
      (_s.adRewardsLeft ?? -1) == 0 &&
      _s.aiMonthLeft > 0;

  String get _title {
    final L10n l = L10n.of(context);
    return switch (_s.aiState) {
      AiState.monthFull => l.creditWallTitleMonth,
      AiState.lifetimeFull => l.creditWallTitleLifetime,
      _ => l.creditWallTitleWindow,
    };
  }

  /// Gövde metni ve içinde kalınlaşacak parça.
  ({String text, String? strong}) get _body {
    final L10n l = L10n.of(context);
    if (_s.aiState == AiState.lifetimeFull) {
      return (
        text: l.creditWallBodyLifetime,
        strong: null,
      );
    }
    if (_s.aiState == AiState.monthFull) {
      final String? on = trLocativeMonthDay(_s.aiMonthResetsOn);
      final String head = on == null ? '' : l.creditWallBodyMonth(on);
      final String tail = _weekCount >= CreditWallLog.promoteAt
          ? ' ${l.creditWallRepeat(trOrdinal(_weekCount))} — '
              '${l.creditWallRepeatTail(_s.plusMonthLimit)}'
          : '';
      return (text: '$head$tail'.trim(), strong: on);
    }
    final String? at = trLocativeTime(_s.aiNextAtHm);
    // Saat gelmediyse cümlenin o yarısı yerine yalnızca kaydetme davetini
    // bırakıyoruz — delikli bir cümle basmaktan iyi.
    final String text = at == null
        ? l.creditWallSaveInfo
        : l.creditWallBodyWindow(_s.aiWindowHours, _s.aiWindowLimit, at);
    return (text: text, strong: at);
  }

  // -------------------------------------------------------------- reklam yolu
  Future<void> _watchAd() async {
    if (_verifying) return;
    sound.tap();
    setState(() {
      _verifying = true;
      _pending = false;
    });

    // 1) Nonce SUNUCUDAN. İstemci uyduramıyor.
    final String? nonce = await dailyStateRepository.startAdReward();
    if (!mounted) return;
    if (nonce == null) {
      // Sunucu "işe yaramaz" dedi (ay dolu, tavan dolu, katman…). HATA DEĞİL:
      // satır sessizce boşa dönüyor.
      setState(() => _verifying = false);
      return;
    }

    // 2) Reklamı göster. `earned` KANIT DEĞİL.
    final AdOutcome outcome =
        await AdService.instance.showRewarded(nonce: nonce);
    if (!mounted) return;
    if (outcome != AdOutcome.earned) {
      // Erken kapattı / gösterilemedi. Mesaj YOK.
      setState(() => _verifying = false);
      return;
    }

    // 3) Ödülü SUNUCUDAN bekle. `my_daily_state` yoklanıyor: hakkın tek
    //    doğruluk kaynağı orası ve "istemci hesaplamaz" kuralı korunuyor.
    //    Bedeli: "SSV gelmedi" ile "SSV geldi ve reddedildi" ayırt edilemiyor,
    //    o yüzden zaman aşımı metni suçlayıcı ya da kesin değil.
    const List<int> backoffMs = <int>[0, 1000, 2000, 3000, 5000, 8000];
    for (final int ms in backoffMs) {
      if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
      if (!mounted) return;
      final DailyState? fresh = await dailyStateRepository.read();
      if (!mounted) return;
      if (fresh != null && (fresh.aiLeft ?? 0) > 0) {
        Navigator.of(context).pop(CreditWallOutcome.creditGranted);
        return;
      }
    }
    setState(() {
      _verifying = false;
      _pending = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _closeRow(context, l),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                children: <Widget>[
                  _header(context, l),
                  const SizedBox(height: Gap.lg),
                  ..._paths(context, l),
                  const SizedBox(height: Gap.md),
                  _saveInfo(context, l),
                  const SizedBox(height: Gap.screen),
                ],
              ),
            ),
            _saveBar(context, l),
          ],
        ),
      ),
    );
  }

  Widget _closeRow(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.screen, 0),
      child: Row(
        children: <Widget>[
          Container(
            width: Sizes.iconTap,
            height: Sizes.iconTap,
            decoration: BoxDecoration(color: c.sunken, shape: BoxShape.circle),
            child: IconButton(
              onPressed: () =>
                  Navigator.of(context).pop(CreditWallOutcome.dismissed),
              icon: KimoIcon(KimoIcons.close, color: c.inkSecondary, size: 20),
              tooltip: l.actionClose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final ({String text, String? strong}) body = _body;
    return Column(
      children: <Widget>[
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: c.actionTint, shape: BoxShape.circle),
          child: Center(
            child: Kimo(size: 70, controller: _kimo, semanticLabel: 'Kimo'),
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(_title, style: t.title, textAlign: TextAlign.center),
        const SizedBox(height: Gap.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text.rich(
            emphasize(
              body.text,
              body.strong,
              base: t.body.copyWith(color: c.inkSecondary),
              strong: t.bodyStrong.copyWith(color: c.ink),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  List<Widget> _paths(BuildContext context, L10n l) {
    final List<Widget> rows = <Widget>[];

    if (_anonymous) {
      // Anonim: reklam ve Plus YOK. Reklam hakkı vermek yeni bir anonim
      // oturumla sıfırlama yolu olurdu; Plus da kalıcı hesap gerektiriyor.
      if (widget.onSignUp != null) {
        rows.add(_row(
          context,
          tint: context.c.actionTint,
          iconColor: context.c.actionText,
          icon: KimoIcons.spark,
          title: l.creditWallSignUpTitle,
          subtitle: l.creditWallSignUpSubtitle,
          trailing: _chevron(context),
          onTap: widget.onSignUp,
        ));
      }
      return rows;
    }

    if (_showAdRow) {
      rows.add(_adRow(context, l));
      rows.add(const SizedBox(height: Gap.sm));
    } else if (_showAdCapRow) {
      rows.add(_adCapRow(context, l));
      rows.add(const SizedBox(height: Gap.sm));
    }
    // Hiçbiri değilse satır HİÇ çizilmiyor: doluluk yok, platform desteksiz ya
    // da yapılandırma eksik. Hata diyaloğu, snackbar, kırmızı metin YOK.

    rows.add(_promote ? _plusCard(context, l) : _plusRow(context, l));
    return rows;
  }

  Widget _adRow(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int left = _s.adRewardsLeft ?? 0;
    return _row(
      context,
      tint: c.mintTint,
      iconColor: c.mintText,
      icon: KimoIcons.play,
      title: l.creditWallAdTitle,
      subtitle: _verifying
          ? l.creditWallAdVerifying
          : l.creditWallAdSubtitle(left),
      trailing: _verifying
          // Bekleme SATIRDA duruyor; alttaki Kaydet düğmesine dokunulmuyor ve
          // ETKİN kalıyor — bekleme üçüncü yolu asla kapatmaz.
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(c.mintText),
              ),
            )
          : Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              decoration: BoxDecoration(
                color: c.mintTint,
                borderRadius: Radii.all(Radii.button),
              ),
              alignment: Alignment.center,
              child: Text(
                l.creditWallAdAction,
                style: t.buttonSmall.copyWith(color: c.mintText),
              ),
            ),
      onTap: _verifying ? null : _watchAd,
    );
  }

  Widget _adCapRow(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    return _row(
      context,
      tint: c.sunken,
      iconColor: c.inkMuted,
      icon: KimoIcons.play,
      title: l.creditWallAdCapTitle,
      subtitle: l.creditWallAdCapSubtitle(_s.adRewardsPerDay),
      muted: true,
      // TIKLANAMAZ: tavan dolu, dokunmanın bir karşılığı yok.
      onTap: null,
    );
  }

  Widget _plusRow(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    return _row(
      context,
      tint: c.actionTint,
      iconColor: c.actionText,
      icon: KimoIcons.spark,
      title: l.creditWallPlusTitle,
      subtitle: l.creditWallPlusSubtitle(
        _s.aiWindowHours,
        _s.plusWindowLimit,
        PlusPlans.trialDays,
      ),
      trailing: _chevron(context),
      onTap: () => _openPlus(context),
    );
  }

  /// Tekrar çarpmada Plus: renkli kart, kıyas tablosu, birincil CTA.
  ///
  /// Ekrandaki TEK `primary` burada (w2). Kaydetme düğmesi `secondary`ye
  /// düşüyor ama TAM GENİŞLİK ve aynı minimum yükseklikte kalıyor —
  /// tasarımın şartı boyutla karşılanıyor, dolguyla değil.
  Widget _plusCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final PlusPlan? yearly = PlusPlans.defaultPlan;
    return KimoCard(
      color: c.actionTint,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _iconTile(context, KimoIcons.spark, c.card, c.actionText),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  l.creditWallPlusTitle,
                  style: t.section.copyWith(color: c.actionTextStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          KimoCard(
            elevated: false,
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: Gap.sm),
            radius: Radii.chip,
            child: Column(
              children: <Widget>[
                _compareRow(context, l.plusRowWindow(_s.aiWindowHours),
                    '${_s.aiWindowLimit}', '${_s.plusWindowLimit}'),
                const SizedBox(height: Gap.xs),
                _compareRow(context, l.plusRowMonth, '${_s.aiMonthLimit}',
                    '${_s.plusMonthLimit}'),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.plusCta(PlusPlans.trialDays),
            onPressed: () => _openPlus(context),
          ),
          // FİYAT YALNIZCA MAĞAZA YANITIYLA ÇİZİLİYOR. Eskiden burada
          // `plus_plans.dart`'taki sabit TL yer tutucuları canlı
          // gösteriliyordu — Apple 3.1.2 gösterilen fiyatın mağazanın kendi
          // yerelleştirilmiş fiyatı olmasını şart koşuyor ve ortada tahsil
          // eden bir mekanizma bile yoktu. Mağaza yanıtı yoksa künye HİÇ
          // çizilmiyor; kart yine de Plus'ı tanıtıyor ve dokunuş paywall'ı
          // açıyor.
          if (yearly != null) ...<Widget>[
            const SizedBox(height: Gap.xs),
            Text.rich(
              emphasize(
                l.plusTrialNote(yearly.priceLabel, yearly.perMonthLabel),
                l.plusAutoRenew,
                base: t.caption.copyWith(color: c.actionText),
                strong: t.captionStrong.copyWith(color: c.actionTextStrong),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _compareRow(
      BuildContext context, String label, String free, String plus) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: t.caption)),
        SizedBox(
          width: 48,
          child: Text(free,
              textAlign: TextAlign.right,
              style: t.caption.copyWith(color: c.inkMuted)),
        ),
        const SizedBox(width: Gap.sm),
        SizedBox(
          width: 56,
          child: Text(plus,
              textAlign: TextAlign.right,
              style: t.numberSmall.copyWith(color: c.actionTextStrong)),
        ),
      ],
    );
  }

  Widget _saveInfo(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      color: c.sunken,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          KimoIcon(KimoIcons.shield, color: c.inkSecondary, size: 20),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              _pending ? l.creditWallAdPending : l.creditWallSaveInfo,
              style: t.caption.copyWith(color: c.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// DEĞİŞMEZ: her dalda var, her dalda etkin, her dalda tam genişlik.
  Widget _saveBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.md, Gap.screen, Gap.screen),
      decoration: BoxDecoration(
        color: c.page,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        children: <Widget>[
          KimoButton(
            label: l.creditWallSaveAction,
            // w1'de birincil, w2'de ikincil — ama İKİSİNDE DE tam genişlik,
            // aynı minimum yükseklik ve etkin. Tasarım: "küçültülmedi".
            kind: _promote ? KimoButtonKind.secondary : KimoButtonKind.primary,
            minHeight: Sizes.buttonMin,
            onPressed: () =>
                Navigator.of(context).pop(CreditWallOutcome.manualEntry),
          ),
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.actionCancel,
            kind: KimoButtonKind.tertiary,
            onPressed: () =>
                Navigator.of(context).pop(CreditWallOutcome.dismissed),
          ),
        ],
      ),
    );
  }

  void _openPlus(BuildContext context) {
    sound.tap();
    // RAKAMLAR SUNUCUDAN GEÇİYOR (Task 12). Eskiden `const PlusScreen()` ile
    // parametresiz açılıyordu, yani `app_config` sınırları değişse bile ekran
    // sabit 10/300/50/1000 yedeğini gösteriyordu — bilinen ve düzeltilmemiş
    // kusur. Paywall artık "8 saatte 50 analiz" gibi bir RAKAM VAADİ
    // taşıdığı için yanlış sayı göstermek kabul edilemez.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlusScreen(
          freeWindowLimit: _s.freeWindowLimit,
          freeMonthLimit: _s.freeMonthLimit,
          plusWindowLimit: _s.plusWindowLimit,
          plusMonthLimit: _s.plusMonthLimit,
          windowHours: _s.aiWindowHours,
        ),
      ),
    );
  }

  Widget _chevron(BuildContext context) =>
      KimoIcon(KimoIcons.forward, color: context.c.inkMuted, size: 18);

  Widget _iconTile(
      BuildContext context, KimoIconData icon, Color bg, Color fg) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.all(Radii.chip),
      ),
      child: Center(child: KimoIcon(icon, color: fg, size: 20)),
    );
  }

  Widget _row(
    BuildContext context, {
    required Color tint,
    required Color iconColor,
    required KimoIconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool muted = false,
  }) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      radius: Radii.button,
      onTap: onTap,
      color: muted ? c.sunken : null,
      elevated: !muted,
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.md, vertical: Gap.sm + 2),
      child: Row(
        children: <Widget>[
          _iconTile(context, icon, tint, iconColor),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: t.bodyStrong
                      .copyWith(color: muted ? c.inkSecondary : c.ink),
                ),
                Text(subtitle,
                    style: t.caption.copyWith(color: c.inkSecondary)),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Gap.sm),
            trailing,
          ],
        ],
      ),
    );
  }
}

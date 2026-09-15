import 'package:flutter/material.dart';

import '../../data/daily_state_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/ai_credit.dart';
import '../../models/tr_suffix.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';

/// Hak hapının GÖRÜNÜMÜ — tek doğruluk kaynağı.
///
/// Dört durumun (artı iki kenar durumun) ikon/rakam/metin/renk seçimi bu saf
/// fonksiyonda toplanıyor ve test tam bu noktaya bakıyor. Eskiden yalnızca
/// metin üretiliyordu; ikon geri gelince "hangi ikon, rakam var mı, nabız atsın
/// mı" soruları da aynı karara bağlandı — üç ayrı yerde dallanmak, durumların
/// bir tanesinde sessizce ayrışmanın en kolay yolu olurdu.
@immutable
class CreditPillSpec {
  const CreditPillSpec({
    required this.filled,
    required this.text,
    required this.semanticLabel,
    required this.tone,
    this.timeText,
    this.locked = false,
    this.pulse = false,
  });

  /// Kalp dolu mu (hak var) yoksa kontur mu (pencere/ay doldu).
  final bool filled;

  /// Hapta görünen birincil metin: rakam ya da kısa saat/tarih.
  final String text;

  /// Ekran okuyucuya giden TAM cümle. Hap kısalttı, erişilebilirlik
  /// kısalmadı — eski uzun `creditState*` anahtarları bu yüzden silinmedi.
  final String semanticLabel;

  /// `low` durumunda rakamın yanında ayırıcıyla duran saat. Diğer durumlarda
  /// `null`: `windowFull`/`monthFull` zamanı [text] içinde taşıyor.
  final String? timeText;

  /// Anonim ömür hakkı bitti: kilit simgesi ekleniyor. Tasarım bu durumu
  /// çizmiyor; `monthFull` renk çiftini paylaşıp kilitle ayrışıyor.
  final bool locked;

  /// Kalp 2 sn'de bir nabız atsın mı. YALNIZCA `low`'da açık.
  ///
  /// Sıfıra düştüğünde nabız DURUYOR ve kalp kontura dönüyor — tasarımın
  /// açık kuralı: "yanıp sönme YOK, kaygı üretmemek için".
  final bool pulse;

  final CreditTone tone;
}

/// Nabız ve pop animasyonlarının test anahtarları.
///
/// Üretimde bir işi yok; `byType` ile aranmaları hangi `ScaleTransition`ın
/// bulunduğunu garanti etmiyordu (Material'ın kendi bileşenleri de kullanıyor).
@visibleForTesting
const Key beatKey = Key('creditPillBeat');
@visibleForTesting
const Key popKey = Key('creditPillPop');

/// Hapın renk ailesi. Tasarımın üç kovası (mercan / bal / nötr) token'lara
/// birebir oturuyor, o yüzden burada renk değil KOVA taşınıyor.
enum CreditTone { coral, honey, neutral }

/// Hap görünümünü üretir. `null` dönerse HİÇBİR ŞEY çizilmiyor.
///
/// Üç ayrı `null` var ve üçü de "bilmiyorum" demek, "sıfır" demek değil:
///   1. `state == null`   → görünüm okunamadı ya da durum tanınmadı.
///   2. `aiLeft == null`  → sayı gelmedi.
///   3. Durumun gerektirdiği saat/tarih eksik → delikli bir hap basmak
///      yerine sessiz kalıyoruz.
CreditPillSpec? creditPillSpec(L10n l, DailyState? s) {
  if (s == null) return null;
  final AiState? state = s.aiState;
  final int? left = s.aiLeft;
  if (state == null || left == null) return null;

  switch (state) {
    case AiState.ok:
      return CreditPillSpec(
        filled: true,
        tone: CreditTone.coral,
        text: l.creditPillCount(left),
        semanticLabel: l.creditStateOk(left),
      );

    case AiState.low:
      final String? at = trLocativeTime(s.aiNextAtHm);
      // Saat yoksa sayıyı tek başına göstermek eksik ama yanlış değil; "az
      // kaldı" bilgisi kullanıcıya yarıyor, o yüzden nabız ve bal rengi
      // korunuyor, yalnızca saat düşüyor.
      return CreditPillSpec(
        filled: true,
        pulse: true,
        tone: CreditTone.honey,
        text: l.creditPillCount(left),
        timeText: s.aiNextAtHm,
        semanticLabel:
            at == null ? l.creditStateOk(left) : l.creditStateLow(left, at),
      );

    case AiState.windowFull:
      final String? hm = s.aiNextAtHm;
      final String? at = trLocativeTime(hm);
      if (hm == null || at == null) return null;
      return CreditPillSpec(
        filled: false,
        tone: CreditTone.neutral,
        text: l.creditPillNext(hm),
        semanticLabel: l.creditStateWindowFull(at),
      );

    case AiState.monthFull:
      // `monthFull` dalı `aiNextAtHm`i HİÇ OKUMUYOR. Ürün kuralı: aylık sınır
      // dolduğunda pencere saati gösterilmez, çünkü o saat artık bir şey vaat
      // etmiyor. Sunucu da o durumda alanı `null` gönderiyor; fonksiyonun
      // şekli bunu ikinci kez garanti ediyor ve test tam bunu iddia ediyor.
      final DateTime? on = s.aiMonthResetsOn;
      final String? onSuffixed = trLocativeMonthDay(on);
      if (on == null || onSuffixed == null) return null;
      return CreditPillSpec(
        filled: false,
        tone: CreditTone.neutral,
        text: l.creditPillMonth(trMonthDay(on)!),
        semanticLabel: l.creditStateMonthFull(onSuffixed),
      );

    case AiState.lifetimeFull:
      return CreditPillSpec(
        filled: false,
        locked: true,
        tone: CreditTone.neutral,
        text: '',
        semanticLabel: l.creditStateLifetimeFull,
      );

    case AiState.suspended:
      // Askı kendi ekranında anlatılıyor; HUD'da hak konuşmuyor.
      return null;
  }
}

/// Hakkın TAM CÜMLESİ — dokununca açılan sayfa ve "çizilecek bir şey var mı"
/// kontrolü için.
///
/// Hap kısaldı (Tur 7 · n1) ama uzun cümle kaybolmadı: yer değiştirdi.
/// [creditPillSpec] ile AYNI karar ağacından türüyor, yani sayfa ile hap
/// birbirinden ayrışamıyor — eskiden tek bir metin fonksiyonu vardı ve o
/// özelliği korumak bu paketin açık hedefiydi. `null` dönerse hiçbir yerde
/// hak konuşulmuyor.
String? creditIndicatorText(L10n l, DailyState? s) =>
    creditPillSpec(l, s)?.semanticLabel;

/// HUD ve fotoğraf ekranındaki hak göstergesi.
///
/// TEK KALP + RAKAM (Tur 7 · n1). On iki kalp çizilmiyor — Task 10'un
/// reddettiği şey tam olarak o tekrardı. İkon "hangi kaynak" sorusunu
/// yanıtladığı için hapta cümle taşınmıyor; tam cümle `semanticLabel`'da ve
/// dokununca açılan sayfada duruyor. Adın "hak" olması değişmedi.
class CreditIndicator extends StatefulWidget {
  const CreditIndicator({super.key, required this.state, this.onTap});

  final DailyState? state;
  final VoidCallback? onTap;

  @override
  State<CreditIndicator> createState() => _CreditIndicatorState();
}

class _CreditIndicatorState extends State<CreditIndicator>
    with TickerProviderStateMixin {
  /// `low` durumundaki 2 sn'lik nabız.
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: Motion.pulse,
  );

  /// Sayı ARTTIĞINDA bir kez oynayan 400 ms'lik pop.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: Motion.pop,
  );

  int? _lastLeft;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      if (reduce) {
        _beat.stop();
        _beat.value = 0;
        _pop.stop();
        _pop.value = 0;
      }
    }
    _sync();
  }

  @override
  void didUpdateWidget(CreditIndicator old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Nabzı ve pop'u duruma göre sürer.
  ///
  /// Nabız yalnızca `low`'da dönüyor; hak sıfıra düştüğünde DURUYOR. Pop
  /// yalnızca sayı BÜYÜDÜĞÜNDE oynuyor — küçüldüğünde (hak harcandığında)
  /// kutlama yapmak yanlış sinyal olurdu.
  void _sync() {
    final int? left = widget.state?.aiLeft;
    final bool pulse = widget.state?.aiState == AiState.low;

    if (_reduceMotion) {
      _lastLeft = left;
      return;
    }

    if (pulse && !_beat.isAnimating) {
      _beat.repeat(reverse: true);
    } else if (!pulse && _beat.isAnimating) {
      _beat.stop();
      _beat.value = 0;
    }

    final int? prev = _lastLeft;
    if (left != null && prev != null && left > prev) {
      _pop.forward(from: 0);
    }
    _lastLeft = left;
  }

  @override
  void dispose() {
    _beat.dispose();
    _pop.dispose();
    super.dispose();
  }

  /// Tasarımın üç renk kovası → token çifti.
  ///
  /// Kova taşımanın sebebi: aynı üç çift hem açık hem koyu temada tasarımın
  /// verdiği değerlerle BİREBİR eşleşiyor, yani burada ikinci bir palet
  /// tanımlamaya gerek yok.
  (Color bg, Color fg, Color glyph) _colors(KimoColors c, CreditTone tone) {
    switch (tone) {
      case CreditTone.coral:
        return (c.actionTintStrong, c.actionText, c.action);
      case CreditTone.honey:
        return (c.honeyTint, c.honeyText, c.honey);
      case CreditTone.neutral:
        return (c.sunken, c.inkSecondary, c.inkMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final CreditPillSpec? spec = creditPillSpec(l, widget.state);
    // Okunamadığında sıfır göstermek, gerçekten sıfır olmasıyla ayırt
    // edilemezdi. Bu yüzden hiç çizmiyoruz.
    if (spec == null) return const SizedBox.shrink();

    final KimoColors c = context.c;
    final (Color bg, Color fg, Color glyph) = _colors(c, spec.tone);

    Widget heart = KimoIcon(
      spec.filled ? KimoIcons.heart : KimoIcons.heartOutline,
      size: 17,
      color: glyph,
    );
    if (spec.pulse && !_reduceMotion) {
      heart = ScaleTransition(
        // Key TESTİN hedefi: sayfada başka `ScaleTransition`lar da var
        // (pop, Material iç bileşenleri) ve `byType` hangisini bulduğunu
        // garanti etmiyordu.
        key: beatKey,
        scale: Tween<double>(begin: 1, end: 1.12).animate(
          CurvedAnimation(parent: _beat, curve: Curves.easeInOut),
        ),
        child: heart,
      );
    }

    final List<Widget> parts = <Widget>[
      if (spec.text.isNotEmpty)
        Text(
          spec.text,
          maxLines: 1,
          // Hap kısaldı ama büyük yazı tipi ölçeğinde hâlâ taşabilir; kırpma
          // burada, çünkü `HudPill` bilerek `Expanded` döndürmüyor.
          overflow: TextOverflow.ellipsis,
          style: context.t.numberSmall.copyWith(color: fg),
        ),
      if (spec.timeText != null) ...<Widget>[
        const SizedBox(width: Gap.sm),
        Container(width: 1, height: 14, color: fg.withValues(alpha: 0.3)),
        const SizedBox(width: Gap.sm),
        Text(
          spec.timeText!,
          maxLines: 1,
          style: context.t.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
        ),
      ],
      if (spec.locked) ...<Widget>[
        if (spec.text.isNotEmpty) const SizedBox(width: Gap.sm),
        KimoIcon(KimoIcons.lock, size: 14, color: fg),
      ],
    ];

    Widget pill = HudPill(
      background: bg,
      foreground: fg,
      icon: heart,
      onTap: widget.onTap,
      semanticLabel: spec.semanticLabel,
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );

    if (!_reduceMotion) {
      pill = ScaleTransition(
        key: popKey,
        scale: Tween<double>(begin: 1, end: 1.06).animate(
          CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
        ),
        child: pill,
      );
    }
    return pill;
  }
}

import 'package:flutter/material.dart';

import '../../data/daily_state_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/ai_credit.dart';
import '../../models/tr_suffix.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_progress.dart';

/// Hak göstergesinin metni — SAF fonksiyon, tek doğruluk kaynağı.
///
/// `null` dönerse HİÇBİR ŞEY çizilmiyor. Üç ayrı durumda `null` dönüyor ve
/// üçü de "bilmiyorum" demek, "sıfır" demek değil:
///   1. `state == null`   → görünüm okunamadı ya da durum tanınmadı.
///   2. `aiLeft == null`  → sayı gelmedi.
///   3. Durumun gerektirdiği saat/tarih eksik → delikli bir cümle basmak
///      yerine sessiz kalıyoruz.
///
/// `monthFull` dalı `aiNextAtHm`i HİÇ OKUMUYOR. Ürün kuralı: aylık sınır
/// dolduğunda pencere saati gösterilmez, çünkü o saat artık bir şey vaat
/// etmiyor. Sunucu da o durumda alanı `null` gönderiyor; fonksiyonun şekli
/// bunu ikinci kez garanti ediyor ve test tam bunu iddia ediyor.
String? creditIndicatorText(L10n l, DailyState? s) {
  if (s == null) return null;
  final AiState? state = s.aiState;
  final int? left = s.aiLeft;
  if (state == null || left == null) return null;

  switch (state) {
    case AiState.ok:
      return l.creditStateOk(left);

    case AiState.low:
      final String? at = trLocativeTime(s.aiNextAtHm);
      // Saat yoksa sayıyı tek başına göstermek yanlış değil ama eksik; yine de
      // "az kaldı" bilgisi kullanıcıya yarıyor, o yüzden `ok` metnine düşüyoruz.
      return at == null ? l.creditStateOk(left) : l.creditStateLow(left, at);

    case AiState.windowFull:
      final String? at = trLocativeTime(s.aiNextAtHm);
      return at == null ? null : l.creditStateWindowFull(at);

    case AiState.monthFull:
      final String? on = trLocativeMonthDay(s.aiMonthResetsOn);
      return on == null ? null : l.creditStateMonthFull(on);

    case AiState.lifetimeFull:
      return l.creditStateLifetimeFull;

    case AiState.suspended:
      // Askı kendi ekranında anlatılıyor; HUD'da hak konuşmuyor.
      return null;
  }
}

/// HUD ve fotoğraf ekranındaki hak göstergesi.
///
/// İKONSUZ, bilinçli: kalp silindi. Kayan pencerede hak zamanla geri geliyor
/// ve "2 hakkın kaldı · sonraki 14:30'da" bir ikonla anlatılamıyor.
class CreditIndicator extends StatelessWidget {
  const CreditIndicator({super.key, required this.state, this.onTap});

  final DailyState? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final String? text = creditIndicatorText(l, state);
    // Okunamadığında sıfır göstermek, gerçekten sıfır olmasıyla ayırt
    // edilemezdi. Bu yüzden hiç çizmiyoruz.
    if (text == null) return const SizedBox.shrink();

    final KimoColors c = context.c;
    final bool out = state?.aiState?.hasCredit == false;
    return HudPill(
      background: out ? c.honeyTint : c.sunken,
      foreground: out ? c.honeyText : c.inkSecondary,
      onTap: onTap,
      semanticLabel: text,
      child: Text(
        text,
        maxLines: 1,
        // `monthFull` metni 360dp'de sığmıyor: seri hapı + "Seviye N" ile
        // birlikte ~205dp kalıyor. `HudPill` bilerek `Expanded` döndürmüyor,
        // o yüzden kırpma burada. Dokununca tam cümle sayfada açılıyor.
        overflow: TextOverflow.ellipsis,
        style: context.t.numberSmall.copyWith(
          color: out ? c.honeyText : c.inkSecondary,
        ),
      ),
    );
  }
}

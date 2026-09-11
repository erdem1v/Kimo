import 'package:flutter/widgets.dart';

/// Cümle ortasında tek bir parçayı kalınlaştırır.
///
/// NEDEN VAR: tasarım dört yerde cümlenin ortasındaki bir parçayı vurguluyor —
/// "Sonraki hakkın **14:30'da** açılır", "**otomatik yenilenir**", "Bir
/// oturumda **5 kat daha fazla analiz**". ARB biçimleme TAŞIYAMIYOR: bir
/// `.arb` değeri düz metin, içine `<b>` koymak da onu HTML'e çevirmez.
///
/// [part] bulunamazsa TÜM metin düz dönüyor, fırlatmıyor: eksik bir kalın
/// kozmetik bir kayıp, çöken bir ekran değil. Zaman/tarih vurgularında [part]
/// az önce yerleştirilen yer tutucu değerinin kendisi olduğu için eşleşme
/// garanti; sabit parçalarda ([plusAutoRenew] gibi) parça KENDİ ARB anahtarı
/// olarak duruyor, böylece iki metin birbirinden ayrışamıyor.
TextSpan emphasize(
  String full,
  String? part, {
  required TextStyle base,
  required TextStyle strong,
}) {
  if (part == null || part.isEmpty) {
    return TextSpan(text: full, style: base);
  }
  final int i = full.indexOf(part);
  if (i < 0) return TextSpan(text: full, style: base);
  return TextSpan(
    style: base,
    children: <InlineSpan>[
      if (i > 0) TextSpan(text: full.substring(0, i)),
      TextSpan(text: part, style: strong),
      if (i + part.length < full.length)
        TextSpan(text: full.substring(i + part.length)),
    ],
  );
}

/// Türkçe bulunma hâli eki (-de / -da / -te / -ta).
///
/// NEDEN BU DOSYA VAR: tasarım "sonraki hakkın **14:30'da** açılır" ve
/// "**1 Ekim'de** yenilenir" yazıyor. O iki örnek doğru ama değerler keyfî:
///
///     14:30'da   15:00'te   16:00'da   13:00'te   14:05'te   14:20'de
///     Ekim'de    Kasım'da   Ağustos'ta  Aralık'ta  Mart'ta
///
/// Ek, sayının ya da ayın **okunuşuna** göre değişiyor. Sabit bir `'da`
/// yazmak üretilen zamanların kabaca yarısını Türkçe bilen bir 16 yaşındakine
/// bozuk gösterirdi. İkisi de KAPALI KÜME (saat 0-23, dakika 0-59, 12 ay),
/// yani tabloyla tam çözülüyor.
///
/// KURAL: ek, sayının SON OKUNAN KELİMESİNE bakıyor.
///   * Dakika 0 değilse son kelime dakikadan gelir  → `14:30` → "otuz"  → 'da
///   * Dakika 0 ise saatten gelir                   → `15:00` → "beş"   → 'te
/// Kelime → ek eşlemesi ünlü uyumu (a/ı/o/u → kalın, e/i/ö/ü → ince) ve
/// sert ünsüz benzeşmesi (f s t k ç ş h p → t'li biçim) sonucudur; tablo o
/// sonucu taşıyor, kuralı çalışma anında yeniden türetmiyor.
///
/// `intl` KULLANILMIYOR: `DateFormat` `initializeDateFormatting` çağrısı
/// gerektiriyor ve depo tarihleri her yerde elle biçimlendiriyor
/// (`widgets/mistake_style.dart:37` `formatShortDate`,
/// `features/capture/pending_photos_screen.dart` `_stamp`).
library;

/// 0-59 arasındaki bir sayının okunuşundaki SON kelime.
String? _lastWord(int n) {
  if (n < 0 || n > 59) return null;
  if (n % 10 == 0) {
    return const <int, String>{
      0: 'sıfır',
      10: 'on',
      20: 'yirmi',
      30: 'otuz',
      40: 'kırk',
      50: 'elli',
    }[n];
  }
  return const <String>[
    'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz',
  ][n % 10 - 1];
}

/// Sayı okunuşlarının bulunma hâli eki. On beş kelime, kapalı küme.
const Map<String, String> _numberSuffix = <String, String>{
  'sıfır': 'da',  // ı kalın, r yumuşak
  'bir': 'de',    // i ince,  r yumuşak
  'iki': 'de',
  'üç': 'te',     // ü ince,  ç sert
  'dört': 'te',   // ö ince,  t sert
  'beş': 'te',    // e ince,  ş sert
  'altı': 'da',
  'yedi': 'de',
  'sekiz': 'de',
  'dokuz': 'da',
  'on': 'da',
  'yirmi': 'de',
  'otuz': 'da',
  'kırk': 'ta',   // ı kalın, k sert
  'elli': 'de',
};

/// Ay adları ve ekleri (1 = Ocak).
const List<List<String>> _months = <List<String>>[
  <String>['Ocak', 'ta'],      // a kalın, k sert
  <String>['Şubat', 'ta'],     // a kalın, t sert
  <String>['Mart', 'ta'],
  <String>['Nisan', 'da'],
  <String>['Mayıs', 'ta'],     // ı kalın, s sert
  <String>['Haziran', 'da'],
  <String>['Temmuz', 'da'],
  <String>['Ağustos', 'ta'],   // o kalın, s sert
  <String>['Eylül', 'de'],     // ü ince,  l yumuşak
  <String>['Ekim', 'de'],
  <String>['Kasım', 'da'],
  <String>['Aralık', 'ta'],    // ı kalın, k sert
];

/// Sunucunun verdiği `HH:MM` (Istanbul duvar saati) → `14:30'da`.
///
/// Çözümlenemezse `null` — çağıran delikli bir cümle basmak yerine hiçbir şey
/// göstermeli. Saat İSTEMCİDE üretilmiyor: cihaz saatini değiştiren bir
/// öğrenciye yanlış saat gösterilmesin diye sunucudan hazır geliyor.
String? trLocativeTime(String? hm) {
  if (hm == null) return null;
  final List<String> parts = hm.trim().split(':');
  if (parts.length != 2) return null;
  final int? h = int.tryParse(parts[0]);
  final int? m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  final String? word = _lastWord(m == 0 ? h : m);
  final String? suffix = word == null ? null : _numberSuffix[word];
  if (suffix == null) return null;
  final String hh = h.toString().padLeft(2, '0');
  final String mm = m.toString().padLeft(2, '0');
  return "$hh:$mm'$suffix";
}

/// Istanbul takvim günü → `1 Ekim'de`.
///
/// Ay adı ARB'de değil burada: `formatShortDate` emsali (kısa ay adları da
/// Dart'ta) ve ek ay adına bağlı, yani ikisinin ayrı dosyalarda yaşaması
/// sessiz bir uyuşmazlık riski olurdu. Uygulama tek dilli.
String? trLocativeMonthDay(DateTime? date) {
  if (date == null) return null;
  if (date.month < 1 || date.month > 12) return null;
  final List<String> m = _months[date.month - 1];
  return "${date.day} ${m[0]}'${m[1]}";
}

/// Istanbul takvim günü → `1 Ekim` (EKSİZ).
///
/// [trLocativeMonthDay]'in kardeşi. Hap dar olduğu için ekli biçim orada
/// taşınmıyor (Tur 7 · n1: hapta `1 Ekim`, sayfada `1 Ekim'de yenilenir`).
/// Ay adı listesi ikisinde de aynı yerden okunuyor; ayrı bir listeye
/// kopyalamak sessiz bir uyuşmazlık riski olurdu.
String? trMonthDay(DateTime? date) {
  if (date == null) return null;
  if (date.month < 1 || date.month > 12) return null;
  return '${date.day} ${_months[date.month - 1][0]}';
}

/// Sıra sayısının Türkçe kelimesi — "ikinci", "üçüncü"…
///
/// Tasarım "Bu hafta **üçüncü** kez karşılaştık" yazıyor. ICU çoğul biçimi bunu
/// taşıyamıyor: yalnızca `=0`, `=1`, `=2` ve adlandırılmış kategorileri kabul
/// ediyor, `=3` sözdizimi hatası veriyor. Kelime bu yüzden burada.
///
/// Küçük sayılar için kelime, büyükler için rakam (`"12."`) — `practiceTimesSeen`
/// anahtarının zaten kullandığı yedek. Duvar sayacı haftalık olduğu için
/// pratikte 2-5 aralığında kalıyor.
String trOrdinal(int n) => const <int, String>{
      1: 'ilk',
      2: 'ikinci',
      3: 'üçüncü',
      4: 'dördüncü',
      5: 'beşinci',
      6: 'altıncı',
      7: 'yedinci',
      8: 'sekizinci',
      9: 'dokuzuncu',
      10: 'onuncu',
    }[n] ??
    '$n.';

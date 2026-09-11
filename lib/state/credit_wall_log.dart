import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının bu hafta hak duvarına kaç kez çarptığı.
///
/// NEDEN İSTEMCİDE: brief her yeni SAYAÇ için sunucu sahipliği, kilit ve
/// pgTAP negatif testi şart koşuyor — ve haklı. Ama bu sayının ürün dışında
/// hiçbir değeri yok: kötüye kullanılsa en fazla kullanıcı kendine Plus
/// kartını erken gösterir. Bir kota sayacı değil, bir sunum kararı. O yüzden
/// `shared_preferences`'ta duruyor ve sunucuda karşılığı YOK.
///
/// HAFTA ANAHTARI SUNUCUDAN: `my_daily_state.week_start` (Istanbul ISO
/// haftası). Cihaz saatinden hafta üretmek Task 03'te kapatılan hatanın
/// aynısı olurdu — saatini ileri alan kullanıcı sayacı sıfırlayabilirdi.
/// `DateTime.now()` bu dosyada HİÇ çağrılmıyor.
class CreditWallLog {
  CreditWallLog._();

  static final CreditWallLog instance = CreditWallLog._();

  static const String _kWeek = 'credit_wall.week_start';
  static const String _kCount = 'credit_wall.count';

  /// Plus'ın öne çıkarılacağı çarpma sayısı. İlk çarpmada Plus sıradan bir
  /// satır, ikinci ve sonrasında renkli kart (brief bölüm 5).
  static const int promoteAt = 2;

  /// Bu haftaki çarpma sayısı. `weekStart` okunamadıysa (`null`) sayaç
  /// ARTIRILMIYOR ve 0 dönülüyor — bilinmeyen durumda nazik tarafa,
  /// yani baskısız w1'e düşüyoruz.
  Future<int> bump(DateTime? weekStart) async {
    if (weekStart == null) return 0;
    final String key = _weekKey(weekStart);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_kWeek);
      final int next = stored == key ? (prefs.getInt(_kCount) ?? 0) + 1 : 1;
      if (stored != key) await prefs.setString(_kWeek, key);
      await prefs.setInt(_kCount, next);
      return next;
    } catch (e) {
      // Disk okunamazsa duvar yine açılmalı; yalnızca ağırlık kararı düşüyor.
      debugPrint('duvar sayacı yazılamadı: $e');
      return 0;
    }
  }

  /// Artırmadan okur (test ve tanı için).
  Future<int> read(DateTime? weekStart) async {
    if (weekStart == null) return 0;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kWeek) != _weekKey(weekStart)) return 0;
      return prefs.getInt(_kCount) ?? 0;
    } catch (e) {
      debugPrint('duvar sayacı okunamadı: $e');
      return 0;
    }
  }

  /// `2026-09-07` — saat bileşeni yok, sunucunun verdiği takvim günü.
  static String _weekKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
}

final CreditWallLog creditWallLog = CreditWallLog.instance;

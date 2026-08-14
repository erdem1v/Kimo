import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cihaz ayarlarına köprü (MainActivity.kt içindeki kanal).
///
/// Android 13+'ta bildirim izni iki kez reddedilirse sistem penceresi bir daha
/// açılmaz; tek çıkış yolu ayar ekranıdır. Kullanıcıyı elle "Ayarlar → Uygulama
/// → Bildirimler" yolculuğuna çıkarmamak için oraya doğrudan gidiyoruz.
class SystemSettings {
  const SystemSettings._();

  static const MethodChannel _channel = MethodChannel('aiyks/system');

  /// Uygulamanın bildirim ayarları ekranını açar.
  static Future<void> openNotificationSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (e) {
      debugPrint('Bildirim ayarları açılamadı: $e');
    }
  }
}

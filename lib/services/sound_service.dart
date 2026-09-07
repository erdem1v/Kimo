import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../state/app_settings.dart';

/// Kısa ses efektlerini çalan servis. Sesler `assets/sounds/` altında sentetik
/// üretilmiş WAV dosyalarıdır. Web'de sesin çalması için kullanıcı etkileşimi
/// (buton dokunuşu) gerekir; bu yüzden efektler dokunma anında tetiklenir.
///
/// Açık/kapalı tercihi burada tutulmuyor: `AppSettings` üzerinden gelir ve
/// diske yazılır. Önceden yalnızca bellekteydi, yani her açılışta kendiliğinden
/// açılıyordu — bir ayar anahtarının yapmaması gereken tam olarak buydu.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  // Tembel oluşturulur; ses kapalıyken (veya testte) hiç AudioPlayer yaratılmaz.
  AudioPlayer? _player;

  bool get enabled => appSettings.soundEnabled;

  Future<void> _play(String name) async {
    if (!enabled) return;
    try {
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource('sounds/$name.wav'));
    } catch (_) {
      // Ses çalınamazsa sessizce yut (ör. web otomatik oynatma kısıtı).
      // Burada sessizlik bilinçli: ses efekti bir sonuç taşımıyor, çalmaması
      // kullanıcının işini bölmez ve gösterilecek bir hata da yok.
    }
  }

  // Dönüş türü BİLİNÇLİ olarak void: ses efekti tanımı gereği ateşle-unut.
  // Future döndürmek, her çağrı yerinde `unawaited(...)` sarmalamayı
  // gerektiriyordu (unawaited_futures lint'i) ve beklemek hiçbir zaman
  // istenen davranış değildi.
  void correct() => unawaited(_play('correct'));
  void wrong() => unawaited(_play('wrong'));
  void tap() => unawaited(_play('tap'));
  void levelUp() => unawaited(_play('levelup'));
}

/// Kısa erişim.
final SoundService sound = SoundService.instance;

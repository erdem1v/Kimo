import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

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

  /// Ses oturumu bir kez yapılandırıldı mı.
  bool _contextSet = false;

  bool get enabled => appSettings.soundEnabled;

  Future<void> _play(String name) async {
    if (!enabled) return;
    try {
      if (!_contextSet) {
        _contextSet = true;
        // SESSİZ DÜĞMESİNE SAYGI (Task 15).
        //
        // `audioplayers` varsayılanı `respectSilence: false`, yani iOS'ta
        // kategori `playback` oluyordu: ses telefon SESSİZDEYKEN BİLE
        // çıkıyordu. Sınıfta, kütüphanede ya da otobüste çalışan bir öğrenci
        // için bu tek başına yeterli bir kusur.
        //
        // `respectSilence: true` iOS'ta kategoriyi `ambient` yapıyor: sessiz
        // düğmesi susturuyor ve arka planda çalan müzik kesilmiyor. Odak
        // `gain` kalmak ZORUNDA — paket `respectSilence` ile `mixWithOthers`
        // birleşimini assert ile reddediyor ve `ambient` karışmayı zaten
        // kendiliğinden sağlıyor.
        await AudioPlayer.global
            .setAudioContext(AudioContextConfig(respectSilence: true).build());
      }
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
  void levelUp() => unawaited(_play('levelup'));

  /// Dokunma geri bildirimi — SES DEĞİL, TİTREŞİM (Task 15).
  ///
  /// 85 çağrı yeri var: her çip, her satır, her düğme. 50 ms'lik sentetik bir
  /// bip'i bu sıklıkta çalmak yaygın bir kalıp değil; mobil normu dokunuşta
  /// titreşim, sesi yalnızca SONUÇ anlarına (doğru, yanlış, seviye atlama)
  /// saklamak. Ses varsayılan olarak AÇIK geldiği için de kullanıcı bunu
  /// kapatmadan önce yaşıyordu.
  ///
  /// Çağrı yerleri bilinçli olarak DEĞİŞMEDİ: karar tek dosyada duruyor,
  /// geri almak da tek satır. `assets/sounds/tap.wav` yerinde bırakıldı.
  ///
  /// Titreşim `appSettings.soundEnabled`e BAĞLI DEĞİL: o anahtar sesi
  /// yönetiyor, titreşim ise işletim sisteminin kendi ayarına uyuyor
  /// (`selectionClick` sessiz düğmesini ve sistem titreşim tercihini zaten
  /// dinliyor).
  void tap() => unawaited(HapticFeedback.selectionClick());
}

/// Kısa erişim.
final SoundService sound = SoundService.instance;

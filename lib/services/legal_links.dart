import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Yayınlanan hukuki metinlerin adresleri.
///
/// `SupabaseConfig` ile BİREBİR aynı desen: değerler derleme sırasında
/// `--dart-define-from-file=supabase.json` ile geliyor, kaynağa gömülmüyor.
/// Gerekçe: adresler henüz yayınlanmadı ve yayınlandıklarında değişebilirler;
/// sabit kodlanmış bir URL yanlış bir belgeye götürürdü.
///
/// SUNUCUDAN OKUNMUYOR — `app_config` istemciye tamamen kapalı (servis rolü
/// anahtarı orada duruyor) ve bir bağlantı listesi için ona bir kapı açmak
/// orantısız olurdu. Onay kaydındaki METİN SÜRÜMÜ ise sunucudan geliyor
/// (`app_config.legal_version`): onun ispat değeri var, adresin yok.
///
/// Adres verilmemişse ilgili satır arayüzde HİÇ ÇİZİLMİYOR. "Hazırlanıyor"
/// yer tutucusu bilinçli olarak geri getirilmedi: mağaza incelemesinde
/// doğrudan sorulan şey oydu.
class LegalLinks {
  const LegalLinks._();

  /// Kullanım Koşulları.
  static const String terms = String.fromEnvironment('LEGAL_TERMS_URL');

  /// Gizlilik Politikası. App Store Connect ve Play Console bunu ZORUNLU
  /// tutuyor; aynı adres oraya da girilmeli.
  static const String privacy = String.fromEnvironment('LEGAL_PRIVACY_URL');

  /// KVKK Aydınlatma Metni.
  static const String kvkk = String.fromEnvironment('LEGAL_KVKK_URL');

  /// Play'in istediği, uygulama DIŞINDAN erişilebilen hesap silme sayfası.
  static const String accountDeletion =
      String.fromEnvironment('LEGAL_DELETE_URL');

  /// Yaptırım itirazlarının ve destek taleplerinin gideceği adres.
  static const String supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL');

  static bool has(String value) => value.trim().isNotEmpty;

  /// Hiçbir adres verilmemişse yasal bölüm hiç çizilmiyor.
  static bool get anyConfigured =>
      has(terms) || has(privacy) || has(kvkk) || has(accountDeletion);
}

/// Hukuki bir bağlantıyı dış tarayıcıda açar.
///
/// Uygulama içi web görünümü DEĞİL: metinler bizim barındırdığımız sayfalarda
/// duruyor ve kullanıcının adres çubuğunu görmesi, okuduğu belgenin gerçekten
/// oradan geldiğini doğrulamasının tek yolu.
///
/// Başarısızlık YUTULUYOR ve `false` dönüyor: bağlantı açılamadı diye akış
/// durmamalı. Çağıran isterse kullanıcıya bir bilgi gösterir.
Future<bool> openLegalUrl(String url) async {
  if (!LegalLinks.has(url)) return false;
  final Uri? uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('bağlantı açılamadı ($url): $e');
    return false;
  }
}

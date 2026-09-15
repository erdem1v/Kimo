/// Supabase bağlantı bilgileri. Değerler derleme/çalıştırma sırasında
/// `--dart-define-from-file=supabase.json` ile gelir; kaynağa gömülmez.
///
/// YAPILANDIRMA ZORUNLU: yoksa uygulama AÇILMAZ. `main.dart` eksik ayarları
/// anlatan bir hata ekranı gösterip çıkıyor (`ConfigErrorApp`). Eskiden bir
/// "demo/mock modu" vardı ve bu yorum onu anlatıyordu; mod Task 03'te
/// KALDIRILDI, yorum Task 13'e kadar kaldı.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

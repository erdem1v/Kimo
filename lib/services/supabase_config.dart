/// Supabase bağlantı bilgileri. Değerler derleme/çalıştırma sırasında
/// `--dart-define-from-file=supabase.json` ile gelir; kaynağa gömülmez.
///
/// Yapılandırma yoksa uygulama mock modda çalışır (Supabase'e bağlanmaz).
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

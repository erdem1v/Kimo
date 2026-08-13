import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bildirim altyapısı (izin ayrıca istenir; burada yalnızca hazırlanır).
  await notifications.init();
  // Anahtarlar tanımlıysa Supabase'i başlat; değilse uygulama mock modda açılır.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
  runApp(const AiYksCoachApp());
}

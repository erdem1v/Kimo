import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/supabase_config.dart';
import 'state/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tema ve ses tercihi ilk kareden ÖNCE okunur; aksi hâlde koyu mod seçmiş
  // kullanıcı bir kare beyaz görürdü.
  await appSettings.load();
  // Bildirim altyapısı (izin ayrıca istenir; burada yalnızca hazırlanır).
  await notifications.init();
  await push.init();
  // Anahtarlar tanımlıysa Supabase'i başlat; değilse uygulama mock modda açılır.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
  runApp(const AiYksCoachApp());
}

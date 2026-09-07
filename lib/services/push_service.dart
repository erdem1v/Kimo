import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crash_service.dart';
import 'notification_router.dart';

/// Anlık bildirimler (FCM). Sosyal olaylar için: arkadaşlık isteği, gelen
/// soru, gönderdiğin sorunun çözülmesi.
///
/// Metinleri sunucu üretir (bkz. push_lines tablosu); burada yalnızca cihaz
/// jetonu kaydedilir ve gelen mesaj gösterilir. Günlük hatırlatmalar ise
/// cihazda üretilir (NotificationService).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _started = false;
  String? _token;

  /// Uygulama ön plandayken gelen bildirimi göstermek için kanal.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'social_events',
    'Sosyal bildirimler',
    description: 'Arkadaşlık istekleri ve gelen sorular',
    importance: Importance.high,
  );

  /// Uygulama açılışında bir kez. Firebase'i başlatır ve dinlemeye geçer.
  Future<void> init() async {
    if (_started || kIsWeb) return;
    try {
      await Firebase.initializeApp();

      // Ön planda gelen mesajı gösterebilmek için kanalı oluştur.
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      // Uygulama arka plandayken bildirime dokunuldu.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage m) =>
            NotificationRouter.handle(m.data['kind'] as String?),
      );
      // Uygulama tamamen kapalıyken bildirime dokunulup açıldı.
      final RemoteMessage? initial = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initial != null) {
        NotificationRouter.handle(initial.data['kind'] as String?);
      }

      _started = true;
    } catch (e) {
      debugPrint('Push başlatılamadı: $e');
    }
  }

  /// Oturum açıldıktan sonra çağrılır: jetonu alır ve sunucuya kaydeder.
  /// Bildirim izni yoksa jeton yine alınır ama bildirim görünmez; izin
  /// NotificationService üzerinden istenir.
  Future<void> registerDevice() async {
    if (!_started) {
      // init() başarısızsa bir kez daha dene (ağ geç gelmiş olabilir).
      await init();
      if (!_started) return;
    }
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _saveToken(token);
    } catch (e) {
      debugPrint('Jeton alınamadı: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final String? uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('device_tokens')
          .upsert(<String, dynamic>{
            'user_id': uid,
            'token': token,
            'platform': defaultTargetPlatform.name,
            'updated_at': DateTime.now().toIso8601String(),
          });
      _token = token;
    } catch (e) {
      debugPrint('Jeton kaydedilemedi: $e');
    }
  }

  /// Çıkışta bu cihazın kaydını siler; başkasının bildirimi buraya düşmesin.
  Future<void> unregisterDevice() async {
    final String? token = _token;
    if (token == null) return;
    try {
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('token', token);
    } catch (e, st) {
      // Çıkışı bloklamayalım; ama sunucuda kalan jeton bir sonraki hesabın
      // yanlış bildirim almasına yol açabilir — iz bırak.
      await reportError(e, st, context: 'unregisterDevice');
    }
  }

  /// Uygulama açıkken gelen bildirim: sistem göstermez, biz gösteririz.
  Future<void> _showForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null) return;
    try {
      await _local.show(
        id: message.hashCode,
        title: n.title,
        body: n.body,
        // Dokunulunca doğru ekrana gidebilmesi için türü taşı.
        payload: message.data['kind'] as String?,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Ön plan bildirimi gösterilemedi: $e');
    }
  }
}

final PushService push = PushService.instance;

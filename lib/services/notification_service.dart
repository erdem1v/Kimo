import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/mascot_lines.dart';
import '../models/mascot.dart';
import '../state/app_settings.dart';
import 'notification_router.dart';

/// Yerel (cihaz üstü) bildirimler. Sunucu gerektirmez: uygulama her açıldığında
/// o günün planı yeniden kurulur.
///
/// Sosyal olaylar (arkadaşlık isteği, gelen soru) buradan gönderilemez —
/// onlar için sunucu push'u (FCM) gerekir.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Her senaryonun sabit kimliği: yeniden planlarken eskisinin üstüne yazar.
  static const int _idReviews = 1;
  static const int _idStreak = 2;
  static const int _idStreakTomorrow = 3;
  static const int _idLeague = 4;
  static const int _idComeback = 5;

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'daily_reminders',
    'Günlük hatırlatmalar',
    channelDescription: 'Tekrar, seri ve lig hatırlatmaları',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        // Bildirime dokunulunca ilgili ekrana götür.
        onDidReceiveNotificationResponse: (NotificationResponse r) =>
            NotificationRouter.handle(r.payload),
      );

      // Uygulama kapalıyken bildirime dokunulup açıldıysa onu da yakala.
      final NotificationAppLaunchDetails? launch = await _plugin
          .getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        NotificationRouter.handle(launch!.notificationResponse?.payload);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Bildirim servisi başlatılamadı: $e');
    }
  }

  /// Sistem izni ister. Yalnızca kullanıcı uygulama içinde "evet" dedikten
  /// sonra çağrılmalı (soğuk sistem penceresi kabul oranını düşürür).
  Future<bool> requestPermission() async {
    await init();
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sistem düzeyinde bildirimler açık mı? Kullanıcı ayarlardan kapatmış
  /// olabilir; uygulama içindeki anahtar buna göre düzeltilir.
  Future<bool> areEnabled() async {
    await init();
    if (!_ready) return false;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      // iOS'ta ayrı bir sorgu yok; izin isteme sonucu tek gerçek kaynak.
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Günün planını kurar. Uygulama açılışında ve veriler yüklendikçe çağrılır.
  ///
  /// Çekirdek kurallar korunuyor: sessiz aralığa planlama yapılmaz · geçmiş
  /// saate planlama yapılmaz · bugün zaten çözülmüşse hatırlatma gönderilmez ·
  /// metin maskota göre seçilir.
  ///
  /// Değişen tek şey **kimin karar verdiği**: saatler ve sessiz aralık artık
  /// koda gömülü değil, `AppSettings` üzerinden kullanıcının. Varsayılanlar
  /// eski sabit değerlerle aynı (17:00 / 20:00 ve 22:00–08:00).

  Future<void> planDay({
    required bool enabled,
    required Mascot mascot,
    required int dueCount,
    required int streak,
    required bool activeToday,
  }) async {
    await init();
    if (!_ready) return;
    await cancelAll();
    if (!enabled) return;

    // 1) Bugünkü tekrarlar — yapılacak iş varsa ve bugün henüz çözülmediyse.
    if (dueCount > 0 && !activeToday) {
      await _at(
        id: _idReviews,
        hour: appSettings.reviewHour,
        kind: NotifyKind.reviewsDue,
        mascot: mascot,
        n: dueCount,
      );
    }

    // 2) Seri tehlikede — serisi olan ve bugün çözmemiş kullanıcı.
    if (streak > 0 && !activeToday) {
      await _at(
        id: _idStreak,
        hour: appSettings.streakHour,
        kind: NotifyKind.streakRisk,
        mascot: mascot,
        n: streak,
      );
    }

    // 3) Yarın için emniyet kemeri: kullanıcı uygulamayı hiç açmazsa da
    //    seri hatırlatması çıksın (açtığında bu plan yenilenir).
    if (streak > 0) {
      await _at(
        id: _idStreakTomorrow,
        hour: appSettings.streakHour,
        dayOffset: 1,
        kind: NotifyKind.streakRisk,
        mascot: mascot,
        n: activeToday ? streak + 1 : streak,
      );
    }

    // 4) Uzun süre girilmezse geri çağrı.
    await _at(
      id: _idComeback,
      hour: 18,
      dayOffset: 3,
      kind: NotifyKind.comeback,
      mascot: mascot,
      n: 3,
    );
  }

  /// Lig haftasının son günü için hatırlatma (sıralama bilindiğinde çağrılır).
  Future<void> planLeagueReminder({
    required bool enabled,
    required Mascot mascot,
    required int rank,
    required String leagueLabel,
    required int daysLeft,
  }) async {
    await init();
    if (!_ready || !enabled) return;
    // Yalnızca son gün ve sıralama kritikse.
    if (daysLeft > 1 || rank <= 0) return;
    await _at(
      id: _idLeague,
      hour: 19,
      kind: NotifyKind.leagueLastDay,
      mascot: mascot,
      sira: rank,
      lig: leagueLabel,
    );
  }

  /// Belirtilen saate (bugün + [dayOffset]) planlar. Saat geçmişse atlar.
  Future<void> _at({
    required int id,
    required int hour,
    required NotifyKind kind,
    required Mascot mascot,
    int dayOffset = 0,
    int? n,
    int? sira,
    String? lig,
  }) async {
    // Sessiz aralık kullanıcının; eşik burada TUTULMUYOR, tek kaynak
    // `AppSettings.isQuietHour`. İki yerde tutulsaydı ayarlar ekranı bir şey,
    // planlayıcı başka bir şey uygular hâle gelirdi.
    if (appSettings.isQuietHour(hour)) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + dayOffset,
      hour,
    );
    if (!when.isAfter(now)) return; // geçmiş saate planlama yok

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: MascotLines.title(kind),
        body: MascotLines.pick(kind, mascot, n: n, sira: sira, lig: lig),
        scheduledDate: when,
        notificationDetails: _details,
        payload: MascotLines.payload(kind),
        // Kesin alarm izni istemeyelim; dakikalık sapma sorun değil.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Bildirim planlanamadı ($kind): $e');
    }
  }
}

final NotificationService notifications = NotificationService.instance;

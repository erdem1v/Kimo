import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/mascot_lines.dart';
import '../models/mascot.dart';
import '../state/app_settings.dart';
import 'crash_service.dart';
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

  /// Son planDay girdileri — ayar değişikliğinde yeniden planlamak için.
  _PlanInputs? _lastPlan;

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
      // BİLİNÇLİ sabit: uygulama yalnızca YKS öğrencilerine, sunucu takvimi de
      // Europe/Istanbul'a göre işliyor. Cihaz dilimini kullanmak, yurt
      // dışındaki öğrencide hatırlatmayı sunucunun gününden ayırırdı. Bedeli
      // belgeli: o öğrencide "20:00" hatırlatması yerel 20:00'de değil,
      // Istanbul 20:00'sinde çalar (Task 03 raporu, çözülmeyenler listesi).
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
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'notify.requestPermission'));
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
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        // Eskiden burada sabit `true` dönüyordu: kullanıcı iOS ayarlarından
        // izni kapatınca uygulama içi anahtar sonsuza dek "açık" kalıyordu.
        final NotificationsEnabledOptions? st = await ios.checkPermissions();
        return st?.isEnabled ?? false;
      }
      return false;
    } catch (e, st) {
      // DİKKAT: false dönmek, home_shell'deki eşitleme yüzünden kullanıcının
      // tercihini kapatabilir; geçici bir eklenti hatası bunu tetiklememeli.
      // Bu yüzden iz bırakıyoruz (bkz. Task 03 raporu).
      unawaited(reportError(e, st, context: 'notify.areEnabled'));
      return false;
    }
  }

  Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (e, st) {
      // Eskiden deponun tek TAMAMEN boş catch'iydi. İptal edilemeyen bildirim
      // kullanıcıyı "kapattım ama gelmeye devam ediyor" durumunda bırakır.
      unawaited(reportError(e, st, context: 'notify.cancelAll'));
    }
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
    // Ayarlardan saat değiştiğinde ya da anahtar yeniden açıldığında ekran
    // yüklemesini beklemeden yeniden planlayabilmek için girdiler saklanır.
    _lastPlan = _PlanInputs(
      mascot: mascot,
      dueCount: dueCount,
      streak: streak,
      activeToday: activeToday,
    );
    // YALNIZCA kendi kimliklerini iptal et. Eskiden cancelAll() çağrılıyordu
    // ve iki yarış üretiyordu: (a) LeagueScreen'in az önce kurduğu lig
    // hatırlatması (_idLeague) siliniyordu — IndexedStack'te iki ekran aynı
    // refreshBus ping'iyle yüklenirken hangisi geç bitirdiyse o kazanıyordu;
    // (b) o an görünen bir FCM bildirimi de kapatılıyordu.
    for (final int id in <int>[
      _idReviews,
      _idStreak,
      _idStreakTomorrow,
      _idComeback,
    ]) {
      try {
        await _plugin.cancel(id: id);
      } catch (e, st) {
        unawaited(reportError(e, st, context: 'notify.cancel'));
      }
    }
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

  /// Son bilinen girdilerle bugünü YENİDEN planlar.
  ///
  /// Ayarlar ekranı çağırır: anahtar tekrar açıldığında ya da saat / sessiz
  /// aralık değiştiğinde. Eskiden değişiklik ancak bir sonraki ekran
  /// yüklemesinde işlerdi — kullanıcı saati değiştirir, o günkü hatırlatma
  /// eski saatte kalırdı.
  Future<void> replanFromCache({required bool enabled}) async {
    final _PlanInputs? p = _lastPlan;
    if (p == null) return;
    await planDay(
      enabled: enabled,
      mascot: p.mascot,
      dueCount: p.dueCount,
      streak: p.streak,
      activeToday: p.activeToday,
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
    // `AppSettings.isQuietHour`. Aralığa denk gelen hatırlatma DÜŞMEZ, bir
    // sonraki uygun saate KAYAR — ayarlardaki metin zaten böyle söylüyordu
    // ama kod düşürüyordu: 22:00 tekrar saati + 22-08 sessizliği seçen
    // kullanıcı hiçbir hatırlatma almıyordu ve bunu asla göremiyordu.
    final ({int hour, int addDays})? slot =
        resolveScheduledHour(hour, appSettings.isQuietHour);
    if (slot == null) return; // 24 saatin tamamı sessiz: kullanıcı kararı

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + dayOffset + slot.addDays,
      slot.hour,
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

/// Sessiz aralığa denk gelen saati bir sonraki uygun saate kaydırır.
///
/// Saf fonksiyon (test edilebilir): [isQuiet] her saati kontrol eder; 24
/// saatin tamamı sessizse `null` döner (hiç planlama yapılmaz — kullanıcının
/// açık kararı). Gece yarısını aşan kaydırma `addDays: 1` ile bildirilir.
({int hour, int addDays})? resolveScheduledHour(
  int hour,
  bool Function(int) isQuiet,
) {
  int h = ((hour % 24) + 24) % 24;
  int addDays = 0;
  for (int i = 0; i < 24; i++) {
    if (!isQuiet(h)) return (hour: h, addDays: addDays);
    h = (h + 1) % 24;
    if (h == 0) addDays = 1;
  }
  return null;
}

/// [NotificationService.planDay] girdilerinin anlık görüntüsü.
class _PlanInputs {
  const _PlanInputs({
    required this.mascot,
    required this.dueCount,
    required this.streak,
    required this.activeToday,
  });

  final Mascot mascot;
  final int dueCount;
  final int streak;
  final bool activeToday;
}

final NotificationService notifications = NotificationService.instance;

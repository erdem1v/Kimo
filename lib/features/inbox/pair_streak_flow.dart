/// Ortak serinin 2. ve 3. anları (Tur 7 · n6).
///
/// 2. AN — ÇAĞRI: arkadaşın sorusu çözüldükten sonra "sen de ona bir soru
/// gönder, ortak seriniz başlasın".
/// 3. AN — KUTLAMA: seri gerçekten başladığında.
///
/// ÇAĞRI YALNIZCA BİR KEZ ÇIKIYOR ve "Şimdi değil" dendiğinde o arkadaş için
/// BİR HAFTA susuyor. Susma CİHAZDA tutuluyor (`credit_wall_log` deseni):
/// sunucuya yazmak yeni bir tablo + yeni bir lockdown göçü demekti ve
/// kaybolmasının en kötü sonucu çağrının bir kez fazla çıkması.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/friend_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import 'send_flow.dart';


/// "Şimdi değil" sessizliğinin süresi.
const Duration _snooze = Duration(days: 7);

String _key(String friendId) => 'pairInvite.$friendId';

/// Bu arkadaş için çağrı gösterilebilir mi.
Future<bool> canOfferPairStreak(String friendId) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? until = prefs.getInt(_key(friendId));
    if (until == null) return true;
    return DateTime.now().millisecondsSinceEpoch > until;
  } catch (_) {
    // Okunamadıysa çağrıyı göstermek, göstermemekten iyi: en kötü sonuç bir
    // kez fazla çıkması.
    return true;
  }
}

Future<void> _snoozeFor(String friendId) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(friendId),
      DateTime.now().add(_snooze).millisecondsSinceEpoch,
    );
  } catch (_) {
    // Sessiz: sessizlik kaybolursa çağrı bir hafta içinde bir kez daha çıkar.
  }
}

/// 2. an — çağrı sayfası.
///
/// "Soru gönder" seçilirse gönderme akışının ARKADAŞ-ÖNCE girişi açılıyor
/// (n5 ile aynı sayfa; ikinci bir gönderme akışı yazılmıyor).
Future<void> offerPairStreak(
  BuildContext context, {
  required String friendId,
  required String friendName,
}) async {
  if (!await canOfferPairStreak(friendId)) return;
  if (!context.mounted) return;
  final L10n l = L10n.of(context);
  final KimoTypography t = context.t;

  final bool? go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.fromLTRB(Gap.screen, Gap.screen, Gap.screen,
          Gap.screen + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.pairStreakInviteTitle(friendName), style: t.section),
          const SizedBox(height: Gap.sm),
          Text(l.pairStreakInviteBody, style: t.body),
          const SizedBox(height: Gap.lg),
          KimoButton(
            label: l.pairStreakInviteAction,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.pairStreakInviteLater,
            kind: KimoButtonKind.tertiary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );

  // Çağrı BİR KEZ çıktı: seçim ne olursa olsun sessizliğe alınıyor. "Şimdi
  // değil"de bir hafta, "gönder"de de aynı — gönderim başarısız olsa bile
  // kullanıcıya aynı çağrıyı tekrar göstermek ısrar olurdu.
  await _snoozeFor(friendId);
  if (!context.mounted) return;

  if (go == true) {
    await showSendEntrySheet(context,
        friendId: friendId, friendName: friendName);
  }
}

/// 3. an — başlama kutlaması.
///
/// KURAL BURADA YAZILI: "Her ikiniz de günde bir soru çözdükçe sayı büyür."
/// Kullanıcı mekaniği tam bu anda öğreniyor; gönderimin seriyi SÜRDÜRMEDİĞİNİ
/// bilmemesi, her gün göndermesi gerektiğini sanmasına yol açardı.
Future<void> celebratePairStreak(
  BuildContext context, {
  required String friendName,
}) async {
  final L10n l = L10n.of(context);
  final KimoTypography t = context.t;
  sound.correct();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.fromLTRB(Gap.screen, Gap.screen, Gap.screen,
          Gap.screen + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.pairStreakStartedTitle, style: t.section),
          const SizedBox(height: Gap.sm),
          Text(l.pairStreakStartedBody(friendName), style: t.body),
          const SizedBox(height: Gap.lg),
          KimoButton(
            label: l.pairStreakStartedAction,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}

/// Çözümden sonra çalıştırılan tek giriş noktası.
///
/// SIRA ÖNEMLİ: önce seri BAŞLATILMAYA çalışılıyor, başladıysa KUTLAMA
/// çıkıyor. Çağrı ise YALNIZCA sunucu "iki yönde çözülmüş gönderim eksik"
/// dediğinde çıkıyor — tek durum ki kullanıcının atacağı adım gerçekten işe
/// yarıyor.
///
/// ESKİDEN "başlamadıysa çağrı" idi ve `start` yedi sonucu tek `false`a
/// katlıyordu (0098 öncesi). Sonuç: serisi ZATEN BAŞLAMIŞ ikiliye ve üst
/// sınıra çarpmış kullanıcıya da "ortak seriniz başlasın" deniyordu. Bu
/// dosyanın kendi yorumu tam olarak bunu yasaklıyordu ama ayrım olmadan
/// kural uygulanamıyordu.
///
/// SESSİZ KALINAN DURUMLAR: `exists` (zaten var — söylenecek bir şey yok),
/// `cap`, `suspended`, `disabled`, `not_eligible`, `error`. Hiçbirinde
/// kullanıcının yapabileceği bir şey yok; çözümün hemen ardından açılan bir
/// yaprakla onu bilgilendirmek, kutlaması gereken anı bir redde çevirirdi.
Future<void> afterSolvingFriendQuestion(
  BuildContext context, {
  required String friendId,
  required String friendName,
  required bool enabled,
}) async {
  if (!enabled) return;
  final String reason = await pairStreakRepository.start(friendId);
  if (!context.mounted) return;
  if (reason == 'started') {
    await celebratePairStreak(context, friendName: friendName);
    return;
  }
  if (reason == 'needs_solved') {
    await offerPairStreak(context, friendId: friendId, friendName: friendName);
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'mascot.dart';

/// Toplam XP'ye göre lig. Kohort/haftalık sıfırlama yok; eşik tabanlı.
enum League {
  bronz,
  gumus,
  altin,
  elmas,
  efsane;

  String get label => switch (this) {
        League.bronz => 'Bronz Ligi',
        League.gumus => 'Gümüş Ligi',
        League.altin => 'Altın Ligi',
        League.elmas => 'Elmas Ligi',
        League.efsane => 'Efsane Ligi',
      };

  String get emoji => switch (this) {
        League.bronz => '🥉',
        League.gumus => '🥈',
        League.altin => '🥇',
        League.elmas => '💎',
        League.efsane => '👑',
      };

  Color get color => switch (this) {
        League.bronz => const Color(0xFFB07242),
        League.gumus => const Color(0xFF9AA5B1),
        League.altin => AppColors.gold,
        League.elmas => AppColors.cyan,
        League.efsane => AppColors.purple,
      };

  /// Lige giriş eşiği (toplam XP).
  int get minXp => switch (this) {
        League.bronz => 0,
        League.gumus => 500,
        League.altin => 1500,
        League.elmas => 3500,
        League.efsane => 7500,
      };

  /// Bir sonraki lig (en üstteyse null).
  League? get next => switch (this) {
        League.bronz => League.gumus,
        League.gumus => League.altin,
        League.altin => League.elmas,
        League.elmas => League.efsane,
        League.efsane => null,
      };

  /// Veritabanındaki değer (profiles.league).
  String get dbValue => switch (this) {
        League.bronz => 'bronz',
        League.gumus => 'gumus',
        League.altin => 'altin',
        League.elmas => 'elmas',
        League.efsane => 'efsane',
      };

  static League fromDb(String? value) => switch (value) {
        'gumus' => League.gumus,
        'altin' => League.altin,
        'elmas' => League.elmas,
        'efsane' => League.efsane,
        _ => League.bronz,
      };

  static League fromXp(int xp) {
    League result = League.bronz;
    for (final League l in League.values) {
      if (xp >= l.minXp) result = l;
    }
    return result;
  }
}

/// Haftanın başlangıcı (pazartesi, güne normalize).
DateTime weekStart(DateTime now) {
  final DateTime d = DateTime(now.year, now.month, now.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Arama/liderlik listelerinde gösterilen herkese açık profil.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.nickname,
    required this.xp,
    required this.streak,
    this.weeklyXp = 0,
    this.mascot,
  });

  final String id;
  final String nickname;
  final int xp;
  final int streak;

  /// Bu haftaki XP — lig içi sıralamayı belirler.
  final int weeklyXp;
  final Mascot? mascot;

  League get league => League.fromXp(xp);

  factory PublicProfile.fromRow(Map<String, dynamic> row) => PublicProfile(
        id: row['id'] as String,
        nickname: (row['nickname'] as String?) ?? 'Öğrenci',
        xp: (row['xp'] as int?) ?? 0,
        streak: (row['streak'] as int?) ?? 0,
        weeklyXp: (row['weekly_xp'] as int?) ?? 0,
        mascot: Mascot.fromDb(row['mascot'] as String?),
      );
}

/// Bana göre bir kullanıcının arkadaşlık durumu.
enum FriendState {
  none, // ilişki yok
  outgoing, // ben istek gönderdim, bekliyor
  incoming, // bana istek geldi
  friends, // karşılıklı kabul
}

/// Arkadaşlık kaydı (istek ya da kabul edilmiş).
class Friendship {
  const Friendship({
    required this.requesterId,
    required this.addresseeId,
    required this.accepted,
  });

  final String requesterId;
  final String addresseeId;
  final bool accepted;

  factory Friendship.fromRow(Map<String, dynamic> row) => Friendship(
        requesterId: row['requester_id'] as String,
        addresseeId: row['addressee_id'] as String,
        accepted: row['status'] == 'accepted',
      );

  /// [me] dışındaki taraf.
  String otherId(String me) => requesterId == me ? addresseeId : requesterId;

  FriendState stateFor(String me) {
    if (accepted) return FriendState.friends;
    return requesterId == me ? FriendState.outgoing : FriendState.incoming;
  }
}

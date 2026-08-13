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

  /// Sıralamada kaçıncıya kadar üst lige çıkılır.
  static const int promotionCount = 5;

  /// Bir grubun en fazla kaç kişi olabileceği.
  static const int cohortSize = 15;

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

}

/// Lig grubundaki bir oyuncu (haftalık XP'ye göre sıralanır).
class LeagueEntry {
  const LeagueEntry({
    required this.userId,
    required this.nickname,
    required this.xp,
    required this.streak,
    this.mascot,
  });

  final String userId;
  final String nickname;
  final int xp;
  final int streak;
  final Mascot? mascot;

  factory LeagueEntry.fromRow(Map<String, dynamic> row) => LeagueEntry(
        userId: row['user_id'] as String,
        nickname: (row['nickname'] as String?) ?? 'Öğrenci',
        xp: (row['xp'] as int?) ?? 0,
        streak: (row['streak'] as int?) ?? 0,
        mascot: Mascot.fromDb(row['mascot'] as String?),
      );
}

/// Kullanıcının bu haftaki lig grubu.
class LeagueBoard {
  const LeagueBoard({
    required this.tier,
    required this.entries,
    required this.weekStart,
  });

  final League tier;
  final List<LeagueEntry> entries;
  final DateTime weekStart;

  /// Haftanın bitimine kalan gün (pazartesi sıfırlanır).
  int get daysLeft {
    final DateTime end = weekStart.add(const Duration(days: 7));
    final DateTime now = DateTime.now();
    final int d = end.difference(DateTime(now.year, now.month, now.day)).inDays;
    return d < 0 ? 0 : d;
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
    this.league = League.bronz,
  });

  final String id;
  final String nickname;
  final int xp;
  final int streak;

  /// Bu haftaki XP — lig içi sıralamayı belirler.
  final int weeklyXp;
  final Mascot? mascot;

  /// Ligi sunucu belirler (haftalık sıralamayla değişir).
  final League league;

  factory PublicProfile.fromRow(Map<String, dynamic> row) => PublicProfile(
        id: row['id'] as String,
        nickname: (row['nickname'] as String?) ?? 'Öğrenci',
        xp: (row['xp'] as int?) ?? 0,
        streak: (row['streak'] as int?) ?? 0,
        weeklyXp: (row['weekly_xp'] as int?) ?? 0,
        mascot: Mascot.fromDb(row['mascot'] as String?),
        league: League.fromDb(row['league'] as String?),
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

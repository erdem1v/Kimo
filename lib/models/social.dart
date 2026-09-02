import 'package:flutter/material.dart';

import 'mascot.dart';

/// Haftalık lig kademesi.
///
/// Altı kademe: bronz < gümüş < altın < platin < zümrüt < elmas.
/// Kademe atlamak XP EŞİĞİYLE OLMAZ: her hafta 30 kişilik bir kohortta
/// yarışılır, ilk 5 yükselir, son 5 düşer. Kararı sunucu verir
/// (`settle_past_leagues`); istemci yalnızca gösterir.
///
/// GEÇİŞ NOTU: eski yapı beş kademeydi (… altın · elmas · efsane) ve `elmas`
/// 4. sıradaydı. Yeni yapıda `elmas` TEPE kademe. Veritabanı göçü sırayı
/// koruyarak eşledi: eski `elmas` → `platin`, eski `efsane` → `zumrut`.
/// Yani `elmas` adı aynı kaldı ama ANLAMI değişti — eski bir istemci yeni
/// sunucuyla konuşursa bu tek fark üzerinden yanlış rozet gösterir.
enum League {
  bronz,
  gumus,
  altin,
  platin,
  zumrut,
  elmas;

  String get label => switch (this) {
    League.bronz => 'Bronz Ligi',
    League.gumus => 'Gümüş Ligi',
    League.altin => 'Altın Ligi',
    League.platin => 'Platin Ligi',
    League.zumrut => 'Zümrüt Ligi',
    League.elmas => 'Elmas Ligi',
  };

  /// Kısa ad — rozet ve satır içi kullanım için ("Altın", "Zümrüt").
  String get shortLabel => switch (this) {
    League.bronz => 'Bronz',
    League.gumus => 'Gümüş',
    League.altin => 'Altın',
    League.platin => 'Platin',
    League.zumrut => 'Zümrüt',
    League.elmas => 'Elmas',
  };

  Color get color => switch (this) {
    League.bronz => const Color(0xFFB07242),
    League.gumus => const Color(0xFF9AA5B1),
    League.altin => const Color(0xFFF2A93B),
    League.platin => const Color(0xFF7FA3B8),
    League.zumrut => const Color(0xFF1B9B6B),
    League.elmas => const Color(0xFF5AC8E8),
  };

  /// Sıralamada kaçıncıya kadar üst lige çıkılır.
  static const int promotionCount = 5;

  /// Sondan kaç kişi bir alt lige düşer.
  static const int demotionCount = 5;

  /// Bir kohortun en fazla kaç kişi olabileceği.
  ///
  /// Sunucudaki `league_cohort_size()` ile AYNI olmak zorunda; ikisi ayrışırsa
  /// arayüz "30 kişilik kohort" derken gerçekte başka bir sayı olur.
  static const int cohortSize = 30;

  /// Bir alt kademe (en alttaysa null).
  League? get previous => switch (this) {
    League.bronz => null,
    League.gumus => League.bronz,
    League.altin => League.gumus,
    League.platin => League.altin,
    League.zumrut => League.platin,
    League.elmas => League.zumrut,
  };

  /// Bir üst kademe (en üstteyse null).
  League? get next => switch (this) {
    League.bronz => League.gumus,
    League.gumus => League.altin,
    League.altin => League.platin,
    League.platin => League.zumrut,
    League.zumrut => League.elmas,
    League.elmas => null,
  };

  /// Veritabanındaki değer (profiles.league).
  String get dbValue => switch (this) {
    League.bronz => 'bronz',
    League.gumus => 'gumus',
    League.altin => 'altin',
    League.platin => 'platin',
    League.zumrut => 'zumrut',
    League.elmas => 'elmas',
  };

  /// Bilinmeyen değer bronza düşer: sunucu yeni bir kademe eklerse istemci
  /// çökmek yerine en alt kademeyi gösterir.
  static League fromDb(String? value) => switch (value) {
    'gumus' => League.gumus,
    'altin' => League.altin,
    'platin' => League.platin,
    'zumrut' => League.zumrut,
    'elmas' => League.elmas,
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
    this.avatarPath,
  });

  final String userId;
  final String nickname;
  final int xp;
  final int streak;
  final Mascot? mascot;

  /// Storage'daki profil fotoğrafının yolu (yoksa maskot simgesi gösterilir).
  final String? avatarPath;

  factory LeagueEntry.fromRow(Map<String, dynamic> row) => LeagueEntry(
    userId: row['user_id'] as String,
    nickname: (row['nickname'] as String?) ?? 'Öğrenci',
    xp: (row['xp'] as int?) ?? 0,
    streak: (row['streak'] as int?) ?? 0,
    mascot: Mascot.fromDb(row['mascot'] as String?),
    avatarPath: row['avatar_path'] as String?,
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
    this.avatarPath,
    this.friendCount = 0,
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

  /// Storage'daki profil fotoğrafının yolu (yoksa maskot simgesi gösterilir).
  final String? avatarPath;

  /// Kabul edilmiş arkadaşlık sayısı.
  final int friendCount;

  factory PublicProfile.fromRow(Map<String, dynamic> row) => PublicProfile(
    id: row['id'] as String,
    nickname: (row['nickname'] as String?) ?? 'Öğrenci',
    xp: (row['xp'] as int?) ?? 0,
    streak: (row['streak'] as int?) ?? 0,
    weeklyXp: (row['weekly_xp'] as int?) ?? 0,
    mascot: Mascot.fromDb(row['mascot'] as String?),
    league: League.fromDb(row['league'] as String?),
    avatarPath: row['avatar_path'] as String?,
    friendCount: (row['friend_count'] as int?) ?? 0,
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

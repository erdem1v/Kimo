import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mascot.dart';
import '../models/social.dart';

/// Sosyal katman: herkese açık profiller (arama/liderlik) ve karşılıklı
/// onaylı arkadaşlık istekleri.
///
/// Okuma `profiles_public` görünümünden yapılır (yalnızca güvenli kolonlar:
/// id, nickname, mascot, xp, streak). Yazma kendi `profiles` satırına.
class SocialRepository {
  SocialRepository._();
  static final SocialRepository instance = SocialRepository._();

  /// Arama/liderlik için okunan görünüm.
  static const String _publicView = 'profiles_public';

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Oturumdaki kullanıcının kimliği (listelerde "sen" ayrımı için).
  String? get currentUserId => _uid;

  /// Kendi profil satırını oluşturur/günceller. Oturum açıldığında çağrılır.
  Future<void> ensureProfile({
    required String nickname,
    Mascot? mascot,
    int? xp,
    int? streak,
  }) async {
    final String? uid = _uid;
    if (uid == null) return;
    await _client.from('profiles').upsert(<String, dynamic>{
      'id': uid,
      'nickname': nickname,
      if (mascot != null) 'mascot': mascot.dbValue,
      'xp': ?xp,
      'streak': ?streak,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// XP/seri/haftalık XP değerlerini kaydeder (lig tablosu bunları okur).
  Future<void> syncStats({
    required int xp,
    required int streak,
    int? weeklyXp,
    DateTime? weekStartDate,
    DateTime? lastActiveDate,
  }) async {
    final String? uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('profiles').update(<String, dynamic>{
        'xp': xp,
        'streak': streak,
        'weekly_xp': ?weeklyXp,
        if (weekStartDate != null) 'week_start': _dateStr(weekStartDate),
        if (lastActiveDate != null)
          'last_activity_date': _dateStr(lastActiveDate),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {
      // Ağ hatası akışı bloklamasın.
    }
  }

  /// Kendi oyunlaştırma verilerim (seri için son aktif gün dahil). Yalnızca
  /// kendi satırım okunur; profiles'ın RLS'i buna izin verir.
  Future<Map<String, dynamic>?> myStats() async {
    final String? uid = _uid;
    if (uid == null) return null;
    try {
      return await _client
          .from('profiles')
          .select('xp, streak, weekly_xp, week_start, last_activity_date')
          .eq('id', uid)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Kendi ligimdeki oyuncular, bu haftaki XP'ye göre sıralı.
  Future<List<PublicProfile>> leagueBoard(League league,
      {int limit = 30}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from(_publicView)
        .select()
        .eq('league', league.dbValue)
        .order('weekly_xp', ascending: false)
        .order('xp', ascending: false)
        .limit(limit);
    return rows.map(PublicProfile.fromRow).toList();
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Kendi profilim (yoksa null).
  Future<PublicProfile?> myProfile() async {
    final String? uid = _uid;
    if (uid == null) return null;
    final Map<String, dynamic>? row = await _client
        .from(_publicView)
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : PublicProfile.fromRow(row);
  }

  /// Takma adla arama (büyük/küçük harf duyarsız, kendim hariç).
  Future<List<PublicProfile>> search(String query) async {
    final String q = query.trim();
    final String? uid = _uid;
    if (q.length < 2 || uid == null) return <PublicProfile>[];
    final List<Map<String, dynamic>> rows = await _client
        .from(_publicView)
        .select()
        .ilike('nickname', '%$q%')
        .neq('id', uid)
        .order('xp', ascending: false)
        .limit(20);
    return rows.map(PublicProfile.fromRow).toList();
  }

  /// Beni ilgilendiren tüm arkadaşlık kayıtları (istek + kabul).
  Future<List<Friendship>> relations() async {
    final String? uid = _uid;
    if (uid == null) return <Friendship>[];
    final List<Map<String, dynamic>> rows = await _client
        .from('friendships')
        .select()
        .or('requester_id.eq.$uid,addressee_id.eq.$uid');
    return rows.map(Friendship.fromRow).toList();
  }

  /// Verilen kimliklerin profillerini getirir.
  Future<List<PublicProfile>> profilesByIds(List<String> ids) async {
    if (ids.isEmpty) return <PublicProfile>[];
    final List<Map<String, dynamic>> rows = await _client
        .from(_publicView)
        .select()
        .inFilter('id', ids)
        .order('xp', ascending: false);
    return rows.map(PublicProfile.fromRow).toList();
  }

  Future<void> sendRequest(String userId) async {
    final String? uid = _uid;
    if (uid == null || uid == userId) return;
    await _client.from('friendships').insert(<String, dynamic>{
      'requester_id': uid,
      'addressee_id': userId,
      'status': 'pending',
    });
  }

  /// Bana gelen isteği kabul eder.
  Future<void> acceptRequest(String requesterId) async {
    final String? uid = _uid;
    if (uid == null) return;
    await _client
        .from('friendships')
        .update(<String, dynamic>{'status': 'accepted'})
        .eq('requester_id', requesterId)
        .eq('addressee_id', uid);
  }

  /// İsteği reddeder / iptal eder / arkadaşlığı siler (iki yön de denenir).
  Future<void> removeRelation(String otherId) async {
    final String? uid = _uid;
    if (uid == null) return;
    await _client
        .from('friendships')
        .delete()
        .eq('requester_id', uid)
        .eq('addressee_id', otherId);
    await _client
        .from('friendships')
        .delete()
        .eq('requester_id', otherId)
        .eq('addressee_id', uid);
  }
}

final SocialRepository socialRepository = SocialRepository.instance;

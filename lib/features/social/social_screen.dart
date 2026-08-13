import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/social_repository.dart';
import '../../models/mascot.dart';
import '../../models/social.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';

/// Sosyal sekme: ligin, arkadaş araması, gelen istekler ve arkadaş sıralaması.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  late final TabController _tabs;

  List<Friendship> _relations = <Friendship>[];
  Map<String, PublicProfile> _people = <String, PublicProfile>{};
  List<PublicProfile> _results = <PublicProfile>[];
  LeagueBoard? _board; // bu haftaki 15 kişilik lig grubum
  bool _loading = true;
  bool _searching = false;
  String? _error;
  final Set<String> _busy = <String>{}; // işlem sürerken kilitlenen kullanıcılar

  bool get _remote => SupabaseConfig.isConfigured;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (_remote) {
      _load();
      refreshBus.addListener(_onRefresh);
    }
    _query.addListener(_onQueryChanged);
  }

  /// Sekmeye dönüldüğünde tazele (gelen istekler için uygulamayı kapatmaya
  /// gerek kalmasın).
  void _onRefresh() {
    if (mounted && !_loading) _load();
  }

  @override
  void dispose() {
    refreshBus.removeListener(_onRefresh);
    _debounce?.cancel();
    _query.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Friendship> rels = await socialRepository.relations();
      final String me = _meId ?? '';
      final List<String> ids =
          rels.map((Friendship f) => f.otherId(me)).toSet().toList();
      final List<PublicProfile> people =
          await socialRepository.profilesByIds(ids);
      final LeagueBoard? board = await socialRepository.myLeagueBoard();
      if (!mounted) return;
      setState(() {
        _relations = rels;
        _people = <String, PublicProfile>{
          for (final PublicProfile p in people) p.id: p,
        };
        _board = board;
        if (board != null) gameProgress.league = board.tier;
        _loading = false;
      });
      // Haftanın son günü ve sıralama kritikse hatırlatma planla.
      if (board != null) {
        final int rank =
            board.entries.indexWhere((LeagueEntry e) => e.userId == _meId) + 1;
        unawaited(notifications.planLeagueReminder(
          enabled: userProfile.notifyEnabled,
          mascot: userProfile.mascot ?? Mascot.evHanimi,
          rank: rank,
          leagueLabel: board.tier.label,
          daysLeft: board.daysLeft,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Sosyal veriler yüklenemedi.';
        _loading = false;
      });
    }
  }

  String? get _meId => socialRepository.currentUserId;

  void _onQueryChanged() {
    _debounce?.cancel();
    final String q = _query.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = <PublicProfile>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final List<PublicProfile> res = await socialRepository.search(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  FriendState _stateOf(String userId) {
    final String me = _meId ?? '';
    for (final Friendship f in _relations) {
      if (f.otherId(me) == userId) return f.stateFor(me);
    }
    return FriendState.none;
  }

  Future<void> _act(String userId, Future<void> Function() action) async {
    if (_busy.contains(userId)) return;
    setState(() => _busy.add(userId));
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem tamamlanamadı. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  // --- Listeler ---

  List<PublicProfile> get _friends {
    final String me = _meId ?? '';
    return _relations
        .where((Friendship f) => f.accepted)
        .map((Friendship f) => _people[f.otherId(me)])
        .whereType<PublicProfile>()
        .toList();
  }

  List<PublicProfile> get _incoming {
    final String me = _meId ?? '';
    return _relations
        .where((Friendship f) =>
            !f.accepted && f.stateFor(me) == FriendState.incoming)
        .map((Friendship f) => _people[f.otherId(me)])
        .whereType<PublicProfile>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sosyal'),
        actions: <Widget>[
          if (_remote)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Yenile',
              onPressed: _loading ? null : _load,
            ),
        ],
        bottom: !_remote
            ? null
            : TabBar(
                controller: _tabs,
                labelColor: AppColors.ink,
                unselectedLabelColor: AppColors.inkLight,
                indicatorColor: AppColors.green,
                indicatorWeight: 3,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                tabs: <Widget>[
                  const Tab(text: 'Lig'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('Arkadaşlar'),
                        if (_incoming.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${_incoming.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
      body: !_remote
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Sosyal özellikler için giriş yapman gerekiyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkLight),
                ),
              ),
            )
          : ListenableBuilder(
              listenable: gameProgress,
              builder: (BuildContext context, _) => TabBarView(
                controller: _tabs,
                children: <Widget>[_leagueTab(), _friendsTab()],
              ),
            ),
    );
  }

  // --- Lig sekmesi ---

  Widget _leagueTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _leagueCard(),
        if (_error != null) _errorBlock(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          const SizedBox(height: 20),
          _sectionTitle('Grubun'),
          const SizedBox(height: 4),
          Text(
            '${_board?.entries.length ?? 0} kişilik gruptasın. Hafta sonunda '
            'ilk ${League.promotionCount} üst lige çıkar, '
            'son ${League.demotionCount} alt lige düşer.',
            style: const TextStyle(color: AppColors.inkLight, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          _leagueBoard(),
        ],
      ],
    );
  }

  Widget _leagueBoard() {
    final LeagueBoard? board = _board;
    if (board == null || board.entries.isEmpty) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: <Widget>[
              Text('⚔️', style: TextStyle(fontSize: 30)),
              SizedBox(height: 8),
              Text(
                'Henüz bir gruba katılmadın.\nBu hafta bir soru çöz, '
                'rakiplerin belirlensin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkLight, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    // Kendi satırımı henüz sunucuya yazılmamış XP ile tazele.
    final String me = _meId ?? '';
    final List<LeagueEntry> rows = board.entries
        .map((LeagueEntry e) => e.userId == me
            ? LeagueEntry(
                userId: e.userId,
                nickname: e.nickname,
                xp: gameProgress.weeklyXp,
                streak: gameProgress.streak,
                mascot: e.mascot,
              )
            : e)
        .toList()
      ..sort((LeagueEntry a, LeagueEntry b) => b.xp.compareTo(a.xp));

    return Column(
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          _boardTile(i + 1, rows[i], rows[i].userId == me, rows.length),
          // Yükselme sınırı
          if (i + 1 == League.promotionCount &&
              rows.length > League.promotionCount)
            _zoneDivider(promotion: true),
          // Düşme sınırı (grup 5'ten büyükse ve iki sınır çakışmıyorsa)
          if (rows.length > League.promotionCount + League.demotionCount &&
              i + 1 == rows.length - League.demotionCount)
            _zoneDivider(promotion: false),
        ],
      ],
    );
  }

  /// Yükselme (üstteki 5) ve düşme (alttaki 5) sınır çizgileri.
  Widget _zoneDivider({required bool promotion}) {
    final Color color = promotion ? AppColors.green : AppColors.red;
    final Color dark = promotion ? AppColors.greenDark : AppColors.redDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: color, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                Icon(
                    promotion
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 14,
                    color: dark),
                const SizedBox(width: 4),
                Text(promotion ? 'yükselme bölgesi' : 'düşme bölgesi',
                    style: TextStyle(
                        color: dark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5)),
              ],
            ),
          ),
          Expanded(child: Divider(color: color, thickness: 1.5)),
        ],
      ),
    );
  }

  Widget _boardTile(int rank, LeagueEntry p, bool isMe, int total) {
    final bool promo = rank <= League.promotionCount;
    // Düşme bölgesi yalnızca grup yeterince kalabalıksa gösterilir.
    final bool demo = total > League.promotionCount + League.demotionCount &&
        rank > total - League.demotionCount;
    final Color medal = switch (rank) {
      1 => AppColors.gold,
      2 => const Color(0xFF9AA5B1),
      3 => const Color(0xFFB07242),
      _ => promo
          ? AppColors.greenDark
          : (demo ? AppColors.redDark : AppColors.inkLight),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.greenBg.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? AppColors.green : AppColors.line,
          width: isMe ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: medal)),
          ),
          const SizedBox(width: 6),
          _avatarOf(p.mascot),
          const SizedBox(width: 12),
          Expanded(
            child: _nameOf(
                nickname: p.nickname, streak: p.streak, isMe: isMe),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('${p.xp} XP',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.ink)),
              const Text('bu hafta',
                  style: TextStyle(color: AppColors.inkLight, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Arkadaşlar sekmesi ---

  Widget _friendsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _searchField(),
        if (_query.text.trim().length >= 2) ...<Widget>[
          const SizedBox(height: 12),
          _searchResults(),
        ],
        if (_error != null) _errorBlock(),
        if (_loading) ...<Widget>[
          const SizedBox(height: 40),
          const Center(child: CircularProgressIndicator()),
        ] else ...<Widget>[
          if (_incoming.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            _sectionTitle('Gelen istekler', badge: _incoming.length),
            const SizedBox(height: 10),
            for (final PublicProfile p in _incoming) _requestTile(p),
          ],
          const SizedBox(height: 22),
          _sectionTitle('Arkadaş sıralaması'),
          const SizedBox(height: 10),
          _leaderboard(),
        ],
      ],
    );
  }

  Widget _errorBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Center(
        child: Column(
          children: <Widget>[
            Text(_error!, style: const TextStyle(color: AppColors.inkLight)),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, {int? badge}) {
    return Row(
      children: <Widget>[
        Text(text,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
        if (badge != null) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$badge',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ],
      ],
    );
  }

  // --- Lig kartı ---

  Widget _leagueCard() {
    final LeagueBoard? board = _board;
    final League league = board?.tier ?? gameProgress.league;
    final League? next = league.next;
    // Grubumdaki sıram (yükselme bölgesinde miyim?).
    final int myRank = board == null
        ? 0
        : board.entries.indexWhere((LeagueEntry e) => e.userId == _meId) + 1;
    final int members = board?.entries.length ?? 0;
    final bool promoting = myRank > 0 && myRank <= League.promotionCount;
    // Düşme yalnızca grup kalabalıkken işler.
    final bool demoting = myRank > 0 &&
        members > League.promotionCount + League.demotionCount &&
        myRank > members - League.demotionCount;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[league.color, league.color.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: league.color.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(league.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(league.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'Bu hafta ${gameProgress.weeklyXp} XP · '
                      'toplam ${gameProgress.xp} XP',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  promoting
                      ? Icons.trending_up_rounded
                      : (demoting
                          ? Icons.trending_down_rounded
                          : Icons.emoji_events_outlined),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    board == null
                        ? 'Bu hafta bir soru çöz, gruba katıl.'
                        : myRank == 0
                            ? 'Gruba katıldın, sıralamaya girmek için çöz.'
                            : promoting
                                ? '$myRank. sıradasın — ilk ${League.promotionCount} '
                                    '${next == null ? "zirvede kalır" : "${next.label}'ne çıkar"}!'
                                : demoting
                                    ? '$myRank. sıradasın — düşme bölgesindesin, '
                                        '${league.previous?.label ?? "alt lige"} '
                                        'düşmemek için çöz!'
                                    : '$myRank. sıradasın — ilk '
                                        '${League.promotionCount}\'e girmen lazım.',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (board != null) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                board.daysLeft <= 1
                    ? 'Hafta bugün kapanıyor!'
                    : 'Haftanın bitimine ${board.daysLeft} gün',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Arama ---

  Widget _searchField() {
    return TextField(
      controller: _query,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Takma adla arkadaş ara…',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkLight),
        suffixIcon: _query.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => _query.clear(),
              ),
        filled: true,
        fillColor: const Color(0xFFF4F4F4),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _searchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('Kimse bulunamadı.',
              style: TextStyle(color: AppColors.inkLight)),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final PublicProfile p in _results) _personTile(p),
      ],
    );
  }

  /// Arama sonucundaki kişi + duruma göre aksiyon.
  Widget _personTile(PublicProfile p) {
    final FriendState state = _stateOf(p.id);
    return _card(
      child: Row(
        children: <Widget>[
          _avatar(p),
          const SizedBox(width: 12),
          Expanded(child: _nameBlock(p)),
          _actionFor(p, state),
        ],
      ),
    );
  }

  Widget _actionFor(PublicProfile p, FriendState state) {
    if (_busy.contains(p.id)) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return switch (state) {
      FriendState.none => _pill(
          label: 'Ekle',
          icon: Icons.person_add_alt_1_rounded,
          color: AppColors.green,
          onTap: () => _act(p.id, () => socialRepository.sendRequest(p.id)),
        ),
      FriendState.outgoing => _pill(
          label: 'İstek gönderildi',
          color: AppColors.inkLight,
          filled: false,
          onTap: () => _act(p.id, () => socialRepository.removeRelation(p.id)),
        ),
      FriendState.incoming => _pill(
          label: 'Kabul et',
          icon: Icons.check_rounded,
          color: AppColors.blue,
          onTap: () => _act(p.id, () => socialRepository.acceptRequest(p.id)),
        ),
      FriendState.friends => _pill(
          label: 'Arkadaşsınız',
          icon: Icons.check_circle_rounded,
          color: AppColors.green,
          filled: false,
          onTap: null,
        ),
    };
  }

  // --- Gelen istekler ---

  Widget _requestTile(PublicProfile p) {
    final bool busy = _busy.contains(p.id);
    return _card(
      child: Row(
        children: <Widget>[
          _avatar(p),
          const SizedBox(width: 12),
          Expanded(child: _nameBlock(p)),
          if (busy)
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
          else ...<Widget>[
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.inkLight),
              tooltip: 'Reddet',
              onPressed: () =>
                  _act(p.id, () => socialRepository.removeRelation(p.id)),
            ),
            _pill(
              label: 'Kabul',
              icon: Icons.check_rounded,
              color: AppColors.green,
              onTap: () =>
                  _act(p.id, () => socialRepository.acceptRequest(p.id)),
            ),
          ],
        ],
      ),
    );
  }

  // --- Arkadaş sıralaması ---

  Widget _leaderboard() {
    final List<PublicProfile> rows = <PublicProfile>[
      PublicProfile(
        id: _meId ?? 'me',
        nickname: userProfile.nickname ?? 'Sen',
        xp: gameProgress.xp,
        streak: gameProgress.streak,
        mascot: userProfile.mascot,
      ),
      ..._friends,
    ]..sort((PublicProfile a, PublicProfile b) => b.xp.compareTo(a.xp));

    if (rows.length == 1) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: <Widget>[
              Text('👋', style: TextStyle(fontSize: 32)),
              SizedBox(height: 8),
              Text(
                'Henüz arkadaşın yok.\nYukarıdan takma adıyla arayıp ekle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkLight, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < rows.length; i++)
          _rankTile(i + 1, rows[i], rows[i].id == _meId),
      ],
    );
  }

  Widget _rankTile(int rank, PublicProfile p, bool isMe) {
    final Color medal = switch (rank) {
      1 => AppColors.gold,
      2 => const Color(0xFF9AA5B1),
      3 => const Color(0xFFB07242),
      _ => AppColors.inkLight,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.greenBg.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? AppColors.green : AppColors.line,
          width: isMe ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: medal),
            ),
          ),
          const SizedBox(width: 6),
          _avatar(p),
          const SizedBox(width: 12),
          Expanded(child: _nameBlock(p, isMe: isMe)),
          Text('${p.xp} XP',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.ink)),
        ],
      ),
    );
  }

  // --- Ortak parçalar ---

  Widget _avatar(PublicProfile p) => _avatarOf(p.mascot);

  Widget _avatarOf(Mascot? m) {
    final Color c = m?.color ?? AppColors.purple;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      // Maskot görselleri eklenince buradaki emoji değişecek.
      child: Text(m?.emoji ?? '🐻', style: const TextStyle(fontSize: 20)),
    );
  }

  Widget _nameBlock(PublicProfile p, {bool isMe = false}) => _nameOf(
        nickname: p.nickname,
        league: p.league,
        streak: p.streak,
        isMe: isMe,
      );

  Widget _nameOf({
    required String nickname,
    required int streak,
    League? league,
    bool isMe = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppColors.ink),
              ),
            ),
            if (isMe) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('sen',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: <Widget>[
            if (league != null) ...<Widget>[
              Text(league.emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(league.label,
                  style: const TextStyle(
                      color: AppColors.inkLight, fontSize: 12)),
            ],
            if (streak > 0) ...<Widget>[
              if (league != null) const SizedBox(width: 8),
              const Text('🔥', style: TextStyle(fontSize: 12)),
              Text('$streak',
                  style: const TextStyle(
                      color: AppColors.inkLight, fontSize: 12)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: child,
    );
  }

  Widget _pill({
    required String label,
    required Color color,
    IconData? icon,
    bool filled = true,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              sound.tap();
              onTap();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: filled ? Colors.white : color),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    color: filled ? Colors.white : color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

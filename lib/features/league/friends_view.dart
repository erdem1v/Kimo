import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/friend_repository.dart';
import '../../data/social_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/social.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';
import '../social/public_profile_screen.dart';

/// 3m — Arkadaşlar.
///
/// **Takma ad araması KALDIRILDI.** Tek ekleme yolu arkadaş kodu. Serbest metin
/// araması `profiles_public` görünümünü dizin gibi dökülebilir kılıyordu:
/// yaygın adları taramak bütün kullanıcı tabanını listelemeye yetiyordu.
/// Task 01 bunu "sosyal/UX pass'ine ertelendi" diye açık bırakmıştı; burası o
/// pass ve `socialRepository.search()` tamamen silindi.
///
/// Kod 31 harflik bir alfabeden 6 karakter (≈887 milyon) ve `add_friend_by_code`
/// saatte 20 denemeyle sınırlı, dolayısıyla tarama yolu kapalı.
class FriendsView extends StatefulWidget {
  const FriendsView({super.key});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  bool get _remote => SupabaseConfig.isConfigured;

  final TextEditingController _code = TextEditingController();

  List<Friendship> _relations = <Friendship>[];
  Map<String, PublicProfile> _people = <String, PublicProfile>{};
  Map<String, int> _mutual = <String, int>{};
  String? _myCode;

  bool _loading = true;
  bool _failed = false;
  bool _adding = false;

  /// İşlem sürerken kilitlenen kullanıcılar.
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    if (_remote) {
      _load();
      refreshBus.addListener(_onRefresh);
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    refreshBus.removeListener(_onRefresh);
    _code.dispose();
    super.dispose();
  }

  void _onRefresh() {
    if (mounted && !_loading) _load();
  }

  String? get _meId => socialRepository.currentUserId;

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final List<Friendship> rels = await socialRepository.relations();
      final String me = _meId ?? '';
      final List<String> ids =
          rels.map((Friendship f) => f.otherId(me)).toSet().toList();
      final List<PublicProfile> people =
          await socialRepository.profilesByIds(ids);
      final String? code = await friendRepository.myCode();

      // Ortak arkadaş sayısı YALNIZCA gelen istekler için isteniyor: kabul
      // edilmiş arkadaşlarda anlamı yok ve her satır için bir RPC çağrısı
      // listeyi gereksizce yavaşlatırdı.
      final List<String> pendingIds = <String>[
        for (final Friendship f in rels)
          if (!f.accepted && f.stateFor(me) == FriendState.incoming)
            f.otherId(me),
      ];
      final List<int> counts = await Future.wait<int>(<Future<int>>[
        for (final String id in pendingIds) friendRepository.mutualFriends(id),
      ]);

      if (!mounted) return;
      setState(() {
        _relations = rels;
        _people = <String, PublicProfile>{
          for (final PublicProfile p in people) p.id: p,
        };
        _mutual = <String, int>{
          for (int i = 0; i < pendingIds.length; i++) pendingIds[i]: counts[i],
        };
        _myCode = code;
        _loading = false;
      });
    } catch (e) {
      debugPrint('arkadaşlar yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

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

  // ------------------------------------------------------------------ eylem

  Future<void> _act(String userId, Future<void> Function() action) async {
    if (_busy.contains(userId)) return;
    setState(() => _busy.add(userId));
    try {
      await action();
      await _load();
    } catch (e) {
      debugPrint('arkadaş işlemi başarısız: $e');
      if (mounted) _snack(L10n.of(context).friendsActionFailed);
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  Future<void> _addByCode() async {
    final L10n l = L10n.of(context);
    final String raw = _code.text.trim();
    if (raw.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      final AddFriendResult res = await friendRepository.addByCode(raw);
      if (!mounted) return;
      // Sunucu ayrım YAPMIYOR: kod yok / kendi kodun / engelli / anonim hepsi
      // aynı mesajı alıyor. Bir kodun var olup olmadığını sızdırmak, kod
      // uzayını taramayı ucuzlatırdı.
      _snack(switch (res.reason) {
        'eklendi' => l.friendsAddSent(res.nickname ?? l.defaultNickname),
        'onay_bekleniyor' => l.friendsAddBlockedByGuardian,
        _ => l.friendsAddNotFound,
      });
      if (res.ok) {
        _code.clear();
        await _load();
      }
    } catch (e) {
      debugPrint('kodla ekleme başarısız: $e');
      if (mounted) _snack(l.friendsAddFailed);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _rotate() async {
    final L10n l = L10n.of(context);
    sound.tap();
    try {
      final String? code = await friendRepository.rotateCode();
      if (!mounted) return;
      setState(() => _myCode = code);
      _snack(l.friendsCodeRotated);
    } catch (e) {
      debugPrint('kod yenilenemedi: $e');
      if (!mounted) return;
      // Sunucu günde bir kez sınırını `54000` ile reddediyor; bu bir hata
      // değil, kuralın kendisi — ayrı bir mesajla söyleniyor.
      _snack(e.toString().contains('54000')
          ? l.friendsCodeRotateOncePerDay
          : l.friendsCodeRotateFailed);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final KimoTypography t = context.t;
    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.screen,
          Gap.screen,
          Gap.screen + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: t.section),
            const SizedBox(height: Gap.sm),
            Text(body, style: t.body),
            const SizedBox(height: Gap.lg),
            KimoButton(
              label: action,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Gap.sm),
            KimoButton(
              label: L10n.of(ctx).actionCancel,
              kind: KimoButtonKind.tertiary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  // -------------------------------------------------------------------- yapı

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            message: l.friendsLoadFailed,
            action: KimoButton(
              label: l.actionRetry,
              expand: false,
              onPressed: _load,
            ),
          ),
        ),
      );
    }

    final List<PublicProfile> incoming = _incoming;
    final List<PublicProfile> friends = _friends;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Gap.screen, 0, Gap.screen, Gap.section),
        children: <Widget>[
          _myCodeCard(context, l),
          const SizedBox(height: Gap.md),
          _addCard(context, l),
          if (incoming.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.xl),
            SectionHeader(
              title: l.friendsRequests,
              trailing: StatusBadge(
                label: '${incoming.length}',
                tone: BadgeTone.pending,
              ),
            ),
            const SizedBox(height: Gap.md),
            for (final PublicProfile p in incoming) ...<Widget>[
              _requestTile(context, l, p),
              const SizedBox(height: Gap.sm),
            ],
          ],
          const SizedBox(height: Gap.xl),
          SectionHeader(title: l.friendsList),
          const SizedBox(height: Gap.md),
          if (friends.isEmpty)
            EmptyState(message: l.friendsEmpty)
          else
            for (final PublicProfile p in friends) ...<Widget>[
              _friendTile(context, l, p),
              const SizedBox(height: Gap.sm),
            ],
        ],
      ),
    );
  }

  Widget _myCodeCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final String? code = _myCode;
    return KimoCard(
      padding: const EdgeInsets.all(Gap.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.friendsMyCode, style: t.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: Gap.sm),
          Row(
            children: <Widget>[
              Expanded(
                // `myCode()` kodu zaten tireli döndürüyor; burada tekrar
                // biçimlendirmiyoruz.
                child: Text(code ?? '—', style: t.numberLarge),
              ),
              if (code != null)
                IconButton(
                  onPressed: () async {
                    sound.tap();
                    await Clipboard.setData(ClipboardData(text: code));
                    if (mounted) _snack(l.actionCopied);
                  },
                  icon: KimoIcon(KimoIcons.notebook, size: 20, color: c.inkMuted),
                  tooltip: l.actionCopy,
                ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(l.friendsCodeHint, style: t.caption),
          if (code != null) ...<Widget>[
            const SizedBox(height: Gap.md),
            KimoButton(
              label: l.friendsCodeRotate,
              kind: KimoButtonKind.tertiary,
              expand: false,
              minHeight: Sizes.rowMin,
              onPressed: _rotate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _addCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.all(Gap.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.friendsAddTitle, style: t.bodyStrong),
          const SizedBox(height: Gap.md),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  // Kod alfabesi harf ve rakam; tire gösterimde var, girişte
                  // serbest — `normalize_friend_code` sunucuda temizliyor.
                  maxLength: 8,
                  style: t.numberMedium,
                  decoration: InputDecoration(
                    hintText: l.friendsAddHint,
                    counterText: '',
                    filled: true,
                    fillColor: c.sunken,
                    border: OutlineInputBorder(
                      borderRadius: Radii.all(Radii.pill),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addByCode(),
                ),
              ),
              const SizedBox(width: Gap.sm),
              KimoButton(
                label: l.friendsAddAction,
                expand: false,
                minHeight: Sizes.rowMin,
                onPressed: _adding ? null : _addByCode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestTile(BuildContext context, L10n l, PublicProfile p) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int mutual = _mutual[p.id] ?? 0;
    final bool busy = _busy.contains(p.id);
    return KimoCard(
      padding: const EdgeInsets.all(Gap.md),
      radius: Radii.tile,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(mascot: p.mascot, avatarPath: p.avatarPath, size: 40),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(p.nickname, style: t.label),
                    if (mutual > 0)
                      Text(
                        l.friendsMutual(mutual),
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: <Widget>[
              Expanded(
                child: KimoButton(
                  label: l.friendsAccept,
                  minHeight: Sizes.rowMin,
                  onPressed: busy
                      ? null
                      : () => _act(p.id,
                          () => socialRepository.acceptRequest(p.id)),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: KimoButton(
                  label: l.friendsBlock,
                  kind: KimoButtonKind.tertiary,
                  minHeight: Sizes.rowMin,
                  onPressed: busy ? null : () => _blockFlow(l, p),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _friendTile(BuildContext context, L10n l, PublicProfile p) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool busy = _busy.contains(p.id);
    return KimoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.md),
      radius: Radii.tile,
      onTap: () {
        sound.tap();
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => PublicProfileScreen(userId: p.id, initial: p),
          ),
        );
      },
      child: Row(
        children: <Widget>[
          UserAvatar(mascot: p.mascot, avatarPath: p.avatarPath, size: 40),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              p.nickname,
              overflow: TextOverflow.ellipsis,
              style: t.label,
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            PopupMenuButton<String>(
              icon: KimoIcon(KimoIcons.settings, size: 20, color: c.inkMuted),
              onSelected: (String v) {
                if (v == 'remove') {
                  _removeFlow(l, p);
                } else if (v == 'block') {
                  _blockFlow(l, p);
                }
              },
              itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text(l.friendsRemove),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: Text(l.friendsBlock),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _removeFlow(L10n l, PublicProfile p) async {
    final bool ok = await _confirm(
      l.friendsConfirmRemoveTitle,
      l.friendsConfirmRemoveBody(p.nickname),
      l.friendsRemove,
    );
    if (!ok || !mounted) return;
    await _act(p.id, () => socialRepository.removeRelation(p.id));
  }

  Future<void> _blockFlow(L10n l, PublicProfile p) async {
    final bool ok = await _confirm(
      l.friendsConfirmBlockTitle,
      l.friendsConfirmBlockBody(p.nickname),
      l.friendsBlock,
    );
    if (!ok || !mounted) return;
    await _act(p.id, () => friendRepository.block(p.id));
    if (mounted) _snack(l.friendsBlocked);
  }
}

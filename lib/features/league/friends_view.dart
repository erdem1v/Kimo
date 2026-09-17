import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/daily_state_repository.dart';
import '../../data/friend_repository.dart';
import '../../data/social_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/social.dart';
import '../../services/sound_service.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';
import '../inbox/send_flow.dart';
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
  final TextEditingController _code = TextEditingController();

  List<Friendship> _relations = <Friendship>[];
  Map<String, PublicProfile> _people = <String, PublicProfile>{};
  Map<String, int> _mutual = <String, int>{};
  String? _myCode;

  /// Ortak seriler — arkadaş kimliğine göre (Tur 7 · n6).
  ///
  /// ORTAK SERİ YALNIZCA BU SATIRDA YAŞIYOR: ayrı bir sayfa ya da ana ekran
  /// kartı YOK. Tasarımın gerekçesi açık — "ikinci bir seri sayacı kaygıyı
  /// ikiye katlar". Ortak seri yoksa satırda hiçbir şey görünmüyor; boş durum
  /// GÖSTERİLMİYOR.
  Map<String, PairStreak> _pairs = <String, PairStreak>{};

  /// Sunucu bayrağı (0079). Kapalıysa ortak seri yüzeyi HİÇ çizilmiyor ve
  /// çağrısı da yapılmıyor.
  bool _pairEnabled = false;

  bool _loading = true;
  bool _failed = false;
  bool _adding = false;

  /// İşlem sürerken kilitlenen kullanıcılar.
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    refreshBus.addListener(_onRefresh);
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
      // `myCode` listeden bağımsız: ilişki+profil zinciriyle PARALEL yürür
      // (profilesByIds gerçekten relations'a bağımlı; o zincir kalıyor).
      final Future<String?> codeFuture = friendRepository.myCode();
      // ENGELLİLER, listeden süzmek için. Engelleme arkadaşlık SATIRINI
      // silmiyor (bilinçli: engel kalkınca ilişki geri gelsin) ve `0091`
      // `are_friends`i engel-farkında yaptı — ama `relations()` tabloyu
      // DOĞRUDAN okuyor, yani satır geliyor. Süzgeç burada bir SUNUM kararı:
      // güvenlik yüzeylerinin hepsi (avatar, gönderim, ortak seri, lig)
      // sunucuda zaten kapalı; burada kapatılan şey kullanıcının "engelledim
      // ama hâlâ listemde" çelişkisi (`app_tr.arb:933` "listelerde seni
      // göremez" diyor).
      final Future<List<BlockedUser>> blockedFuture =
          friendRepository.blockedUsers();
      final List<Friendship> rels = await socialRepository.relations();
      final String me = _meId ?? '';
      final List<String> ids =
          rels.map((Friendship f) => f.otherId(me)).toSet().toList();
      final List<PublicProfile> people =
          await socialRepository.profilesByIds(ids);
      final String? code = await codeFuture;
      final Set<String> blocked = <String>{
        for (final BlockedUser b in await blockedFuture) b.id,
      };

      // Bayrak KAPALIYSA ortak seri çağrısı HİÇ yapılmıyor: kapatılmış bir
      // özelliğin ağ trafiği de olmamalı.
      final DailyState? daily = await dailyStateRepository.read();
      final bool pairOn = daily?.pairStreakEnabled ?? false;
      final List<PairStreak> pairs =
          pairOn ? await pairStreakRepository.mine() : <PairStreak>[];

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
        _blocked = blocked;
        _pairEnabled = pairOn;
        _pairs = <String, PairStreak>{
          for (final PairStreak p in pairs) p.friendId: p,
        };
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

  /// Engellediğim kullanıcılar. Arkadaş satırı sunucuda DURUYOR (engel
  /// kalkınca ilişki geri gelsin diye); listeden süzmek sunum kararı.
  Set<String> _blocked = const <String>{};

  List<PublicProfile> get _friends {
    final String me = _meId ?? '';
    return _relations
        .where((Friendship f) => f.accepted && !_blocked.contains(f.otherId(me)))
        .map((Friendship f) => _people[f.otherId(me)])
        .whereType<PublicProfile>()
        .toList();
  }

  List<PublicProfile> get _incoming {
    final String me = _meId ?? '';
    return _relations
        .where((Friendship f) =>
            !f.accepted &&
            f.stateFor(me) == FriendState.incoming &&
            !_blocked.contains(f.otherId(me)))
        .map((Friendship f) => _people[f.otherId(me)])
        .whereType<PublicProfile>()
        .toList();
  }

  // ------------------------------------------------------------------ eylem

  /// Eylemi çalıştırır ve GERÇEKTEN olup olmadığını döndürür.
  ///
  /// Dönüş değeri Task 16'da eklendi: `_blockFlow` eylemin sonucuna bakmadan
  /// "Engellendi" diyordu. Hata durumunda kullanıcı önce
  /// `friendsActionFailed`i, hemen ardından "Engellendi"yi görüyordu — yani
  /// son söz, olmamış bir şeyin olduğunu söylüyordu.
  Future<bool> _act(String userId, Future<void> Function() action) async {
    if (_busy.contains(userId)) return false;
    setState(() => _busy.add(userId));
    try {
      await action();
      await _load();
      return true;
    } catch (e) {
      debugPrint('arkadaş işlemi başarısız: $e');
      if (mounted) _snack(L10n.of(context).friendsActionFailed);
      return false;
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
        'askida' => l.friendsAddBlockedBySuspension,
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

  /// Kod yenileme tek seferlik (Task 14).
  ///
  /// NEDEN: sunucu yenilemeyi günde BİR kez kabul ediyor (`54000`). Koruma
  /// yokken hızlı çift dokunuş iki RPC gönderiyor ve kullanıcı arka arkaya
  /// "Kod yenilendi" ile "günde bir kez yenileyebilirsin" görüyordu —
  /// üstelik ikinci cevap önce dönerse ekranda YENİLENMEDEN ÖNCEKİ kod
  /// kalabiliyordu. Hemen yanındaki `_add` akışı `_adding` bayrağını zaten
  /// taşıyor; aynı koruma buraya uygulanmamıştı.
  bool _rotating = false;

  Future<void> _rotate() async {
    if (_rotating) return;
    final L10n l = L10n.of(context);
    sound.tap();
    setState(() => _rotating = true);
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
    } finally {
      if (mounted) setState(() => _rotating = false);
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
          // 4. AN — RİSK ve KIRILMA (Tur 7 · n6). İkisi de arkadaş listesinde
          // yaşıyor; ayrı bir sayfa ya da ana ekran kartı YOK.
          ..._pairNotices(context, l),
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
              // Devre dışı bırakmak GÖRÜNÜR koruma; `_rotating` kontrolü
              // içeride de duruyor çünkü `KimoButton` bir `GestureDetector`
              // ve iki dokunuş aynı karede gelebiliyor.
              onPressed: _rotating ? null : _rotate,
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
              // BOŞ KODDA KAPALI (Task 15 · D2). Eskiden yalnızca `_adding`
              // kapatıyordu: alan boşken düğme tamamen etkin görünüyor,
              // dokunuş `_addByCode`ın ilk satırında sessizce dönüyor ve
              // kullanıcıya hiçbir şey söylenmiyordu.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _code,
                builder: (BuildContext ctx, TextEditingValue v, Widget? _) =>
                    KimoButton(
                  label: l.friendsAddAction,
                  expand: false,
                  busy: _adding,
                  minHeight: Sizes.rowMin,
                  onPressed: (_adding || v.text.trim().isEmpty)
                      ? null
                      : _addByCode,
                ),
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
              UserAvatar(name: p.nickname, avatarPath: p.avatarPath, size: 40),
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
                  // İKİNCİL: bekleyen istek başına bir tane çiziliyor. Üç
                  // istekte, "Ekle" ile birlikte dört birincil düğme aynı
                  // ekranda duruyordu.
                  kind: KimoButtonKind.secondary,
                  minHeight: Sizes.rowMin,
                  onPressed: busy
                      ? null
                      : () => _act(p.id,
                          () => socialRepository.acceptRequest(p.id)),
                ),
              ),
              const SizedBox(width: Gap.sm),
              // REDDET (Task 16). Gelen istekte yalnızca "Kabul et" ve
              // "Engelle" vardı: hayır demenin tek yolu karşı tarafı
              // ENGELLEMEKTİ. Engelleme çok daha ağır bir eylem — lig
              // tahtasında maskeliyor, bütün sosyal yüzeyleri kapatıyor ve
              // kullanıcının kendi "Engellenen kişiler" listesini şişiriyor.
              Expanded(
                child: KimoButton(
                  label: l.friendsDecline,
                  kind: KimoButtonKind.tertiary,
                  minHeight: Sizes.rowMin,
                  onPressed: busy
                      ? null
                      : () => _act(
                          p.id, () => socialRepository.removeRelation(p.id)),
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
          UserAvatar(name: p.nickname, avatarPath: p.avatarPath, size: 40),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              p.nickname,
              overflow: TextOverflow.ellipsis,
              style: t.label,
            ),
          ),
          // ORTAK SERİ ROZETİ (Tur 7 · n6). Kişisel seriyle AYNI alev, farklı
          // renk: mercan senin serin, NANE ortak seri. `mintTint`/`mintText`
          // elmas hapı için tanımlıydı ve elmas v1'de gizli olduğu için
          // kullanılmıyordu — yeniden kullanılıyor.
          //
          // Seri YOKSA HİÇBİR ŞEY çizilmiyor: boş durum göstermek, olmayan
          // bir mekaniği varmış gibi sunmak olurdu.
          if (_pairEnabled && (_pairs[p.id]?.streak ?? 0) > 0) ...<Widget>[
            const SizedBox(width: Gap.sm),
            _pairBadge(context, l, _pairs[p.id]!),
          ],
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
                if (v == 'leavePair') {
                  // ÇIKIŞ KARŞI TARAFA BİLDİRİLMİYOR: bildirilirse ayrılmak
                  // sosyal olarak cezalandırılırdı.
                  unawaited(_act(p.id, () async {
                    await pairStreakRepository.leave(p.id);
                  }));
                } else if (v == 'send') {
                  unawaited(showSendEntrySheet(
                    context,
                    friendId: p.id,
                    friendName: p.nickname,
                  ));
                } else if (v == 'remove') {
                  _removeFlow(l, p);
                } else if (v == 'block') {
                  _blockFlow(l, p);
                }
              },
              itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                // Tur 7 · n5: gönderme akışının ARKADAŞ-ÖNCE girişi. Bugüne
                // kadar tek giriş Hatalarım satırındaki ikondu, yani akış
                // zorunlu olarak soru-önceydi.
                PopupMenuItem<String>(
                  value: 'send',
                  child: Text(l.mistakesSend),
                ),
                if (_pairEnabled && _pairs.containsKey(p.id))
                  PopupMenuItem<String>(
                    value: 'leavePair',
                    child: Text(l.pairStreakLeave),
                  ),
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

  /// Risk ve kırılma satırları.
  ///
  /// İKİSİNDE DE KİMİN ÇÖZMEDİĞİ YAZMIYOR. Risk satırı yalnızca KULLANICININ
  /// KENDİ PAYI eksikken çıkıyor ("bir soru çözersen … devam eder") — arkadaşın
  /// eksiği bir uyarıya dönüşmüyor, çünkü "arkadaşın seni bekliyor" arkadaşı
  /// baskı aracına çevirirdi.
  ///
  /// KIRILMA BİLDİRİMİ HİÇ GÖNDERİLMİYOR: kullanıcı uygulamayı açtığında
  /// burada görüyor. Metin suçlamıyor ve DAVETLE bitiyor.
  List<Widget> _pairNotices(BuildContext context, L10n l) {
    if (!_pairEnabled || _pairs.isEmpty) return const <Widget>[];
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final List<Widget> out = <Widget>[];

    // RİSK: seri açık, benim payım eksik.
    final Iterable<PairStreak> atRisk =
        _pairs.values.where((PairStreak p) => p.streak > 0 && p.myTurn);
    if (atRisk.isNotEmpty) {
      final PairStreak p = atRisk.first;
      out.add(KimoCard(
        radius: Radii.tile,
        color: c.mintTint,
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.pairStreakRiskTitle,
                style: t.bodyStrong.copyWith(color: c.mintText)),
            const SizedBox(height: Gap.xxs),
            Text(l.pairStreakRiskBody(p.streak),
                style: t.caption.copyWith(color: c.mintText)),
          ],
        ),
      ));
      out.add(const SizedBox(height: Gap.md));
    }

    // KIRILMA: satır var ama sayı sıfırlandı.
    final Iterable<PairStreak> broken =
        _pairs.values.where((PairStreak p) => p.streak == 0);
    if (broken.isNotEmpty) {
      final PairStreak p = broken.first;
      out.add(KimoCard(
        radius: Radii.tile,
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.pairStreakBrokenTitle, style: t.bodyStrong),
            const SizedBox(height: Gap.xxs),
            Text(l.pairStreakBrokenBody, style: t.caption),
            const SizedBox(height: Gap.md),
            KimoButton(
              label: l.pairStreakBrokenAction,
              kind: KimoButtonKind.secondary,
              minHeight: Sizes.rowMin,
              expand: false,
              onPressed: () => unawaited(showSendEntrySheet(
                context,
                friendId: p.friendId,
                friendName: p.nickname,
              )),
            ),
          ],
        ),
      ));
      out.add(const SizedBox(height: Gap.md));
    }
    return out;
  }

  /// Nane renkli ortak seri rozeti.
  Widget _pairBadge(BuildContext context, L10n l, PairStreak s) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Semantics(
      label: '${s.streak} ${l.pairStreakLabel}',
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm, vertical: Gap.xxs),
        decoration: BoxDecoration(
          color: c.mintTint,
          borderRadius: Radii.all(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            KimoIcon(KimoIcons.flame, size: 14, color: c.mintText),
            const SizedBox(width: Gap.xxs),
            Text('${s.streak}',
                style: t.numberSmall.copyWith(color: c.mintText)),
          ],
        ),
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
    final bool done = await _act(p.id, () => friendRepository.block(p.id));
    if (done && mounted) _snack(l.friendsBlocked);
  }
}

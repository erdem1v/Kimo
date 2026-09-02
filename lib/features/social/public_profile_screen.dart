import 'package:flutter/material.dart';

import '../../data/friend_repository.dart';
import '../../data/social_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/social.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';

/// Başka bir kullanıcının profili: ligden ya da arkadaş listesinden açılır.
///
/// Yalnızca `profiles_public` görünümündeki alanlar gösteriliyor. O görünüm
/// e-posta, doğum yılı, veli e-postası ve arkadaş kodu TAŞIMIYOR — burada
/// gösterilmemesinin sebebi bir arayüz kararı değil, verinin gelmemesi.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId, this.initial});

  final String userId;

  /// Listede zaten elimizde olan bilgi: ekran boş açılmasın diye.
  final PublicProfile? initial;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  PublicProfile? _profile;
  int _mutual = 0;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final PublicProfile? p =
          await socialRepository.profileById(widget.userId);
      final int mutual = await friendRepository.mutualFriends(widget.userId);
      if (!mounted) return;
      setState(() {
        if (p != null) _profile = p;
        _mutual = mutual;
        _loading = false;
        _failed = p == null && widget.initial == null;
      });
    } catch (e) {
      debugPrint('profil yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _profile == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final PublicProfile? p = _profile;

    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        title: Text(l.publicProfileTitle, style: t.section),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: KimoIcon(KimoIcons.back, color: c.ink),
          tooltip: l.actionBack,
        ),
      ),
      body: p == null
          ? Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(Gap.screen),
                      child: EmptyState(
                        message: l.publicProfileLoadFailed,
                        action: _failed
                            ? KimoButton(
                                label: l.actionRetry,
                                expand: false,
                                onPressed: _load,
                              )
                            : null,
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.md, Gap.screen, Gap.section),
              children: <Widget>[
                Center(
                  child: UserAvatar(
                    size: 108,
                    avatarPath: p.avatarPath,
                    mascot: p.mascot,
                  ),
                ),
                const SizedBox(height: Gap.md),
                Text(p.nickname, textAlign: TextAlign.center, style: t.heading),
                if (_mutual > 0) ...<Widget>[
                  const SizedBox(height: Gap.sm),
                  Center(
                    child: StatusBadge(
                      label: l.friendsMutual(_mutual),
                      tone: BadgeTone.neutral,
                    ),
                  ),
                ],
                const SizedBox(height: Gap.xl),
                ProfileStatsRow(
                  xp: p.xp,
                  streak: p.streak,
                  friends: p.friendCount,
                ),
                const SizedBox(height: Gap.md),
                LeagueBanner(league: p.league),
              ],
            ),
    );
  }
}

/// Toplam XP · seri · arkadaş sayısı. Hem kendi profilinde hem başkasınınkinde
/// aynı görünsün diye ortak.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.xp,
    required this.streak,
    required this.friends,
  });

  final int xp;
  final int streak;
  final int friends;

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    return Row(
      children: <Widget>[
        Expanded(child: _cell(context, '$xp', l.profileXp)),
        const SizedBox(width: Gap.sm),
        Expanded(child: _cell(context, '$streak', l.profileStreak)),
        const SizedBox(width: Gap.sm),
        Expanded(child: _cell(context, '$friends', l.profileFriends)),
      ],
    );
  }

  Widget _cell(BuildContext context, String value, String label) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      child: Column(
        children: <Widget>[
          Text(value, style: t.numberLarge),
          const SizedBox(height: Gap.xxs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Lig şeridi.
///
/// XP ARTIK GÖSTERİLMİYOR: ligi belirleyen şey toplam XP değil, haftalık
/// sıralama. Yan yana koymak "XP biriktirince lig atlanır" izlenimi veriyordu
/// ve bu yanlış.
class LeagueBanner extends StatelessWidget {
  const LeagueBanner({super.key, required this.league});

  final League league;

  @override
  Widget build(BuildContext context) {
    final KimoTypography t = context.t;
    return KimoCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: league.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(league.label, style: t.bodyStrong)),
        ],
      ),
    );
  }
}

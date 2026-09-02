import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/social_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/mascot.dart';
import '../../models/social.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';
import '../social/public_profile_screen.dart';
import 'friends_view.dart';

/// 3l + 3m — Lig ve Arkadaşlar.
///
/// Tek sekme, iki görünüm. Segment üstte; alt navigasyonda ayrı iki sekme
/// açmak beş sekmelik çubuğu altıya çıkarırdı ve tasarımın sekme listesi sabit.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final L10n l = L10n.of(context);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.sm, Gap.screen, Gap.md),
              child: SegmentedTabs(
                labels: <String>[l.leagueTab, l.friendsTab],
                selectedIndex: _tab,
                onChanged: (int i) {
                  sound.tap();
                  setState(() => _tab = i);
                },
              ),
            ),
            Expanded(
              child: _tab == 0 ? const LeagueBoardView() : const FriendsView(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haftalık lig tahtası: 30 kişilik kohort, ilk 5 yükselir, son 5 düşer.
class LeagueBoardView extends StatefulWidget {
  const LeagueBoardView({super.key});

  @override
  State<LeagueBoardView> createState() => _LeagueBoardViewState();
}

class _LeagueBoardViewState extends State<LeagueBoardView> {
  bool get _remote => SupabaseConfig.isConfigured;

  LeagueBoard? _board;
  bool _loading = true;
  bool _failed = false;

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
    super.dispose();
  }

  void _onRefresh() {
    if (mounted && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final LeagueBoard? board = await socialRepository.myLeagueBoard();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
      });
      if (board != null) {
        gameProgress.league = board.tier;
        final int rank = board.entries.indexWhere(
              (LeagueEntry e) => e.userId == socialRepository.currentUserId,
            ) +
            1;
        unawaited(
          notifications.planLeagueReminder(
            enabled: userProfile.notifyEnabled,
            mascot: userProfile.mascot ?? Mascot.evHanimi,
            rank: rank,
            leagueLabel: board.tier.label,
            daysLeft: board.daysLeft,
          ),
        );
      }
    } catch (e) {
      debugPrint('lig yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            message: l.leagueLoadFailed,
            action: KimoButton(
              label: l.actionRetry,
              expand: false,
              onPressed: _load,
            ),
          ),
        ),
      );
    }

    final LeagueBoard? board = _board;
    if (board == null || board.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(message: l.leagueEmpty),
        ),
      );
    }

    final String? me = socialRepository.currentUserId;
    final int total = board.entries.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Gap.screen, 0, Gap.screen, Gap.section),
        children: <Widget>[
          _header(context, l, board, me, total),
          const SizedBox(height: Gap.lg),
          for (int i = 0; i < total; i++) ...<Widget>[
            // Bölge çizgileri GERÇEK kohort boyutuna göre çiziliyor: 30 kişilik
            // bir grup dolmamışsa (hafta başı) çizgiler yine doğru yerde durur
            // çünkü sunucu da ilk 5 / son 5 kuralını gerçek üye sayısına
            // uyguluyor (`settle_past_leagues`).
            if (i == League.promotionCount && total > League.promotionCount)
              _zoneLine(context, l.leaguePromotionZone, context.c.mint),
            if (total > League.demotionCount &&
                i == total - League.demotionCount &&
                i > League.promotionCount)
              _zoneLine(context, l.leagueDemotionZone, context.c.action),
            _row(context, i + 1, board.entries[i],
                board.entries[i].userId == me),
            const SizedBox(height: Gap.sm),
          ],
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    L10n l,
    LeagueBoard board,
    String? me,
    int total,
  ) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int rank =
        board.entries.indexWhere((LeagueEntry e) => e.userId == me) + 1;
    return KimoCard(
      padding: const EdgeInsets.all(Gap.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: board.tier.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(board.tier.label, style: t.section)),
              StatusBadge(
                label: l.leagueDaysLeft(board.daysLeft),
                tone: board.daysLeft <= 1 ? BadgeTone.alert : BadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            l.leagueCohortNote(
              League.cohortSize,
              League.promotionCount,
              League.demotionCount,
            ),
            style: t.caption.copyWith(color: c.inkSecondary),
          ),
          if (rank > 0) ...<Widget>[
            const SizedBox(height: Gap.md),
            Text(l.leagueRankOf(rank, total), style: t.numberMedium),
          ],
        ],
      ),
    );
  }

  Widget _zoneLine(BuildContext context, String label, Color color) {
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: color, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
            child: Text(label, style: t.overline.copyWith(color: color)),
          ),
          Expanded(child: Divider(color: color, thickness: 1.5)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int rank, LeagueEntry e, bool isMe) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return KimoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.md),
      radius: Radii.tile,
      elevated: isMe,
      color: isMe ? c.actionTint : c.card,
      onTap: isMe
          ? null
          : () {
              sound.tap();
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(userId: e.userId),
                ),
              );
            },
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text('$rank', style: t.numberSmall, textAlign: TextAlign.center),
          ),
          const SizedBox(width: Gap.sm),
          UserAvatar(mascot: e.mascot, avatarPath: e.avatarPath, size: 36),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              isMe ? l.leagueYou : e.nickname,
              overflow: TextOverflow.ellipsis,
              style: isMe ? t.bodyStrong.copyWith(color: c.actionText) : t.label,
            ),
          ),
          Text(
            l.leagueWeeklyXp(e.xp),
            style: t.numberSmall.copyWith(color: c.inkSecondary),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import 'session_result.dart';

/// 3i — Oturum sonu.
///
/// Üç şey gösteriyor ve üçü de gerçek: ne yapıldığı (soru sayısı, ilk denemede
/// bilinen, en uzun seri), ne kazanıldığı (sunucunun verdiği XP ve elmas) ve
/// nereye gidildiği (seviye şeridi).
///
/// **Sandık zaten açılmış olarak geliyor.** Ödülü veren `claim_daily_goal()`
/// çağrısı pratik ekranında, hedefe ulaşıldığı anda yapılıyor; buradaki dokunuş
/// yalnızca sonucu açıyor. Sandığa basınca RPC çağırsaydık, kullanıcı ekranı
/// kapatınca kazandığı ödül hiç yazılmamış olurdu.
class SessionEndScreen extends StatefulWidget {
  const SessionEndScreen({
    super.key,
    required this.result,
    this.canContinue = false,
  });

  final SessionResult result;

  /// Kalan sorularla devam teklifi gösterilsin mi. Ekran `true` döndürerek
  /// kapanır; kararı çağıran uyguluyor.
  final bool canContinue;

  @override
  State<SessionEndScreen> createState() => _SessionEndScreenState();
}

class _SessionEndScreenState extends State<SessionEndScreen> {
  final KimoController _kimo = KimoController();
  bool _chestOpen = false;

  @override
  void initState() {
    super.initState();
    _kimo.mood = KimoMood.happy;
    // Tepki yalnızca GERÇEKTEN olan bir şey için: seri büyüdüyse. Her oturum
    // sonunda `levelUp` oynatmak, olmayan bir seviye atlamasını kutlamak olurdu.
    if (widget.result.streakGrew) _kimo.trigger(KimoReaction.streakUp);
  }

  @override
  void dispose() {
    _kimo.dispose();
    super.dispose();
  }

  void _openChest() {
    if (_chestOpen) return;
    sound.levelUp();
    _kimo.trigger(KimoReaction.chestOpen);
    setState(() => _chestOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final SessionResult r = widget.result;

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                children: <Widget>[
                  const SizedBox(height: Gap.xl),
                  Center(child: Kimo(size: 140, controller: _kimo)),
                  const SizedBox(height: Gap.lg),
                  Text(
                    r.goalReached ? l.sessionGoalReached : l.sessionDoneOverline,
                    textAlign: TextAlign.center,
                    style: t.overline.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    l.sessionSolvedCount(r.solved),
                    textAlign: TextAlign.center,
                    style: t.title,
                  ),
                  if (r.streakGrew) ...<Widget>[
                    const SizedBox(height: Gap.md),
                    Center(
                      child: StatusBadge(
                        label: l.sessionStreakGrew(r.streak),
                        tone: BadgeTone.pending,
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.xl),
                  _stats(context, l, r),
                  if (r.gemsAwarded > 0) ...<Widget>[
                    const SizedBox(height: Gap.md),
                    _chest(context, l, r),
                  ],
                  const SizedBox(height: Gap.md),
                  _levelCard(context, l, r),
                  const SizedBox(height: Gap.xl),
                ],
              ),
            ),
            _actions(context, l, r),
          ],
        ),
      ),
    );
  }

  Widget _stats(BuildContext context, L10n l, SessionResult r) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _statTile(
            context,
            value: '${r.firstTryCorrect}',
            label: l.sessionFirstTry,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _statTile(
            context,
            // Kombo hiç oluşmadıysa (çevrimdışı ya da tek doğru) 1 gösteriliyor
            // — "×0 seri" diye bir şey yok.
            value: '×${r.longestCombo < 1 ? 1 : r.longestCombo}',
            label: l.sessionLongestCombo,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _statTile(
            context,
            value: '+${r.xpGained}',
            label: l.sessionXp,
          ),
        ),
      ],
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String value,
    required String label,
  }) {
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

  Widget _chest(BuildContext context, L10n l, SessionResult r) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      color: c.honeyTint,
      elevated: false,
      onTap: _chestOpen ? null : _openChest,
      child: Row(
        children: <Widget>[
          AnimatedScale(
            scale: _chestOpen ? 1.15 : 1,
            duration: Motion.count,
            curve: Curves.easeOutBack,
            child: KimoIcon(KimoIcons.gem, size: 32, color: c.honey),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              _chestOpen ? l.sessionChestGems(r.gemsAwarded) : l.sessionChestReady,
              style: t.bodyStrong.copyWith(color: c.honeyText),
            ),
          ),
          if (!_chestOpen)
            Text(l.sessionOpenChest, style: t.buttonSmall.copyWith(color: c.honeyText)),
        ],
      ),
    );
  }

  Widget _levelCard(BuildContext context, L10n l, SessionResult r) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(l.sessionLevel(r.level), style: t.bodyStrong)),
              Text(
                '${r.xpToNextLevel} ${l.sessionXp}',
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          KimoProgressBar(value: r.levelProgress),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, L10n l, SessionResult r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.md, Gap.screen, Gap.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.canContinue && r.remaining > 0) ...<Widget>[
            KimoButton(
              label: l.sessionExtraRound(r.remaining),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Gap.sm),
            KimoButton(
              label: l.sessionEnough,
              kind: KimoButtonKind.tertiary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ] else
            KimoButton(
              label: l.sessionContinue,
              onPressed: () => Navigator.of(context).pop(false),
            ),
        ],
      ),
    );
  }
}

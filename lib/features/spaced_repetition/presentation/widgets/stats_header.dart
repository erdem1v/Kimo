import 'package:flutter/material.dart';

import 'package:ai_yks_coach/core/localization/gen/app_localizations.dart';

/// Seans üstündeki oyunlaştırma göstergesi: can, XP ve günlük seri.
class StatsHeader extends StatelessWidget {
  const StatsHeader({
    super.key,
    required this.hearts,
    required this.xp,
    required this.streak,
  });

  final int hearts;
  final int xp;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _StatPill(
          icon: Icons.favorite_rounded,
          color: Colors.red,
          value: '$hearts',
          label: l10n.heartsLabel,
        ),
        _StatPill(
          icon: Icons.star_rounded,
          color: Colors.amber.shade700,
          value: '$xp',
          label: l10n.xpLabel,
        ),
        _StatPill(
          icon: Icons.local_fire_department_rounded,
          color: Colors.deepOrange,
          value: l10n.streakDays(streak),
          label: l10n.streakLabel,
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../state/game_progress.dart';
import '../theme/app_colors.dart';

/// Emoji + değer içeren yuvarlak istatistik pili (seri, elmas, can vb.).
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.emoji,
    required this.value,
    required this.color,
  });

  final String emoji;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// gameProgress'i dinleyip seri / elmas / can pillerini gösteren üst şerit.
class TopStatsBar extends StatelessWidget {
  const TopStatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameProgress,
      builder: (BuildContext context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            StatPill(
                emoji: '🔥',
                value: '${gameProgress.streak}',
                color: AppColors.orange),
            StatPill(
                emoji: '💎',
                value: '${gameProgress.gems}',
                color: AppColors.blue),
            StatPill(
                emoji: '❤️',
                value: '${gameProgress.hearts}',
                color: AppColors.red),
          ],
        );
      },
    );
  }
}

/// Yuvarlak, kalın ilerleme çubuğu.
class RoundedProgressBar extends StatelessWidget {
  const RoundedProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.green,
    this.background = AppColors.line,
    this.height = 16,
  });

  final double value;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: <Widget>[
          Container(height: height, color: background),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: 0.9,
                  heightFactor: 0.35,
                  child: Container(
                    margin: EdgeInsets.only(top: height * 0.18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pratik başlığındaki can göstergesi (dolu + boş kalpler).
class HeartsRow extends StatelessWidget {
  const HeartsRow({super.key, required this.hearts, required this.maxHearts});

  final int hearts;
  final int maxHearts;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < maxHearts; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i < hearts ? Icons.favorite : Icons.favorite_border,
              color: i < hearts ? AppColors.red : AppColors.line,
              size: 22,
            ),
          ),
      ],
    );
  }
}

/// Kalın bölüm başlığı.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    );
  }
}

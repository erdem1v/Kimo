import 'package:flutter/material.dart';

import 'package:ai_yks_coach/core/localization/gen/app_localizations.dart';
import 'package:ai_yks_coach/features/spaced_repetition/domain/review_item.dart';
import 'package:ai_yks_coach/shared/models/models.dart';
import 'package:ai_yks_coach/shared/widgets/tip_a_shape_view.dart';

/// Tek bir tekrar sorusunu gösteren kart: kavram/zorluk etiketleri, soru metni,
/// (varsa) Tip A şekli, cevabı gösterme ve doğru/yanlış işaretleme kontrolleri.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.item,
    required this.revealed,
    required this.onReveal,
    required this.onAnswer,
  });

  final ReviewItem item;
  final bool revealed;
  final VoidCallback onReveal;
  final void Function(ReviewGrade grade) onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final Question q = item.question;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _chip(context, Icons.school_outlined, _prettyConcept(q.conceptId)),
                  _chip(context, Icons.bar_chart_rounded, _difficultyText(l10n, q.difficulty)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                q.text,
                style: theme.textTheme.titleLarge?.copyWith(height: 1.35),
              ),
              if (q.drawingParams != null) ...<Widget>[
                const SizedBox(height: 20),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: TipAShapeView(drawingParams: q.drawingParams!),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (!revealed)
                FilledButton.icon(
                  onPressed: onReveal,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(l10n.showAnswer),
                )
              else ...<Widget>[
                _AnswerBlock(question: q),
                const SizedBox(height: 20),
                _AnswerButtons(onAnswer: onAnswer),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  static String _prettyConcept(String conceptId) => conceptId
      .split('_')
      .where((String w) => w.isNotEmpty)
      .map((String w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String _difficultyText(AppLocalizations l10n, Difficulty d) {
    switch (d) {
      case Difficulty.kolay:
        return l10n.difficultyEasy;
      case Difficulty.orta:
        return l10n.difficultyMedium;
      case Difficulty.zor:
        return l10n.difficultyHard;
    }
  }
}

class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${l10n.correctAnswerLabel}: ${question.correctAnswer}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (question.solutionSteps.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(l10n.solutionLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            for (int i = 0; i < question.solutionSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${i + 1}. ',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        question.solutionSteps[i],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({required this.onAnswer});

  final void Function(ReviewGrade grade) onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            onPressed: () => onAnswer(ReviewGrade.iyi),
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.answeredCorrect),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(color: theme.colorScheme.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => onAnswer(ReviewGrade.bilemedim),
            icon: const Icon(Icons.close_rounded),
            label: Text(l10n.answeredWrong),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_yks_coach/core/localization/gen/app_localizations.dart';
import 'package:ai_yks_coach/features/spaced_repetition/presentation/review_session_controller.dart';
import 'package:ai_yks_coach/features/spaced_repetition/presentation/widgets/question_card.dart';
import 'package:ai_yks_coach/features/spaced_repetition/presentation/widgets/stats_header.dart';

/// "Bugünün Tekrarları" ana ekranı.
///
/// Tekrar zamanı gelen soruları listeler ve tek tek çözdürür. Şu an mock veri
/// ile çalışır; veri katmanı (drift/Supabase) devreye alındığında yalnızca
/// repository değişir, bu ekran aynı kalır.
class TodayReviewsScreen extends ConsumerWidget {
  const TodayReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ReviewSessionState state = ref.watch(reviewSessionControllerProvider);
    final ReviewSessionController controller =
        ref.read(reviewSessionControllerProvider.notifier);

    final Widget body;
    if (state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.isEmpty) {
      body = _EmptyView(l10n: l10n);
    } else if (state.isComplete) {
      body = _CompleteView(
        l10n: l10n,
        state: state,
        onRestart: controller.restart,
      );
    } else {
      body = _SessionView(l10n: l10n, state: state, controller: controller);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.todaysReviewsTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({
    required this.l10n,
    required this.state,
    required this.controller,
  });

  final AppLocalizations l10n;
  final ReviewSessionState state;
  final ReviewSessionController controller;

  @override
  Widget build(BuildContext context) {
    final item = state.current!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          StatsHeader(hearts: state.hearts, xp: state.xp, streak: state.streak),
          const SizedBox(height: 16),
          _ProgressRow(l10n: l10n, state: state),
          const SizedBox(height: 16),
          Expanded(
            child: QuestionCard(
              key: ValueKey<String>(item.question.id),
              item: item,
              revealed: state.answerRevealed,
              onReveal: controller.revealAnswer,
              onAnswer: controller.answer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.l10n, required this.state});

  final AppLocalizations l10n;
  final ReviewSessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.reviewsDueSubtitle(state.total),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              '${state.answeredCount}/${state.total}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: state.progress, minHeight: 8),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.emoji_events_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              l10n.emptyReviewsTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.emptyReviewsBody,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteView extends StatelessWidget {
  const _CompleteView({
    required this.l10n,
    required this.state,
    required this.onRestart,
  });

  final AppLocalizations l10n;
  final ReviewSessionState state;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_outline_rounded,
                size: 80, color: Colors.green.shade600),
            const SizedBox(height: 20),
            Text(
              l10n.sessionCompleteTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.sessionCompleteBody(state.correctCount, state.total),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            StatsHeader(hearts: state.hearts, xp: state.xp, streak: state.streak),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.restartSession),
            ),
          ],
        ),
      ),
    );
  }
}

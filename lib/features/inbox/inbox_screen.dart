import 'package:flutter/material.dart';

import '../../data/friend_repository.dart';
import '../../data/question_send_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/received_question.dart';
import '../../models/report_reason.dart';
import '../../services/sound_service.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/mistake_photo.dart';
import '../../widgets/user_avatar.dart';

/// 3n — Gelen kutusu.
///
/// Her kartta üç eylem: **Çöz · Sil · Bildir**. Üçünün de sunucuda karşılığı
/// var — "Sil" için 0051 göçü yazıldı (`dismiss_received_question`), çünkü
/// yalnızca istemcide gizlemek uygulamayı yeniden açtığında sorunun geri
/// gelmesi demekti.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<ReceivedQuestion> _items = <ReceivedQuestion>[];
  bool _loading = true;
  bool _failed = false;

  /// İşlem sürerken kilitlenen gönderimler.
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
    super.dispose();
  }

  void _onRefresh() {
    if (mounted && !_loading) _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final List<ReceivedQuestion> items =
          await questionSendRepository.received();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('gelen kutusu yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _dismiss(ReceivedQuestion q) async {
    final L10n l = L10n.of(context);
    if (_busy.contains(q.sendId)) return;
    sound.tap();
    setState(() => _busy.add(q.sendId));
    try {
      await questionSendRepository.dismissReceived(q.sendId);
      if (!mounted) return;
      setState(() => _items = _items
          .where((ReceivedQuestion e) => e.sendId != q.sendId)
          .toList());
      _snack(l.inboxDeleted);
    } catch (e) {
      debugPrint('soru kaldırılamadı: $e');
      // Yerel listeden ÇIKARMIYORUZ: sunucuda kalmışsa kullanıcı silindiğini
      // sanıp bir daha açtığında geri geldiğini görürdü.
      if (mounted) _snack(l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy.remove(q.sendId));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        title: Text(l.inboxTitle, style: t.section),
      ),
      body: SafeArea(child: _body(context, l)),
    );
  }

  Widget _body(BuildContext context, L10n l) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            message: l.inboxLoadFailed,
            action: KimoButton(
              label: l.actionRetry,
              expand: false,
              onPressed: _load,
            ),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            illustration: const Kimo(size: 110),
            message: l.inboxEmpty,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Gap.screen, Gap.sm, Gap.screen, Gap.section),
        children: <Widget>[
          for (final ReceivedQuestion q in _items) ...<Widget>[
            _InboxCard(
              question: q,
              busy: _busy.contains(q.sendId),
              onSolved: _load,
              onDismiss: () => _dismiss(q),
              onReported: _load,
            ),
            const SizedBox(height: Gap.md),
          ],
        ],
      ),
    );
  }
}

/// Tek gelen soru kartı: fotoğraf, gönderen, üç eylem ve çözüm şıkları.
class _InboxCard extends StatefulWidget {
  const _InboxCard({
    required this.question,
    required this.busy,
    required this.onSolved,
    required this.onDismiss,
    required this.onReported,
  });

  final ReceivedQuestion question;
  final bool busy;
  final Future<void> Function() onSolved;
  final VoidCallback onDismiss;
  final Future<void> Function() onReported;

  @override
  State<_InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends State<_InboxCard> {
  final KimoController _kimo = KimoController();

  bool _open = false;
  bool _answering = false;
  AnswerResult? _result;

  @override
  void dispose() {
    _kimo.dispose();
    super.dispose();
  }

  Future<void> _answer(int index) async {
    if (_answering || _result != null) return;
    setState(() => _answering = true);
    try {
      final AnswerResult res = await questionSendRepository.answerSentQuestion(
        widget.question.sendId,
        index,
      );
      if (!mounted) return;
      if (res.queued) {
        // Çevrimdışı: doğruluğu SUNUCU belirlediği için sonucu gösteremiyoruz.
        // Uydurmak yerine kuyruğa alındığını söylüyoruz.
        setState(() => _answering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).practiceQueuedCount(1))),
        );
        return;
      }
      gameProgress.applyServerTotals(res.totals);
      _kimo.trigger(res.correct ? KimoReaction.correct : KimoReaction.wrong);
      if (res.correct) {
        sound.correct();
      } else {
        sound.wrong();
      }
      setState(() {
        _result = res;
        _answering = false;
      });
      await widget.onSolved();
    } catch (e) {
      debugPrint('cevap gönderilemedi: $e');
      if (!mounted) return;
      setState(() => _answering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).errorGeneric)),
      );
    }
  }

  Future<void> _report() async {
    sound.tap();
    final bool? done = await showReportSheet(context, widget.question);
    if (done == true) await widget.onReported();
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final ReceivedQuestion q = widget.question;
    final AnswerResult? res = _result;

    return KimoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Radii.card),
            ),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: MistakePhoto(path: q.photoPath, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UserAvatar(mascot: q.senderMascot, size: 32),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l.inboxFrom(q.senderNickname),
                            overflow: TextOverflow.ellipsis,
                            style: t.label,
                          ),
                          Text(
                            '${q.subject} · ${q.concept}',
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    if (q.solved)
                      StatusBadge(
                        label: l.inboxSolvedAlready,
                        tone: BadgeTone.neutral,
                      ),
                  ],
                ),
                if (q.note != null && q.note!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Gap.sm),
                  Text(q.note!, style: t.caption),
                ],
                const SizedBox(height: Gap.md),

                if (res != null || (q.solved && q.correctIndex != null))
                  _resultRow(context, l, res, q)
                else if (_open)
                  _options(context, q)
                else
                  _actions(context, l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, L10n l) {
    return Row(
      children: <Widget>[
        Expanded(
          child: KimoButton(
            label: l.inboxSolve,
            minHeight: Sizes.rowMin,
            onPressed: widget.question.solved
                ? null
                : () {
                    sound.tap();
                    setState(() => _open = true);
                  },
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: KimoButton(
            label: l.inboxDelete,
            kind: KimoButtonKind.tertiary,
            minHeight: Sizes.rowMin,
            onPressed: widget.busy ? null : widget.onDismiss,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: KimoButton(
            label: l.inboxReport,
            kind: KimoButtonKind.tertiary,
            minHeight: Sizes.rowMin,
            onPressed: widget.busy ? null : _report,
          ),
        ),
      ],
    );
  }

  Widget _options(BuildContext context, ReceivedQuestion q) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Row(
      children: <Widget>[
        for (int i = 0; i < q.options.length; i++) ...<Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _answering ? null : () => _answer(i),
              child: Container(
                height: Sizes.rowMin,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.sunken,
                  borderRadius: Radii.all(Radii.pill),
                ),
                child: Text(
                  q.options[i].label.isNotEmpty
                      ? q.options[i].label
                      : String.fromCharCode(65 + i),
                  style: t.numberMedium,
                ),
              ),
            ),
          ),
          if (i != q.options.length - 1) const SizedBox(width: Gap.sm),
        ],
      ],
    );
  }

  Widget _resultRow(
    BuildContext context,
    L10n l,
    AnswerResult? res,
    ReceivedQuestion q,
  ) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool correct = res?.correct ?? q.correct ?? false;
    final int? idx = res?.correctIndex ?? q.correctIndex;
    final String label = (idx != null && idx < q.options.length)
        ? q.options[idx].label
        : '—';
    return Row(
      children: <Widget>[
        Kimo(size: 40, controller: _kimo),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Text(
            correct ? l.inboxCorrect : l.inboxWrong(label),
            style: t.bodyStrong.copyWith(
              color: correct ? c.mintText : c.honeyText,
            ),
          ),
        ),
        // Çarpan yalnızca sunucu gerçekten uyguladıysa.
        if ((res?.multiplier ?? 1) > 1)
          StatusBadge(
            label: l.practiceCombo(res!.multiplier),
            tone: BadgeTone.pending,
          ),
      ],
    );
  }
}

/// Şikâyet sayfası. Tasarımdaki beş sebep + isteğe bağlı not + "engelle" kutusu.
///
/// Şikâyet ve engelleme TEK çağrıda gidiyor (`report_received_question`): iki
/// ayrı istek olsaydı ikincisi düştüğünde kullanıcı engellediğini sanıp
/// engellememiş olurdu.
Future<bool?> showReportSheet(BuildContext context, ReceivedQuestion q) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => _ReportSheet(question: q),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.question});

  final ReceivedQuestion question;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _note = TextEditingController();
  ReportReason? _reason;
  bool _block = false;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ReportReason? reason = _reason;
    if (reason == null || _sending) return;
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await friendRepository.reportReceived(
        sendId: widget.question.sendId,
        reason: reason,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        block: _block,
      );
      nav.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l.inboxReportSent)));
    } catch (e) {
      debugPrint('şikâyet gönderilemedi: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(l.inboxReportFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.screen,
        Gap.screen,
        Gap.screen,
        Gap.screen + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.inboxReportTitle, style: t.section),
            const SizedBox(height: Gap.md),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (ReportReason? v) => setState(() => _reason = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final ReportReason r in ReportReason.inbox)
                    RadioListTile<ReportReason>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label, style: t.body),
                      subtitle: Text(
                        r.hint,
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 300,
              style: t.body,
              decoration: InputDecoration(
                hintText: l.inboxReportNoteHint,
                filled: true,
                fillColor: c.sunken,
                border: OutlineInputBorder(
                  borderRadius: Radii.all(Radii.tile),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            CheckboxListTile(
              value: _block,
              onChanged: (bool? v) => setState(() => _block = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.inboxReportBlockAlso, style: t.body),
            ),
            const SizedBox(height: Gap.md),
            KimoButton(
              label: l.inboxReportSend,
              icon: const KimoIcon(KimoIcons.flag, size: 18),
              onPressed: (_reason == null || _sending) ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

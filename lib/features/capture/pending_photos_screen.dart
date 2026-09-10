import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/photo_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import 'confirm_screen.dart';

/// Bekleyen fotoğraflar — çevrimdışı kuyruğun kullanıcıya görünen yüzü.
///
/// Bu depoda SESSİZ KUYRUK KABUL EDİLMİYOR: cevap kuyruğunun da bir şeridi ve
/// bir sayacı var (`practice_screen`). Fotoğraf kuyruğu daha da görünür olmak
/// zorunda, çünkü kayıtların bir kısmı kullanıcı eylemi bekliyor — doğru şık
/// işaretlenmeden soru kaydedilemiyor (§5 kuralı).
class PendingPhotosScreen extends StatefulWidget {
  const PendingPhotosScreen({super.key});

  @override
  State<PendingPhotosScreen> createState() => _PendingPhotosScreenState();
}

class _PendingPhotosScreenState extends State<PendingPhotosScreen> {
  List<PendingPhoto> _items = <PendingPhoto>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final List<PendingPhoto> items = await photoQueue.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _complete(PendingPhoto p) async {
    sound.tap();
    final Uint8List? bytes = await photoQueue.bytesOf(p.id);
    final Map<String, dynamic>? entry = await photoQueue.entry(p.id);
    if (!mounted) return;
    if (bytes == null || entry == null) {
      // Dosya kaybolmuş: kaydı burada bırakmak "tamamla"nın hiçbir şey
      // yapmadığı bir düğme olmasına yol açardı.
      _snack(L10n.of(context).photoQueueMissingPhoto);
      await photoQueue.remove(p.id);
      await _load();
      return;
    }
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ConfirmMistakeScreen(
          imageBytes: bytes,
          analysis: null,
          queueEntryId: p.id,
          initialFields: entry,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) refreshBus.ping();
    await _load();
  }

  Future<void> _delete(PendingPhoto p) async {
    final L10n l = L10n.of(context);
    final bool ok = await _confirm(
      l.photoQueueDeleteTitle,
      l.photoQueueDeleteBody,
      l.photoQueueDeleteTitle,
    );
    if (!ok) return;
    await photoQueue.remove(p.id);
    await _load();
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
        padding: EdgeInsets.fromLTRB(Gap.screen, Gap.screen, Gap.screen,
            Gap.screen + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: t.section),
            const SizedBox(height: Gap.sm),
            Text(body, style: t.body),
            const SizedBox(height: Gap.lg),
            KimoButton(label: action, onPressed: () => Navigator.of(ctx).pop(true)),
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
        title: Text(l.photoQueueTitle, style: t.section),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: KimoIcon(KimoIcons.back, color: c.ink),
          tooltip: l.actionBack,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Gap.screen, Gap.md, Gap.screen, Gap.section),
                children: <Widget>[
                  if (_items.isEmpty)
                    EmptyState(message: l.photoQueueEmpty)
                  else
                    for (final PendingPhoto p in _items) _tile(context, l, p),
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, L10n l, PendingPhoto p) {
    final KimoTypography t = context.t;
    final KimoColors c = context.c;
    final (String label, BadgeTone tone) = switch (p) {
      PendingPhoto(gatedByAge: true) =>
        (l.photoQueueStateAgeGate, BadgeTone.pending),
      PendingPhoto(state: PhotoQueueState.needsAnalysis) =>
        (l.photoQueueStateAnalyzing, BadgeTone.pending),
      PendingPhoto(state: PhotoQueueState.needsUser) =>
        (l.photoQueueStateNeedsUser, BadgeTone.alert),
      PendingPhoto(state: PhotoQueueState.ready) =>
        (l.photoQueueStateReady, BadgeTone.neutral),
    };
    final String title = <String?>[p.subject, p.concept]
            .whereType<String>()
            .where((String s) => s.isNotEmpty)
            .join(' · ')
            .trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: KimoCard(
        padding: const EdgeInsets.all(Gap.md),
        radius: Radii.tile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title.isEmpty ? l.photoQueueTitle : title,
                    style: t.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                StatusBadge(label: label, tone: tone),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(_stamp(p.createdAt),
                style: t.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: Gap.md),
            Row(
              children: <Widget>[
                // Yaş kilidindeki kayıtta "Tamamla" YOK: analiz henüz
                // yapılamadı ve kullanıcıyı boş bir forma göndermek onu
                // AI'nın dolduracağı alanları elle yazmaya zorlardı.
                if (!p.gatedByAge)
                  Expanded(
                    child: KimoButton(
                      label: l.photoQueueComplete,
                      onPressed: () => _complete(p),
                    ),
                  ),
                if (!p.gatedByAge) const SizedBox(width: Gap.sm),
                Expanded(
                  child: KimoButton(
                    label: l.photoQueueDeleteTitle,
                    kind: KimoButtonKind.tertiary,
                    onPressed: () => _delete(p),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _stamp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}'
      ' ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Kuyruk dolduğunda gösterilen sayfa — ÇIKIŞ YOLUYLA birlikte.
///
/// Yalnız "sıra dolu" demek kullanıcıyı sıkıştırırdı: nereye bakacağını,
/// neyi sileceğini bilmiyor. Birincil düğme doğrudan bekleyenler ekranına
/// götürüyor.
Future<void> showPhotoQueueFullSheet(BuildContext context) async {
  final KimoTypography t = context.t;
  final L10n l = L10n.of(context);
  final NavigatorState nav = Navigator.of(context);
  final bool? open = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.fromLTRB(Gap.screen, Gap.screen, Gap.screen,
          Gap.screen + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.photoQueueFullTitle, style: t.section),
          const SizedBox(height: Gap.sm),
          Text(l.photoQueueFullBody, style: t.body),
          const SizedBox(height: Gap.lg),
          KimoButton(
            label: l.photoQueueFullAction,
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
  if (open == true) {
    await nav.push<void>(
      MaterialPageRoute<void>(builder: (_) => const PendingPhotosScreen()),
    );
  }
}

/// [PhotoQueueAdd] sonucunu kullanıcıya anlatır. `ok` dışındaki her sonuç
/// görünür: sessiz başarısızlık, kuyruğun önlemek için var olduğu kaybın ta
/// kendisi olurdu.
Future<void> reportQueueAdd(
  BuildContext context,
  PhotoQueueAdd result, {
  String? okMessage,
}) async {
  final L10n l = L10n.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case PhotoQueueAdd.ok:
      if (okMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(okMessage)));
      }
    case PhotoQueueAdd.full:
      await showPhotoQueueFullSheet(context);
    case PhotoQueueAdd.noSession:
      messenger.showSnackBar(SnackBar(content: Text(l.photoQueueNoSession)));
    case PhotoQueueAdd.diskError:
      messenger.showSnackBar(SnackBar(content: Text(l.photoQueueDiskError)));
  }
}

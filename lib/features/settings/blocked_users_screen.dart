import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/friend_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';

/// Engellenen kişiler (A-8).
///
/// Kullanıcı Task 08'e kadar birini engelleyebiliyor ama engellediklerini
/// göremiyor ve engeli kaldıramıyordu — geri alınamayan tek yönlü bir karar.
/// Sunucu tarafı 0044'ten beri hazırdı (`unblock_user`, `blocks_delete_own`);
/// eksik olan yalnızca bu ekrandı.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<BlockedUser> _items = <BlockedUser>[];
  bool _loading = true;
  bool _failed = false;

  /// İşlemi süren kimlikler — çift dokunuş iki isteğe dönüşmesin
  /// (`friends_view`'deki `_busy` deseni).
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _failed = false);
    try {
      final List<BlockedUser> items = await friendRepository.blockedUsers();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('engel listesi okunamadı: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _unblock(BlockedUser u) async {
    final L10n l = L10n.of(context);
    final bool ok = await _confirm(
      l.blockedConfirmTitle,
      l.blockedConfirmBody(u.nickname),
      l.blockedUnblock,
    );
    if (!ok || !mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(u.id));
    try {
      await friendRepository.unblock(u.id);
      // Engel kalkınca arkadaş listesi ve gelen kutusu da değişebilir
      // (engellenen kişi yeniden görünür hâle geliyor).
      refreshBus.ping();
      messenger.showSnackBar(SnackBar(content: Text(l.blockedDone)));
      await _load();
    } catch (e) {
      debugPrint('engel kaldırılamadı: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.blockedFailed)));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
        title: Text(l.blockedTitle, style: t.section),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
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
                  if (_failed)
                    EmptyState(
                      message: l.errorGeneric,
                      action: KimoButton(
                        label: l.actionRetry,
                        expand: false,
                        onPressed: _load,
                      ),
                    )
                  else if (_items.isEmpty)
                    EmptyState(message: l.blockedEmpty)
                  else
                    for (final BlockedUser u in _items) _row(context, l, u),
                ],
              ),
            ),
    );
  }

  Widget _row(BuildContext context, L10n l, BlockedUser u) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool busy = _busy.contains(u.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: KimoCard(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.md),
        radius: Radii.tile,
        child: Row(
          children: <Widget>[
            UserAvatar(name: u.nickname, size: 36),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(u.nickname,
                      style: t.label, overflow: TextOverflow.ellipsis),
                  Text(
                    _stamp(u.blockedAt),
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            KimoButton(
              label: l.blockedUnblock,
              kind: KimoButtonKind.tertiary,
              expand: false,
              onPressed: busy
                  ? null
                  : () {
                      sound.tap();
                      unawaited(_unblock(u));
                    },
            ),
          ],
        ),
      ),
    );
  }

  static String _stamp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

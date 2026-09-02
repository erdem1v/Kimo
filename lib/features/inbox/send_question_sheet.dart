import 'package:flutter/material.dart';

import '../../data/question_send_repository.dart';
import '../../data/social_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/social.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';

/// Bir soruyu arkadaşlara gönderme sayfası.
///
/// Yalnızca kabul edilmiş arkadaşlar listeleniyor; kural veritabanında da
/// zorunlu (`sends_insert_friend` politikası), yani liste bir kolaylık,
/// koruma değil.
Future<void> showSendQuestionSheet(
  BuildContext context, {
  required String mistakeId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) =>
        _SendSheet(mistakeId: mistakeId, title: title),
  );
}

class _SendSheet extends StatefulWidget {
  const _SendSheet({required this.mistakeId, required this.title});

  final String mistakeId;
  final String title;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  final TextEditingController _note = TextEditingController();
  final Set<String> _selected = <String>{};

  List<PublicProfile> _friends = <PublicProfile>[];
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _failed = false);
    try {
      final List<Friendship> rels = await socialRepository.relations();
      final String me = socialRepository.currentUserId ?? '';
      final List<String> ids = rels
          .where((Friendship f) => f.accepted)
          .map((Friendship f) => f.otherId(me))
          .toList();
      final List<PublicProfile> people =
          await socialRepository.profilesByIds(ids);
      if (!mounted) return;
      setState(() {
        _friends = people;
        _loading = false;
      });
    } catch (e) {
      // Boş liste ile "yüklenemedi" ayrı iki durum: birincisinde kullanıcı
      // arkadaş eklemeli, ikincisinde yeniden denemeli.
      debugPrint('arkadaş listesi yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final SendResult result = await questionSendRepository.sendToFriends(
        mistakeId: widget.mistakeId,
        receiverIds: _selected.toList(),
        note: _note.text,
      );
      nav.pop();
      if (result.ok) sound.correct();
      // `SendResult.message` sunucunun gerçek sonucunu anlatıyor ("zaten
      // göndermiştin" dâhil); burada ezmiyoruz.
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      debugPrint('soru gönderilemedi: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(l.sendFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.lg,
          Gap.screen,
          Gap.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration:
                    BoxDecoration(color: c.border, borderRadius: Radii.all(2)),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text(l.sendTitle, style: t.section),
            const SizedBox(height: Gap.xxs),
            Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Gap.lg),
            Flexible(child: _body(context, l)),
            if (!_loading && !_failed && _friends.isNotEmpty) ...<Widget>[
              const SizedBox(height: Gap.md),
              TextField(
                controller: _note,
                maxLength: 200,
                style: t.body,
                decoration: InputDecoration(
                  hintText: l.sendNoteHint,
                  counterText: '',
                  filled: true,
                  fillColor: c.sunken,
                  border: OutlineInputBorder(
                    borderRadius: Radii.all(Radii.tile),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Text(
                l.sendSelected(_selected.length),
                style: t.caption.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Gap.sm),
              KimoButton(
                label: l.sendAction,
                icon: const KimoIcon(KimoIcons.play, size: 18),
                onPressed: (_selected.isEmpty || _sending) ? null : _send,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, L10n l) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Gap.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed) {
      return EmptyState(
        message: l.sendLoadFailed,
        action: KimoButton(
          label: l.actionRetry,
          expand: false,
          onPressed: _loadFriends,
        ),
      );
    }
    if (_friends.isEmpty) return EmptyState(message: l.sendNoFriends);

    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        for (final PublicProfile p in _friends) ...<Widget>[
          _friendRow(context, p),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }

  Widget _friendRow(BuildContext context, PublicProfile p) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool picked = _selected.contains(p.id);
    return KimoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.md, vertical: Gap.sm),
      radius: Radii.tile,
      elevated: false,
      color: picked ? c.actionTint : c.sunken,
      onTap: () {
        sound.tap();
        setState(() {
          if (picked) {
            _selected.remove(p.id);
          } else {
            _selected.add(p.id);
          }
        });
      },
      child: Row(
        children: <Widget>[
          UserAvatar(size: 36, mascot: p.mascot, avatarPath: p.avatarPath),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              p.nickname,
              overflow: TextOverflow.ellipsis,
              style: picked ? t.label.copyWith(color: c.actionText) : t.label,
            ),
          ),
          if (picked) KimoIcon(KimoIcons.check, size: 18, color: c.actionText),
        ],
      ),
    );
  }
}

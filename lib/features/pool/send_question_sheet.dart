import 'package:flutter/material.dart';

import '../../data/question_pool_repository.dart';
import '../../data/social_repository.dart';
import '../../models/social.dart';
import '../../services/sound_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';

/// Bir soruyu arkadaşlara gönderme alt sayfası. Yalnızca arkadaşlar listelenir
/// (gönderim kuralı veritabanında da zorunludur).
Future<void> showSendQuestionSheet(
  BuildContext context, {
  required String mistakeId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
  Set<String> _alreadySent = <String>{};
  bool _loading = true;
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
    try {
      final List<Friendship> rels = await socialRepository.relations();
      final String me = socialRepository.currentUserId ?? '';
      final List<String> ids = rels
          .where((Friendship f) => f.accepted)
          .map((Friendship f) => f.otherId(me))
          .toList();
      final List<PublicProfile> people = await socialRepository.profilesByIds(
        ids,
      );
      // Bu soruyu daha önce kime gönderdiysem işaretlensin; tekrar seçip
      // "gönderilemedi" hatası almasın.
      final Set<String> sent = await questionPoolRepository.alreadySentTo(
        widget.mistakeId,
      );
      if (!mounted) return;
      setState(() {
        _friends = people;
        _alreadySent = sent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    final SendResult result = await questionPoolRepository.sendToFriends(
      mistakeId: widget.mistakeId,
      receiverIds: _selected.toList(),
      note: _note.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (result.ok) sound.correct();
    // "Zaten göndermiştin" bir hata değil: kırmızı yerine nötr göster.
    final bool failed = !result.ok && result.error != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok
            ? AppColors.green
            : (failed ? AppColors.red : AppColors.ink),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arkadaşına gönder',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.inkLight, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_friends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Henüz arkadaşın yok.\nSosyal sekmesinden arkadaş ekleyebilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkLight),
                  ),
                ),
              )
            else ...<Widget>[
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final PublicProfile p in _friends) _friendTile(p),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: 'Not ekle (isteğe bağlı)',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF4F4F4),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GameButton(
                label: _sending
                    ? 'Gönderiliyor...'
                    : (_selected.isEmpty
                          ? 'GÖNDER'
                          : 'GÖNDER (${_selected.length})'),
                enabled: _selected.isNotEmpty && !_sending,
                onPressed: _send,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _friendTile(PublicProfile p) {
    final bool selected = _selected.contains(p.id);
    final bool done = _alreadySent.contains(p.id);
    return GestureDetector(
      onTap: done
          ? null
          : () {
              sound.tap();
              setState(() {
                selected ? _selected.remove(p.id) : _selected.add(p.id);
              });
            },
      child: Opacity(
        opacity: done ? 0.5 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.green.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.green : AppColors.line,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (p.mascot?.color ?? AppColors.purple).withValues(
                    alpha: 0.16,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  p.mascot?.emoji ?? '🐻',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (done)
                const Text(
                  'gönderildi',
                  style: TextStyle(
                    color: AppColors.inkLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.green : AppColors.line,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

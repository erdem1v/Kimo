/// ARKADAŞ-ÖNCE gönderme akışı (Tur 7 · n5).
///
/// Depoda bugüne kadar tek bir yol vardı ve o SORU-ÖNCE idi: Hatalarım
/// listesindeki satırın "gönder" ikonu → alıcı seç. Tasarımın istediği akış
/// tersi: arkadaş satırından başla, sonra soruyu seç.
///
/// AKIŞ SIRASI GİRİŞ NOKTASINI TAKİP EDİYOR ve kullanıcıya iki kez seçim
/// yaptırılmıyor:
///   * arkadaş satırından gelindiyse ALICI sabit → içerik seç (bu dosya),
///   * Hatalarım satırından gelindiyse İÇERİK sabit → arkadaş seç
///     (`send_question_sheet.dart`, değişmedi).
/// Her yolda en fazla iki ekran.
library;

import 'package:flutter/material.dart';

import '../../data/mistake_repository.dart';
import '../../data/question_send_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/mistake_photo.dart';
import '../../widgets/mistake_style.dart';
import '../capture/capture_screen.dart';

/// Arkadaş satırından açılan üç seçenekli sayfa.
///
/// "KAPAT" AYRI BİR SATIR, bilinçli: Apple HIG action sheet için iptali
/// ZORUNLU kılıyor (en fazla 3 ek seçenek + Cancel). Material 3'te kapanma
/// scrim/geri tuşu/sürükleme ile de mümkün ama WCAG 2.5.1/2.5.7 dokunulabilir
/// bir kapatma hedefi istiyor — ayrı satır ikisini birden karşılıyor ve tek
/// widget iki platformda aynı kalıyor.
Future<void> showSendEntrySheet(
  BuildContext context, {
  required String friendId,
  required String friendName,
}) async {
  final int total = await _archiveCount();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => SendEntrySheetBody(
      friendId: friendId,
      friendName: friendName,
      archiveCount: total,
    ),
  );
}

/// Arşiv sayısı yalnızca alt metin için: `totalCount()` satır indirmiyor
/// (`head: true`), yani sayfayı açmak listeyi çekmiyor.
Future<int> _archiveCount() async {
  try {
    return await mistakeRepository.totalCount();
  } catch (_) {
    return 0;
  }
}

/// Üç seçenekli sayfanın gövdesi.
///
/// `_`siz: widget testi bunu doğrudan kurabiliyor. Sayfayı açan
/// [showSendEntrySheet] arşiv sayısını okuyor ve o, Supabase gerektiriyor —
/// gövdeyi ayırmak testi ağa bağlamıyor.
@visibleForTesting
class SendEntrySheetBody extends StatelessWidget {
  const SendEntrySheetBody({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.archiveCount,
  });

  final String friendId;
  final String friendName;
  final int archiveCount;

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final KimoTypography t = context.t;
    final KimoColors c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.screen,
        Gap.screen,
        Gap.screen,
        Gap.screen + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.sendEntryTitle(friendName), style: t.section),
          const SizedBox(height: Gap.xs),
          Text(l.sendEntryBody, style: t.caption),
          const SizedBox(height: Gap.lg),
          _Option(
            icon: KimoIcons.notebook,
            label: l.sendEntryFromArchive,
            hint: l.sendEntryFromArchiveHint(archiveCount),
            onTap: () {
              sound.tap();
              Navigator.of(context).pop();
              Navigator.of(context).push<void>(MaterialPageRoute<void>(
                builder: (_) => SendArchiveScreen(
                  friendId: friendId,
                  friendName: friendName,
                ),
              ));
            },
          ),
          const SizedBox(height: Gap.sm),
          _Option(
            icon: KimoIcons.camera,
            label: l.sendEntryNewPhoto,
            hint: l.sendEntryNewPhotoHint,
            onTap: () {
              sound.tap();
              Navigator.of(context).pop();
              // Çekim akışı zaten onay → kaydet ile bitiyor; tek eklenen
              // şey GÖNDERME NİYETİ. Yeni ekran yok.
              Navigator.of(context).push<void>(MaterialPageRoute<void>(
                builder: (_) => CaptureScreen(
                  sendToFriendId: friendId,
                  sendToFriendName: friendName,
                ),
              ));
            },
          ),
          const SizedBox(height: Gap.md),
          KimoButton(
            label: l.actionClose,
            kind: KimoButtonKind.tertiary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(height: Gap.xs, child: ColoredBox(color: c.card)),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final KimoIconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      radius: Radii.tile,
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.md),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.actionTint,
              borderRadius: Radii.all(Radii.chip),
            ),
            child: KimoIcon(icon, size: 20, color: c.actionText),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: t.bodyStrong),
                Text(hint, style: t.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          KimoIcon(KimoIcons.forward, size: 18, color: c.inkMuted),
        ],
      ),
    );
  }
}

/// Arşivden soru seçme ekranı (Tur 7 · n5).
///
/// %90 YENİDEN KULLANIM, bilinçli: liste `mistakeRepository.fetch()` (en yeni
/// 500, zaten var), ders çipleri Hatalarım ekranının şeridi, sıralama
/// `created_at desc` ile zaten "son eklenenler". YENİ SUNUCU SORGUSU YOK.
///
/// GÖNDERİLEMEYENLER GİZLENMİYOR: soluk gösterilip sebebi yazılıyor. Gizlemek,
/// kullanıcının sorusunun neden listede olmadığını anlamamasına yol açardı —
/// ve sebep genelde geçici (fotoğraf inceleniyor).
class SendArchiveScreen extends StatefulWidget {
  const SendArchiveScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  final String friendId;
  final String friendName;

  @override
  State<SendArchiveScreen> createState() => _SendArchiveScreenState();
}

class _SendArchiveScreenState extends State<SendArchiveScreen> {
  final TextEditingController _query = TextEditingController();

  List<MistakeEntry> _items = <MistakeEntry>[];
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  bool _hideUnsendable = false;
  String? _subject;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final List<MistakeEntry> rows = await mistakeRepository.fetch();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      debugPrint('arşiv yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// Gönderilebilirlik ölçütü `received_questions` görünümünün ÜÇ ZORUNLU
  /// ALANIYLA aynı: fotoğraf, şıklar ve doğru şık. Görünüm bunları şart
  /// koştuğu için eksik bir soru gönderilse de alıcıda HİÇ görünmezdi.
  static bool _sendable(MistakeEntry e) =>
      e.id != null &&
      e.photoPath != null &&
      (e.options?.isNotEmpty ?? false) &&
      e.correctIndex != null;

  List<String> get _subjects {
    final Set<String> out = <String>{for (final MistakeEntry e in _items) e.subject};
    final List<String> list = out.toList()..sort();
    return list;
  }

  List<MistakeEntry> get _filtered {
    final String q = _query.text.trim().toLowerCase();
    return _items.where((MistakeEntry e) {
      if (_subject != null && e.subject != _subject) return false;
      if (_hideUnsendable && !_sendable(e)) return false;
      if (q.isEmpty) return true;
      return e.concept.toLowerCase().contains(q) ||
          e.subject.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _send() async {
    final String? id = _selectedId;
    if (id == null || _sending) return;
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final SendResult res = await questionSendRepository.sendToFriends(
        mistakeId: id,
        receiverIds: <String>[widget.friendId],
      );
      if (res.ok) sound.correct();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(res.message)));
      refreshBus.ping();
    } catch (e) {
      debugPrint('soru gönderilemedi: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(l.sendFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final List<MistakeEntry> rows = _filtered;

    return Scaffold(
      appBar: AppBar(title: Text(l.sendArchiveTitle(widget.friendName))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.screen),
                    child: EmptyState(
                      message: l.mistakesLoadFailed,
                      action: KimoButton(
                        label: l.actionRetry,
                        expand: false,
                        onPressed: _load,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.screen, Gap.md, Gap.screen, Gap.sm),
                      child: TextField(
                        controller: _query,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l.sendArchiveSearchHint,
                          filled: true,
                          fillColor: c.sunken,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(Gap.md),
                            child: KimoIcon(KimoIcons.notebook,
                                size: 18, color: c.inkMuted),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: Radii.all(Radii.pill),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    _chips(context, l),
                    Expanded(child: _list(context, l, rows, t, c)),
                    _footer(context, l, t, c),
                  ],
                ),
    );
  }

  Widget _chips(BuildContext context, L10n l) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      child: Row(
        children: <Widget>[
          KimoChip(
            label: l.mistakesFilterAll,
            selected: _subject == null,
            onTap: () {
              sound.tap();
              setState(() => _subject = null);
            },
          ),
          for (final String s in _subjects) ...<Widget>[
            const SizedBox(width: Gap.sm),
            KimoChip(
              label: s,
              selected: _subject == s,
              onTap: () {
                sound.tap();
                setState(() => _subject = s);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(BuildContext context, L10n l, List<MistakeEntry> rows,
      KimoTypography t, KimoColors c) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            message: _items.isEmpty ? l.sendArchiveEmpty : l.sendArchiveNoMatch,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.md, Gap.screen, Gap.md),
      children: <Widget>[
        SectionHeader(title: l.sendArchiveRecent),
        const SizedBox(height: Gap.sm),
        for (final MistakeEntry e in rows) ...<Widget>[
          _row(context, l, e, t, c),
          const SizedBox(height: Gap.sm),
        ],
        if (_items.length >= MistakeRepository.archiveLimit)
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(
              l.sendArchiveTruncated(MistakeRepository.archiveLimit),
              style: t.caption.copyWith(color: c.inkMuted),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, L10n l, MistakeEntry e, KimoTypography t,
      KimoColors c) {
    final bool can = _sendable(e);
    final bool selected = can && e.id == _selectedId;
    // GEÇİCİ sebep soluk + açıklama; kalıcı sebep de aynı yolla anlatılıyor
    // çünkü ikisinin de çıkışı kullanıcının elinde (şıkları girmek / taramanın
    // bitmesi). Gizlemek "sorum nerede?" sorusunu üretirdi.
    final String? why = can
        ? null
        : (e.photoPath == null || (e.options?.isEmpty ?? true))
            ? l.sendUnsendableOptions
            : l.sendUnsendableScan;
    return Opacity(
      opacity: can ? 1 : 0.45,
      child: KimoCard(
        radius: Radii.tile,
        color: selected ? c.actionTint : c.card,
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.md),
        onTap: can
            ? () {
                sound.tap();
                setState(() => _selectedId = e.id);
              }
            : null,
        child: Row(
          children: <Widget>[
            if (e.photoPath != null)
              ClipRRect(
                borderRadius: Radii.all(Radii.chip),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: MistakePhoto(path: e.photoPath!, fit: BoxFit.cover),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.sunken,
                  borderRadius: Radii.all(Radii.chip),
                ),
                child: KimoIcon(KimoIcons.notebook,
                    size: 18, color: c.inkMuted),
              ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(e.concept,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.label),
                  Text(
                    why ?? '${e.subject} · ${formatShortDate(e.date)}',
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            if (selected)
              KimoIcon(KimoIcons.check, size: 18, color: c.actionText),
          ],
        ),
      ),
    );
  }

  Widget _footer(
      BuildContext context, L10n l, KimoTypography t, KimoColors c) {
    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(
        Gap.screen,
        Gap.md,
        Gap.screen,
        Gap.md + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                // KAPALI DÜĞMENİN GERÇEK KOŞULU (Task 15 · D5). Düğme
                // `_selectedId == null` iken kapalı, ama yanındaki tek metin
                // notların gönderilmediğini anlatıyordu — yani başka bir
                // şeyi. Seçim yapılana kadar önce ENGELİ söylüyoruz.
                child: Text(
                  _selectedId == null
                      ? l.sendArchiveNeedPick
                      : l.sendArchiveNote(widget.friendName),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ),
              const SizedBox(width: Gap.sm),
              KimoChip(
                label: l.sendUnsendableHideToggle,
                selected: _hideUnsendable,
                onTap: () {
                  sound.tap();
                  setState(() => _hideUnsendable = !_hideUnsendable);
                },
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          KimoButton(
            label: l.sendArchiveAction,
            busy: _sending,
            onPressed: (_selectedId == null || _sending) ? null : _send,
          ),
        ],
      ),
    );
  }
}

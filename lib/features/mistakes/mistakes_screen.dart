import 'package:flutter/material.dart';

import '../../data/mistake_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/mistake_store.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/mistake_photo.dart';
import '../../widgets/mistake_style.dart';
import '../capture/capture_screen.dart';
import '../inbox/send_question_sheet.dart';
import 'mistake_stats.dart';

/// 3j — "Hatalarım".
///
/// Üç kat: (1) hâkim/öğreniyorum/bugün halkası, (2) İnatçılar, (3) son 7 gün
/// ve arşiv listesi.
///
/// **Hiçbiri yeni bir sunucu sayacı gerektirmiyor.** Halka `mastered`'dan,
/// İnatçılar `is_leech`/`lapses`'ten, son 7 gün `created_at`'ten türüyor —
/// üçü de Task 01'den beri yazılan alanlar. Task'ın kuralı buydu: "önce
/// mevcut veriden türetilebilir mi diye sor".
class MistakesScreen extends StatefulWidget {
  const MistakesScreen({super.key});

  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
  final bool _remote = SupabaseConfig.isConfigured;

  List<MistakeEntry> _items = <MistakeEntry>[];
  bool _loading = false;
  bool _failed = false;

  /// Seçili ders filtresi; `null` = tümü.
  String? _subject;

  @override
  void initState() {
    super.initState();
    if (_remote) {
      _load();
      refreshBus.addListener(_onRefresh);
    } else {
      _items = mistakeStore.items;
    }
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
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final List<MistakeEntry> items = await mistakeRepository.fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('hatalar yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _capture() async {
    sound.tap();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CaptureScreen()),
    );
    if (!mounted) return;
    if (_remote) {
      await _load();
    } else {
      setState(() => _items = mistakeStore.items);
    }
  }

  List<MistakeEntry> get _filtered => _subject == null
      ? _items
      : _items.where((MistakeEntry e) => e.subject == _subject).toList();

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(bottom: false, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final L10n l = L10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
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
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: EmptyState(
            illustration: const Kimo(size: 120),
            message: '${l.mistakesEmptyTitle}\n${l.mistakesEmptyBody}',
            action: KimoButton(
              label: l.todayEmptyAction,
              expand: false,
              onPressed: _capture,
            ),
          ),
        ),
      );
    }

    final MistakeStats stats = MistakeStats.from(_items);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Gap.screen, Gap.sm, Gap.screen, Gap.section),
        children: <Widget>[
          Text(l.mistakesTitle, style: context.t.title),
          const SizedBox(height: Gap.lg),
          _ringCard(context, l, stats),
          if (stats.leeches.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.md),
            _leechCard(context, l, stats),
          ],
          const SizedBox(height: Gap.md),
          _weekCard(context, l, stats),
          const SizedBox(height: Gap.xl),
          _subjectFilter(context, l, stats),
          const SizedBox(height: Gap.md),
          for (final MistakeEntry e in _filtered) ...<Widget>[
            _MistakeTile(entry: e),
            const SizedBox(height: Gap.sm),
          ],
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.lg),
              child: EmptyState(message: l.mistakesNoMatch),
            ),
        ],
      ),
    );
  }

  /// Hâkim / öğreniyorum / bugün halkası.
  ///
  /// Tasarım burada bir donut grafik gösteriyor. `SegmentRing` dilimli bir
  /// halka çiziyor ve üç oranı ayrı ayrı gösteremiyor; onun yerine halka
  /// **hâkim oranını** taşıyor, üç sayı yanında okunuyor. Üç renkli bir dilim
  /// grafiği için ayrı bir boyayıcı gerekiyordu; okunurluk kazancı, üç sayıyı
  /// zaten yan yana yazan bu düzene göre ölçülebilir değildi.
  Widget _ringCard(BuildContext context, L10n l, MistakeStats s) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.all(Gap.screen),
      child: Row(
        children: <Widget>[
          SegmentRing(
            // Dilim sayısı arşiv boyutu DEĞİL, sabit 20: 200 soruluk bir
            // arşivde 200 dilim okunmaz bir yüzük olurdu. Halka oranı taşıyor,
            // kesin sayı ortadaki yüzde ve yandaki üç satırda.
            total: 20,
            filled: (s.masteredPercent / 5).round(),
            size: 92,
            filledColor: c.mint,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('${s.masteredPercent}%', style: t.numberMedium),
                Text(
                  l.mistakesMastered,
                  style: t.overline.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.mistakesTotal(s.total), style: t.section),
                const SizedBox(height: Gap.md),
                _legend(context, c.mint, l.mistakesMastered, s.mastered),
                const SizedBox(height: Gap.xs),
                _legend(context, c.action, l.mistakesLearning, s.learning),
                const SizedBox(height: Gap.xs),
                _legend(context, c.honey, l.mistakesDueToday, s.dueToday),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color dot, String label, int value) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(label, style: t.caption.copyWith(color: c.inkSecondary)),
        ),
        Text('$value', style: t.numberSmall),
      ],
    );
  }

  /// İnatçılar — `is_leech` VEYA `lapses >= 4`.
  ///
  /// Metin "en az dört kez" diyor çünkü `ReviewScheduler.leechThreshold = 4`.
  /// Mockup "en az üç kez" yazıyordu; koddaki eşik kazandı.
  Widget _leechCard(BuildContext context, L10n l, MistakeStats s) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      color: c.actionTint,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              KimoIcon(KimoIcons.flag, size: 20, color: c.actionText),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  l.mistakesLeechTitle,
                  style: t.bodyStrong.copyWith(color: c.actionText),
                ),
              ),
              StatusBadge(label: '${s.leeches.length}', tone: BadgeTone.alert),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(l.mistakesLeechBody, style: t.caption),
          const SizedBox(height: Gap.md),
          for (final MistakeEntry e in s.leeches.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${e.subject} · ${e.concept}',
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: c.ink),
                    ),
                  ),
                  Text(
                    l.mistakesLapses(e.lapses),
                    style: t.caption.copyWith(color: c.actionText),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Son 7 günün çubukları — `created_at` üzerinden.
  Widget _weekCard(BuildContext context, L10n l, MistakeStats s) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int peak = s.weekPeak;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(title: l.mistakesWeekTitle),
          const SizedBox(height: Gap.md),
          if (peak == 0)
            Text(l.mistakesWeekEmpty, style: t.caption.copyWith(color: c.inkMuted))
          else
            SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (int i = 0; i < s.week.length; i++) ...<Widget>[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Text('${s.week[i]}', style: t.overline),
                          const SizedBox(height: Gap.xxs),
                          Container(
                            height: 8 + 40 * (s.week[i] / peak),
                            decoration: BoxDecoration(
                              color: s.week[i] == 0 ? c.trackEmpty : c.action,
                              borderRadius: Radii.all(4),
                            ),
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            s.weekLabels[i],
                            style: t.overline.copyWith(color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    if (i != s.week.length - 1) const SizedBox(width: Gap.xs),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _subjectFilter(BuildContext context, L10n l, MistakeStats s) {
    return SizedBox(
      // Dokunma hedefi tabanı; çipin kendi dolgusu bundan küçük olsa da
      // satır kısalıp taşmasın.
      height: Sizes.iconTap,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          KimoChip(
            label: l.mistakesFilterAll,
            selected: _subject == null,
            onTap: () {
              sound.tap();
              setState(() => _subject = null);
            },
          ),
          for (final MapEntry<String, int> e in s.bySubject.entries) ...<Widget>[
            const SizedBox(width: Gap.sm),
            KimoChip(
              label: '${e.key} · ${e.value}',
              selected: _subject == e.key,
              onTap: () {
                sound.tap();
                setState(() => _subject = e.key);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Arşiv satırı.
class _MistakeTile extends StatelessWidget {
  const _MistakeTile({required this.entry});

  final MistakeEntry entry;

  bool get _sendable =>
      entry.id != null &&
      entry.photoPath != null &&
      entry.hasOptions &&
      entry.correctIndex != null;

  /// Küçük resim. Yerel baytlar `SizedPhoto` ile `cacheWidth`'e indiriliyor;
  /// depodaki fotoğraflar imzalı URL gerektirdiği için [MistakePhoto]'dan
  /// geçiyor (o da kendi içinde imzayı ve yeniden denemeyi yönetiyor).
  Widget _thumb(BuildContext context) {
    final KimoColors c = context.c;
    if (entry.imageBytes != null) {
      return SizedPhoto(
        image: MemoryImage(entry.imageBytes!),
        logicalWidth: 56,
        height: 56,
      );
    }
    if (entry.photoPath != null) {
      return MistakePhoto(path: entry.photoPath!, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: c.sunken,
      child: Center(
        child: KimoIcon(KimoIcons.notebook, size: 20, color: c.inkMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return KimoCard(
      padding: const EdgeInsets.all(Gap.md),
      radius: Radii.tile,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: Radii.all(Radii.chip),
            child: SizedBox(width: 56, height: 56, child: _thumb(context)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.concept,
                        overflow: TextOverflow.ellipsis,
                        style: t.label,
                      ),
                    ),
                    if (entry.mastered)
                      StatusBadge(
                        label: l.mistakesMastered,
                        tone: BadgeTone.mastered,
                      )
                    else if (entry.isLeech)
                      StatusBadge(
                        label: l.mistakeLeechBadge,
                        tone: BadgeTone.alert,
                      ),
                  ],
                ),
                const SizedBox(height: Gap.xxs),
                Text(
                  '${entry.subject} · ${formatShortDate(entry.date)}',
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
                if (entry.type != null) ...<Widget>[
                  const SizedBox(height: Gap.sm),
                  StatusBadge(
                    label: entry.type!.label,
                    tone: BadgeTone.neutral,
                  ),
                ],
              ],
            ),
          ),
          if (_sendable)
            IconButton(
              onPressed: () {
                sound.tap();
                showSendQuestionSheet(
                  context,
                  mistakeId: entry.id!,
                  title: '${entry.subject} · ${entry.concept}',
                );
              },
              icon: KimoIcon(KimoIcons.play, size: 18, color: c.inkMuted),
              tooltip: l.mistakesSend,
            ),
        ],
      ),
    );
  }
}

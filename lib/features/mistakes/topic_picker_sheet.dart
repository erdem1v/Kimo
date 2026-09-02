import 'package:flutter/material.dart';

import '../../data/yks_curriculum.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/mistake_style.dart';

/// Konu seçici. Konular yalnızca müfredat listesinden seçilebilir; serbest
/// metin girilemez. Aksi hâlde aynı konu farklı adlarla yazılır ve
/// istatistikler (ders dağılımı, ilerleme) eşleşmez.
Future<String?> showTopicPicker(
  BuildContext context, {
  required String curriculum,
  required String exam,
  required String subject,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => _TopicPicker(
      curriculum: curriculum,
      exam: exam,
      subject: subject,
      selected: selected,
    ),
  );
}

class _TopicPicker extends StatefulWidget {
  const _TopicPicker({
    required this.curriculum,
    required this.exam,
    required this.subject,
    this.selected,
  });

  final String curriculum;
  final String exam;
  final String subject;
  final String? selected;

  @override
  State<_TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends State<_TopicPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Unit> get _units =>
      YksCurriculum.forExam(widget.curriculum, widget.exam)[widget.subject] ??
      <Unit>[];

  /// Aramaya uyan konular, ünite başlıklarıyla birlikte.
  List<Unit> get _filtered {
    final String q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _units;
    final List<Unit> out = <Unit>[];
    for (final Unit u in _units) {
      // Parametre adı `t` DEĞİL: bu depoda `t` tipografi erişimcisi
      // (`context.t`) için ayrılmış ve gölgelemek okuyanı yanıltıyor.
      final List<String> hits = u.topics
          .where((String topic) => topic.toLowerCase().contains(q))
          .toList();
      if (hits.isNotEmpty) out.add(Unit(u.name, hits));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final Color color = subjectColor(widget.subject);
    final List<Unit> units = _filtered;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.screen, Gap.lg, Gap.screen,
            Gap.md + MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.border, borderRadius: Radii.all(2)),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 22,
                    decoration: BoxDecoration(
                        color: color, borderRadius: Radii.all(4)),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      widget.subject + ' · ' + widget.exam,
                      style: t.section,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xxs),
              Text(l.topicPickerTitle,
                  style: t.caption.copyWith(color: c.inkMuted)),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _search,
                style: t.body,
                decoration: InputDecoration(
                  hintText: l.topicPickerSearch,
                  prefixIcon:
                      KimoIcon(KimoIcons.bars, size: 18, color: c.inkMuted),
                  filled: true,
                  fillColor: c.sunken,
                  contentPadding: const EdgeInsets.symmetric(vertical: Gap.md),
                  border: OutlineInputBorder(
                    borderRadius: Radii.all(Radii.tile),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Expanded(
                child: units.isEmpty
                    ? Center(child: EmptyState(message: l.topicPickerNoMatch))
                    : ListView(
                        children: <Widget>[
                          for (final Unit u in units) ...<Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  2, Gap.md, 2, Gap.sm),
                              child: Text(u.name.toUpperCase(),
                                  style: t.overline.copyWith(color: color)),
                            ),
                            for (final String t in u.topics) _tile(t, color),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(String topic, Color color) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool isSelected = widget.selected == topic;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: KimoCard(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.md),
        radius: Radii.chip,
        elevated: false,
        color: isSelected ? c.actionTint : c.sunken,
        onTap: () {
          sound.tap();
          Navigator.of(context).pop(topic);
        },
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                topic,
                style: isSelected
                    ? t.label.copyWith(color: c.actionText)
                    : t.label,
              ),
            ),
            if (isSelected)
              KimoIcon(KimoIcons.check, size: 18, color: c.actionText),
          ],
        ),
      ),
    );
  }
}

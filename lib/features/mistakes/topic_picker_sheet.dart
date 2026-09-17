import 'package:flutter/material.dart';

import '../../data/curriculum_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/curriculum.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/mistake_style.dart';

/// Seçicinin sonucu: ders ve konu BİRLİKTE.
///
/// Task 09'a kadar seçici yalnızca konu döndürüyordu, ders dışarıdan
/// parametre olarak geliyordu. Arama artık tüm derslerde çalıştığı için
/// kullanıcı "atışlar" yazıp Fizik'i hiç seçmeden Fizik'in konusunu
/// bulabiliyor — dolayısıyla dersi de seçici belirliyor.
class TopicPick {
  const TopicPick(this.subject, this.topic);

  final String subject;
  final String topic;
}

/// Konu seçici.
///
/// Konular yalnızca müfredat ağacından seçilebilir; serbest metin girilemez.
/// Aksi hâlde aynı konu farklı adlarla yazılır ve istatistikler (ders
/// dağılımı, ilerleme) eşleşmez. Sunucu da 0071'den beri ağaç dışı konuyu
/// reddediyor, yani bu artık bir istemci nezaketi değil.
///
/// **ARAMA ÖNCE, MENÜ SONRA.** Onlarca ders ve yüzlerce konu var; iç içe menü
/// gezmek gerçek bir maliyet. Sorgu boşken bugünkü davranış korunuyor (seçili
/// dersin konuları ünite başlıklarıyla, ders seçili değilse ders listesi) —
/// yani gezinme yolu duruyor, sadece varsayılan değil.
Future<TopicPick?> showTopicPicker(
  BuildContext context, {
  required String curriculum,
  required String exam,
  String? subject,
  String? selected,
}) {
  return showModalBottomSheet<TopicPick>(
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
    this.subject,
    this.selected,
  });

  final String curriculum;
  final String exam;
  final String? subject;
  final String? selected;

  @override
  State<_TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends State<_TopicPicker> {
  final TextEditingController _search = TextEditingController();

  /// Gezinme yolunda seçili ders. Arama sonucundan seçim yapılırken
  /// kullanılmıyor — orada ders sonucun kendisinden geliyor.
  String? _subject;

  @override
  void initState() {
    super.initState();
    _subject = widget.subject;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  CurriculumTree get _tree => curriculumRepository.treeFor(widget.curriculum);

  String get _query => _search.text.trim();

  void _pick(String subject, String topic) {
    sound.tap();
    Navigator.of(context).pop(TopicPick(subject, topic));
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final bool searching = _query.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.screen, Gap.md, Gap.screen, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: Radii.all(Radii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Text(
                  _subject == null || searching
                      ? '${l.topicPickerTitle} · ${widget.exam}'
                      : '${_subject!} · ${widget.exam}',
                  style: t.section,
                ),
                const SizedBox(height: Gap.xs),
                Text(l.topicPickerHint, style: t.caption.copyWith(color: c.inkMuted)),
                const SizedBox(height: Gap.md),
                TextField(
                  controller: _search,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  style: t.body,
                  decoration: InputDecoration(
                    hintText: l.topicPickerSearch,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(Gap.sm),
                      child: KimoIcon(KimoIcons.bars, size: 18, color: c.inkMuted),
                    ),
                    suffixIcon: searching
                        ? IconButton(
                            onPressed: () => _search.clear(),
                            icon: KimoIcon(KimoIcons.close, size: 16, color: c.inkMuted),
                            tooltip: l.actionCancel,
                          )
                        : null,
                    filled: true,
                    fillColor: c.sunken,
                    border: OutlineInputBorder(
                      borderRadius: Radii.all(Radii.tile),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Expanded(
                  child: searching
                      ? _results(context, l)
                      : (_subject == null
                          ? _subjectList(context, l)
                          : _browse(context, l)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ arama
  Widget _results(BuildContext context, L10n l) {
    final List<TopicHit> hits =
        _tree.search(widget.exam, _query, preferSubject: _subject);
    if (hits.isEmpty) {
      return EmptyState(message: l.topicPickerNoMatch);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.section),
      children: <Widget>[
        for (final TopicHit h in hits) _hitTile(context, h),
      ],
    );
  }

  Widget _hitTile(BuildContext context, TopicHit h) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final Color color = subjectColor(h.subject);
    final bool isSelected = widget.selected == h.topic && _subject == h.subject;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: KimoCard(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
        radius: Radii.chip,
        elevated: false,
        color: isSelected ? c.actionTint : c.sunken,
        onTap: () => _pick(h.subject, h.topic),
        child: Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: Radii.all(Radii.pill),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    h.topic,
                    style: isSelected
                        ? t.label.copyWith(color: c.actionText)
                        : t.label,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Eşleşme bir ETİKETTEN geldiyse söyleniyor: kullanıcı hem
                    // neden bu sonucu gördüğünü hem de kaydedilecek adın farklı
                    // olduğunu şaşırmadan görüyor ("atışlar → Kuvvet ve Hareket").
                    h.matchedAlias == null
                        ? '${h.subject} · ${h.unit}'
                        : '${h.subject} · ${h.unit} · ${h.matchedAlias}',
                    style: t.caption.copyWith(color: c.inkMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              KimoIcon(KimoIcons.check, size: 18, color: c.actionText),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- gezinme
  Widget _subjectList(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    final List<String> subjects = _tree.subjectNames(widget.exam);
    if (subjects.isEmpty) return EmptyState(message: l.topicPickerNoTree);
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.section),
      children: <Widget>[
        for (final String s in subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: KimoCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.md),
              radius: Radii.chip,
              elevated: false,
              color: context.c.sunken,
              onTap: () {
                sound.tap();
                setState(() => _subject = s);
              },
              child: Row(
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: subjectColor(s),
                      borderRadius: Radii.all(Radii.pill),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(child: Text(s, style: t.label)),
                  KimoIcon(KimoIcons.forward, size: 16, color: context.c.border),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _browse(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    final String subject = _subject!;
    final Color color = subjectColor(subject);
    final List<UnitNode> units = _tree.unitsOf(widget.exam, subject);
    if (units.isEmpty) return EmptyState(message: l.topicPickerNoTree);
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.section),
      children: <Widget>[
        // Ders değiştirme yolu: aramaya geçmeden de dersler listesine dönülebilsin.
        Align(
          alignment: Alignment.centerLeft,
          child: KimoButton(
            label: l.topicPickerAllSubjects,
            kind: KimoButtonKind.tertiary,
            expand: false,
            onPressed: () {
              sound.tap();
              setState(() => _subject = null);
            },
          ),
        ),
        const SizedBox(height: Gap.sm),
        for (final UnitNode u in units) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.md, 0, Gap.sm),
            child: Text(u.unit.toUpperCase(),
                style: t.overline.copyWith(color: color)),
          ),
          for (final TopicNode topic in u.topics)
            _hitTile(
              context,
              TopicHit(subject: subject, unit: u.unit, topic: topic.topic),
            ),
        ],
      ],
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/mistake_repository.dart';
import '../../data/yks_curriculum.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/mistake_store.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../mistakes/topic_picker_sheet.dart';

/// 3f — Onayla ve kaydet.
///
/// Form doldurma değil ONAYLAMA: yapay zekâ sınav/ders/konuyu ve şıkları
/// doldurmuşsa kullanıcıya kalan iki dokunuş var (doğru şık + kaydet).
///
/// **AYNI EKRAN ELLE GİRİŞ FORMUDUR.** Günlük yapay zekâ hakkı bittiğinde,
/// çevrimdışıyken ve "fotoğrafsız devam et" yolunda da bu ekran açılıyor;
/// yalnızca alanlar boş geliyor. Task'ın istediği bu: "Elle giriş yolu zaten
/// çevrimdışı kayıt için de gerekiyor — aynı formu iki durum da kullansın."
class ConfirmMistakeScreen extends StatefulWidget {
  const ConfirmMistakeScreen({
    super.key,
    this.imageBytes,
    this.analysis,
  });

  /// Çekilen fotoğraf. `null` ise fotoğrafsız kayıt (elle giriş).
  final Uint8List? imageBytes;

  /// Yapay zekâ sonucu. `null` ise analiz hiç yapılmadı (çevrimdışı, iptal
  /// edildi ya da mock mod). `outOfCredit` ise hak bitti.
  final QuestionAnalysis? analysis;

  @override
  State<ConfirmMistakeScreen> createState() => _ConfirmMistakeScreenState();
}

class _ConfirmMistakeScreenState extends State<ConfirmMistakeScreen> {
  /// Şıksız bir soru kaydedilemiyor (tekrar ekranı doğru şıkkı biliyor olmalı),
  /// bu yüzden elle girişte beş harf hazır geliyor. Metinleri boş kalabilir:
  /// tasarımda pratik ekranı şıkların METNİNİ değil harflerini gösteriyor.
  static const List<String> _defaultLabels = <String>['A', 'B', 'C', 'D', 'E'];

  final TextEditingController _note = TextEditingController();
  final KimoController _kimo = KimoController();

  String _exam = 'TYT';
  String? _subject;
  String? _concept;
  final List<String> _extras = <String>[];
  MistakeType? _type;
  int? _correctIndex;
  List<String> _labels = <String>[];
  bool _saving = false;

  /// Ders satırı açık mı (yerinde açılan çip satırı — modal yok).
  bool _subjectOpen = false;

  @override
  void initState() {
    super.initState();
    final QuestionAnalysis? a = widget.analysis;
    if (a != null && a.ok) {
      _labels = <String>[for (final QuestionOption o in a.options) o.label];
      // Yapay zekânın önerisi YALNIZCA müfredatta karşılığı varsa kabul
      // ediliyor. Uydurma ders/konu arşivi ve istatistikleri kirletirdi.
      if (a.exam == 'TYT' || a.exam == 'AYT') _exam = a.exam!;
      if (a.subject != null && _subjects.contains(a.subject)) {
        _subject = a.subject;
        if (a.concept != null && _topicsOf(a.subject!).contains(a.concept)) {
          _concept = a.concept;
        }
      }
    }
    if (_labels.isEmpty) _labels = List<String>.from(_defaultLabels);
  }

  @override
  void dispose() {
    _note.dispose();
    _kimo.dispose();
    super.dispose();
  }

  bool get _manual => widget.analysis == null || !(widget.analysis?.ok ?? false);
  bool get _outOfCredit => widget.analysis?.outOfCredit ?? false;

  List<String> get _subjects =>
      YksCurriculum.forExam(userProfile.curriculum, _exam).keys.toList();

  List<String> _topicsOf(String subject) {
    final List<Unit> units =
        YksCurriculum.forExam(userProfile.curriculum, _exam)[subject] ??
            <Unit>[];
    return <String>[for (final Unit u in units) ...u.topics];
  }

  bool get _canSave =>
      !_saving && _subject != null && _concept != null && _correctIndex != null;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final List<QuestionOption> options = <QuestionOption>[
        for (final String label in _labels)
          QuestionOption(label: label, text: ''),
      ];

      if (SupabaseConfig.isConfigured) {
        await mistakeRepository.add(
          subject: _subject!,
          concept: _concept!,
          type: _type,
          note: _note.text.trim(),
          imageBytes: widget.imageBytes,
          options: options,
          correctIndex: _correctIndex,
          exam: _exam,
          // Soru havuzu bu sürümde yok (bkz. lib/_archive/README.md).
          isPublic: false,
          extraConcepts: _extras,
        );
      } else {
        mistakeStore.add(
          MistakeEntry(
            subject: _subject!,
            concept: _concept!,
            type: _type,
            note: _note.text.trim(),
            date: DateTime.now(),
            hasPhoto: widget.imageBytes != null,
            imageBytes: widget.imageBytes,
            options: options,
            correctIndex: _correctIndex,
          ),
        );
      }
      unawaited(sound.correct());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('hata kaydedilemedi: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).confirmSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(context, l),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Gap.screen, 0, Gap.screen, Gap.screen),
                children: <Widget>[
                  if (widget.imageBytes != null) _photo(context, l),
                  if (_outOfCredit) ...<Widget>[
                    const SizedBox(height: Gap.md),
                    _creditNotice(context, l),
                  ],
                  const SizedBox(height: Gap.md),
                  _kimoLine(context, l),
                  const SizedBox(height: Gap.md),
                  _classificationCard(context, l),
                  const SizedBox(height: Gap.md),
                  _correctOptionCard(context, l),
                  const SizedBox(height: Gap.md),
                  _reasonCard(context, l),
                ],
              ),
            ),
            _saveBar(context, l),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.screen, Gap.md),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            icon: KimoIcon(KimoIcons.close, color: c.ink),
            tooltip: l.actionCancel,
          ),
          Expanded(child: Text(l.confirmTitle, style: t.section)),
        ],
      ),
    );
  }

  Widget _photo(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: <Widget>[
          ClipRRect(
            borderRadius: Radii.all(Radii.card),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.memory(widget.imageBytes!, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.sm),
              decoration: BoxDecoration(
                color: c.overlay,
                borderRadius: Radii.all(Radii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  KimoIcon(KimoIcons.play, size: 14, color: c.onAction),
                  const SizedBox(width: Gap.xs),
                  Text(
                    l.confirmFullscreen,
                    style: t.captionStrong.copyWith(color: c.onAction),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    if (widget.imageBytes == null) return;
    sound.tap();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Center(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image.memory(widget.imageBytes!),
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const KimoIcon(KimoIcons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hak bittiğinde gösterilen bilgi. Geri sayım YOK — tasarım kararı:
  /// "Arayüzde geri sayım yok, kalan hak gösterilir."
  Widget _creditNotice(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      color: c.honeyTint,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.creditExhaustedTitle,
            style: t.bodyStrong.copyWith(color: c.honeyText),
          ),
          const SizedBox(height: Gap.xs),
          Text(l.creditExhaustedBody, style: t.caption),
        ],
      ),
    );
  }

  Widget _kimoLine(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Kimo(size: 44, controller: _kimo),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(
              _manual ? l.confirmIntroManual : l.confirmIntro,
              style: t.body,
            ),
          ),
        ),
      ],
    );
  }

  Widget _classificationCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Column(
        children: <Widget>[
          // Sınav — iki değerli, doğrudan segment.
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
            child: Row(
              children: <Widget>[
                SizedBox(width: 64, child: Text(l.confirmExam, style: t.caption)),
                Expanded(
                  child: SegmentedTabs(
                    labels: const <String>['TYT', 'AYT'],
                    selectedIndex: _exam == 'AYT' ? 1 : 0,
                    onChanged: (int i) {
                      sound.tap();
                      setState(() {
                        _exam = i == 1 ? 'AYT' : 'TYT';
                        // Müfredat sınava göre değişiyor; eski seçim geçersiz.
                        _subject = null;
                        _concept = null;
                        _extras.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          // Ders — yerinde açılan çip satırı, modal yok.
          _row(
            context,
            label: l.confirmSubject,
            value: _subject,
            onTap: () => setState(() => _subjectOpen = !_subjectOpen),
          ),
          if (_subjectOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: <Widget>[
                  for (final String s in _subjects)
                    KimoChip(
                      label: s,
                      selected: s == _subject,
                      onTap: () {
                        sound.tap();
                        setState(() {
                          _subject = s;
                          _concept = null;
                          _extras.clear();
                          _subjectOpen = false;
                        });
                      },
                    ),
                ],
              ),
            ),
          Divider(height: 1, color: c.border),
          _row(
            context,
            label: l.confirmTopic,
            value: _concept,
            placeholder: l.confirmTopicPick,
            enabled: _subject != null,
            onTap: _subject == null ? null : () => _pickTopic(context),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String? value,
    String? placeholder,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.rowMin),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        child: Row(
          children: <Widget>[
            SizedBox(width: 64, child: Text(label, style: t.caption)),
            Expanded(
              child: Text(
                value ?? placeholder ?? '—',
                style: value == null
                    ? t.body.copyWith(color: c.inkMuted)
                    : t.label,
              ),
            ),
            if (onTap != null)
              KimoIcon(
                KimoIcons.back,
                size: 18,
                color: enabled ? c.inkMuted : c.border,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTopic(BuildContext context) async {
    sound.tap();
    final String? picked = await showTopicPicker(
      context,
      curriculum: userProfile.curriculum,
      exam: _exam,
      subject: _subject!,
      selected: _concept,
    );
    if (!mounted || picked == null) return;
    setState(() => _concept = picked);
  }

  Widget _correctOptionCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.confirmCorrectOption, style: t.caption),
          const SizedBox(height: Gap.md),
          Row(
            children: <Widget>[
              for (int i = 0; i < _labels.length; i++) ...<Widget>[
                Expanded(
                  child: _optionButton(context, i),
                ),
                if (i != _labels.length - 1) const SizedBox(width: Gap.sm),
              ],
            ],
          ),
          if (_correctIndex == null) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Text(
              l.confirmNeedCorrect,
              style: t.caption.copyWith(color: c.actionText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionButton(BuildContext context, int index) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool selected = _correctIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        sound.tap();
        setState(() => _correctIndex = index);
      },
      child: AnimatedContainer(
        duration: Motion.press,
        height: Sizes.rowMin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.mint : c.sunken,
          borderRadius: Radii.all(Radii.pill),
        ),
        child: Text(
          _labels[index],
          style: t.numberMedium.copyWith(
            color: selected ? c.onAction : c.inkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _reasonCard(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    final KimoColors c = context.c;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(l.confirmWhyWrong, style: t.bodyStrong),
              const SizedBox(width: Gap.xs),
              Text(
                l.confirmOptional,
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: <Widget>[
              for (final MistakeType type in MistakeType.choices)
                KimoChip(
                  label: type.label,
                  selected: _type == type,
                  onTap: () {
                    sound.tap();
                    // İkinci dokunuş seçimi kaldırıyor: alan isteğe bağlı ve
                    // yanlışlıkla seçilen bir sebep geri alınabilmeli.
                    setState(() => _type = _type == type ? null : type);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.md, Gap.screen, Gap.md),
      decoration: BoxDecoration(
        color: c.page,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KimoButton(
            label: l.confirmSave,
            onPressed: _canSave ? _save : null,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            _canSave
                // Tekrar merdiveninin İLK adımı 1 gün (ReviewScheduler.steps
                // ilk elemanı). Tasarımda "3 gün" yazıyordu; kod kazandı.
                ? l.confirmNextReview
                : (_subject == null || _concept == null)
                    ? l.confirmNeedTopic
                    : l.confirmNeedCorrect,
            style: t.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

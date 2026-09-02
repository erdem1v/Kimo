import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';

/// Sınav yılı → müfredat (2026–2027 eski, 2028+ Maarif).
///
/// [dismissible] false ise kapatılamıyor; ilk açılışta müfredat seçilmeden
/// devam etmek konu eşleştirmesini yanlış müfredata bağlardı.
Future<void> showExamYearSheet(
  BuildContext context, {
  bool dismissible = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: dismissible,
    enableDrag: dismissible,
    isScrollControlled: true,
    backgroundColor: context.c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) =>
        PopScope(canPop: dismissible, child: const _ExamYearForm()),
  );
}

class _ExamYearForm extends StatefulWidget {
  const _ExamYearForm();

  @override
  State<_ExamYearForm> createState() => _ExamYearFormState();
}

class _ExamYearFormState extends State<_ExamYearForm> {
  static const List<int> _years = <int>[2026, 2027, 2028, 2029, 2030];
  int? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = userProfile.examYear;
  }

  Future<void> _save() async {
    if (_selected == null || _saving) return;
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    sound.tap();
    setState(() => _saving = true);
    try {
      await userProfile.setExamYear(_selected!);
      nav.pop();
    } catch (e) {
      // Sessizce kapanmıyor: yıl kaydedilemediyse müfredat da değişmemiştir
      // ve kullanıcı bunu bilmeli.
      debugPrint('sınav yılı kaydedilemedi: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.examYearSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final String? curr = _selected == null
        ? null
        : UserProfile.curriculumForYear(_selected!);

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
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: Radii.all(2),
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text(l.examYearTitle, style: t.section),
            const SizedBox(height: Gap.xxs),
            Text(l.examYearBody, style: t.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: Gap.lg),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: <Widget>[
                for (final int y in _years)
                  KimoChip(
                    label: '$y',
                    selected: _selected == y,
                    onTap: () {
                      sound.tap();
                      setState(() => _selected = y);
                    },
                  ),
              ],
            ),
            if (curr != null) ...<Widget>[
              const SizedBox(height: Gap.lg),
              Row(
                children: <Widget>[
                  KimoIcon(KimoIcons.notebook, size: 16, color: c.inkMuted),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      curr == UserProfile.maarif
                          ? l.examYearMaarif
                          : l.examYearOld,
                      style: t.caption.copyWith(color: c.inkSecondary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Gap.xl),
            KimoButton(
              label: _saving ? l.actionSave : l.actionContinue,
              onPressed: (_selected == null || _saving) ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

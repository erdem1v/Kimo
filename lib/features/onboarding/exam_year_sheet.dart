import 'package:flutter/material.dart';

import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';

/// Sınav yılını soran alt sayfa. Yıl → müfredat (2026-2027 eski, 2028+ maarif).
/// İlk açılışta [dismissible]=false ile zorunlu; profilde true ile isteğe bağlı.
Future<void> showExamYearSheet(
  BuildContext context, {
  bool dismissible = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: dismissible,
    enableDrag: dismissible,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    setState(() => _saving = true);
    await userProfile.setExamYear(_selected!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final String? curr = _selected == null
        ? null
        : UserProfile.curriculumForYear(_selected!);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
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
            const SizedBox(height: 18),
            const Text(
              'YKS\'ye hangi yıl gireceksin?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Konuları doğru müfredata göre eşleştirebilmemiz için gerekli.',
              style: TextStyle(color: AppColors.inkLight, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final int y in _years)
                  ChoiceChip(
                    label: Text('$y'),
                    selected: _selected == y,
                    onSelected: (_) => setState(() => _selected = y),
                    labelStyle: TextStyle(
                      color: _selected == y ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.green,
                    backgroundColor: const Color(0xFFF4F4F4),
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ],
            ),
            if (curr != null) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.blueDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      curr == UserProfile.maarif
                          ? 'Yeni müfredat (Maarif Modeli)'
                          : 'Mevcut müfredat (2018)',
                      style: const TextStyle(
                        color: AppColors.blueDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            GameButton(
              label: _saving ? 'Kaydediliyor...' : 'DEVAM',
              enabled: _selected != null && !_saving,
              onPressed: _save,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

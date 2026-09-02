import 'package:flutter/material.dart';

import 'package:ai_yks_coach/data/question_send_repository.dart';
import 'package:ai_yks_coach/models/report_reason.dart';
import 'package:ai_yks_coach/services/sound_service.dart';
import 'package:ai_yks_coach/theme/app_colors.dart';
import 'package:ai_yks_coach/widgets/game_button.dart';

/// Havuz sorusunu şikayet etme alt sayfası. Gönderilirse true döner
/// (çağıran ekran o soruyu atlar).
Future<bool> showReportQuestionSheet(
  BuildContext context, {
  required String questionId,
}) async {
  final bool? sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext ctx) => _ReportSheet(questionId: questionId),
  );
  return sent ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.questionId});

  final String questionId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _note = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_reason == null || _sending) return false;
    // "Başka bir sorun" seçildiyse açıklama zorunlu.
    if (_reason == ReportReason.other) return _note.text.trim().length >= 5;
    return true;
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      await questionSendRepository.report(
        questionId: widget.questionId,
        reason: _reason!,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirilemedi. Bu soruyu zaten bildirmiş olabilirsin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Bu soruyu bildir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text(
              'Sorun ne? Bildirdiğin soru sana bir daha gösterilmez.',
              style: TextStyle(color: AppColors.inkLight, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final ReportReason r in ReportReason.values) _tile(r),
                ],
              ),
            ),
            if (_reason == ReportReason.other) ...<Widget>[
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLength: 200,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Kısaca ne olduğunu yaz…',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF4F4F4),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            GameButton(
              label: _sending ? 'Gönderiliyor...' : 'BİLDİR',
              color: AppColors.red,
              enabled: _canSend,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(ReportReason r) {
    final bool selected = _reason == r;
    final Color color = r.color;
    return GestureDetector(
      onTap: () {
        sound.tap();
        setState(() => _reason = r);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(r.icon,
                size: 20, color: selected ? color : AppColors.inkLight),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(r.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: selected ? color : AppColors.ink)),
                  const SizedBox(height: 1),
                  Text(r.hint,
                      style: const TextStyle(
                          color: AppColors.inkLight, fontSize: 11.5)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

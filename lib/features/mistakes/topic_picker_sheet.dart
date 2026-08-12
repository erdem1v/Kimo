import 'package:flutter/material.dart';

import '../../data/yks_curriculum.dart';
import '../../services/sound_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mistake_style.dart';

/// Konu seçici. Konular yalnızca müfredat listesinden seçilebilir; serbest
/// metin girilemez. Aksi hâlde aynı konu farklı adlarla yazılır, harita ve
/// havuz eşleşmez.
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
      final List<String> hits = u.topics
          .where((String t) => t.toLowerCase().contains(q))
          .toList();
      if (hits.isNotEmpty) out.add(Unit(u.name, hits));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = subjectColor(widget.subject);
    final List<Unit> units = _filtered;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 12 + MediaQuery.of(context).viewInsets.bottom),
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
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Text(subjectEmoji(widget.subject),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('${widget.subject} · ${widget.exam}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 2),
              const Text('Konuyu listeden seç',
                  style: TextStyle(color: AppColors.inkLight, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Konu ara…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.inkLight),
                  filled: true,
                  fillColor: const Color(0xFFF4F4F4),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: units.isEmpty
                    ? const Center(
                        child: Text('Konu bulunamadı.',
                            style: TextStyle(color: AppColors.inkLight)),
                      )
                    : ListView(
                        children: <Widget>[
                          for (final Unit u in units) ...<Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
                              child: Text(
                                u.name.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
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
    final bool isSelected = widget.selected == topic;
    return GestureDetector(
      onTap: () {
        sound.tap();
        Navigator.of(context).pop(topic);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.line,
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                topic,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSelected ? color : AppColors.ink,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

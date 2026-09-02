import 'package:flutter/material.dart';

import '../../data/moderation_repository.dart';
import '../../data/yks_curriculum.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_photo.dart';
import '../../widgets/mistake_style.dart';
import '../mistakes/topic_picker_sheet.dart';

/// Moderatör ekranı: tüm kullanıcıların soruları. Yanlış sınıflandırılmışları
/// tek tek düzeltmek, yayından kaldırmak veya silmek için.
class AllQuestionsScreen extends StatefulWidget {
  const AllQuestionsScreen({super.key});

  @override
  State<AllQuestionsScreen> createState() => _AllQuestionsScreenState();
}

// Havuz kaldırıldığı için `pool`/`private` süzgeçleri de kaldırıldı: hiçbir
// soru artık paylaşıma açılmıyor, o iki liste her zaman boş/tamdı.
enum _Filter { all, hidden, invalid }

class _AllQuestionsScreenState extends State<AllQuestionsScreen> {
  List<AdminQuestion> _items = <AdminQuestion>[];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<AdminQuestion> items =
          await moderationRepository.allQuestions();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Sorular yüklenemedi. Moderatör yetkin var mı?';
        _loading = false;
      });
    }
  }

  /// Konu müfredatta var mı? (yanlış sınıflandırmayı bulmak için)
  bool _isValid(AdminQuestion q) {
    if (q.exam != 'TYT' && q.exam != 'AYT') return false;
    final Map<String, List<Unit>> subjects =
        YksCurriculum.forExam(userProfile.curriculum, q.exam!);
    final List<Unit>? units = subjects[q.subject];
    if (units == null) return false;
    return units.any((Unit u) => u.topics.contains(q.concept));
  }

  List<AdminQuestion> get _filtered => switch (_filter) {
        _Filter.all => _items,
        _Filter.hidden => _items
            .where((AdminQuestion q) => q.moderation != 'ok')
            .toList(),
        _Filter.invalid =>
          _items.where((AdminQuestion q) => !_isValid(q)).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final int invalid =
        _items.where((AdminQuestion q) => !_isValid(q)).length;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tüm sorular'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _filters(invalid),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filters(int invalid) {
    Widget chip(_Filter f, String label, {int? badge}) {
      final bool sel = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? AppColors.ink : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label,
                    style: TextStyle(
                        color: sel ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                if (badge != null && badge > 0) ...<Widget>[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: <Widget>[
          chip(_Filter.all, 'Tümü (${_items.length})'),
          chip(_Filter.invalid, 'Hatalı', badge: invalid),
          chip(_Filter.hidden, 'Gizli/Kaldırıldı'),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkLight)),
            ),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    final List<AdminQuestion> items = _filtered;
    if (items.isEmpty) {
      return const Center(
        child: Text('Bu filtrede soru yok.',
            style: TextStyle(color: AppColors.inkLight)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int i) => _card(items[i]),
    );
  }

  Widget _card(AdminQuestion q) {
    final bool valid = _isValid(q);
    final Color color = subjectColor(q.subject);
    return GestureDetector(
      onTap: () => _openEditor(q),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: valid ? AppColors.line : AppColors.red,
            width: valid ? 1.5 : 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: q.photoPath == null
                    ? Container(
                        color: AppColors.blueBg,
                        child: const Icon(Icons.notes_rounded,
                            color: AppColors.blueDark, size: 20))
                    : MistakePhoto(path: q.photoPath!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: q.exam == null
                              ? AppColors.red
                              : color.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(q.exam ?? '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${q.subject} · ${q.concept}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Text(q.ownerNickname,
                          style: const TextStyle(
                              color: AppColors.inkLight, fontSize: 11.5)),
                      const SizedBox(width: 8),
                      _badge(q),
                      if (q.reportCount > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        Text('🚩${q.reportCount}',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ],
                  ),
                  if (!valid) ...<Widget>[
                    const SizedBox(height: 3),
                    const Text('müfredatta karşılığı yok',
                        style: TextStyle(
                            color: AppColors.redDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkLight),
          ],
        ),
      ),
    );
  }

  Widget _badge(AdminQuestion q) {
    final (String label, Color color) = switch (q.moderation) {
      'removed' => ('kaldırıldı', AppColors.red),
      'hidden' => ('gizli', AppColors.orange),
      _ => ('yayında', AppColors.green),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 10.5)),
    );
  }

  Future<void> _openEditor(AdminQuestion q) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => _QuestionEditor(question: q)),
    );
    if (changed == true) await _load();
  }
}

/// Tek bir sorunun düzeltme ekranı.
class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({required this.question});

  final AdminQuestion question;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late String? _exam = widget.question.exam;
  late String _subject = widget.question.subject;
  late String? _concept = widget.question.concept;
  late int? _correctIndex = widget.question.correctIndex;
  late final List<String> _extras =
      List<String>.of(widget.question.extraConcepts);
  bool _saving = false;
  static const int _maxExtras = 2;

  Map<String, List<Unit>> get _subjects => YksCurriculum.forExam(
      userProfile.curriculum, _exam == 'AYT' ? 'AYT' : 'TYT');

  bool get _conceptValid =>
      _exam != null && _concept != null && _topicExists(_concept!);

  /// Konu, seçili sınav+ders altında müfredatta var mı?
  bool _topicExists(String topic) {
    final List<Unit>? units = _subjects[_subject];
    return units?.any((Unit u) => u.topics.contains(topic)) ?? false;
  }

  Future<void> _pickTopic() async {
    if (_exam == null) return;
    final String? picked = await showTopicPicker(
      context,
      curriculum: userProfile.curriculum,
      exam: _exam!,
      subject: _subject,
      selected: _concept,
    );
    if (picked != null) setState(() => _concept = picked);
  }

  Future<void> _pickExtra() async {
    if (_exam == null) return;
    final String? picked = await showTopicPicker(
      context,
      curriculum: userProfile.curriculum,
      exam: _exam!,
      subject: _subject,
    );
    if (picked == null) return;
    if (picked == _concept || _extras.contains(picked)) return;
    setState(() => _extras.add(picked));
  }

  Future<void> _save() async {
    if (_saving || !_conceptValid) return;
    setState(() => _saving = true);
    try {
      await moderationRepository.updateQuestion(
        widget.question.id,
        subject: _subject,
        concept: _concept,
        exam: _exam,
        correctIndex: _correctIndex,
        extraConcepts: _extras,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi.')),
      );
    }
  }

  Future<void> _action(String action, String label) async {
    if (action == 'delete') {
      final bool ok = await _confirmDelete();
      if (!ok) return;
    }
    final String? photoPath = widget.question.photoPath;
    try {
      if (action == 'delete') {
        // Satır silinince photo_path'i kaybederiz; dosyayı ÖNCE sil, yoksa
        // nesne depoda yetim kalır (bugünkü davranış tam olarak buydu).
        if (photoPath != null && photoPath.isNotEmpty) {
          await moderationRepository.purgePhoto(widget.question.id, photoPath);
        }
        await moderationRepository.questionAction(widget.question.id, action);
      } else {
        await moderationRepository.questionAction(widget.question.id, action);
        // 'hide' → moderation='removed': dosya da gitmeli (Değişmez 3).
        if (action == 'hide') {
          await moderationRepository.purgePhoto(widget.question.id, photoPath);
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label başarısız.')));
    }
  }

  Future<bool> _confirmDelete() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Soruyu sil'),
        content: const Text(
          'Bu soru kalıcı olarak silinecek. Sahibinin hata bankasından da '
          'kalkar ve geri alınamaz.',
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AdminQuestion q = widget.question;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Soruyu düzelt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          if (q.photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 320,
                color: Colors.white,
                child: MistakePhoto(path: q.photoPath!, fit: BoxFit.contain),
              ),
            ),
          const SizedBox(height: 18),
          _label('Sınav'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String e in const <String>['TYT', 'AYT'])
                ChoiceChip(
                  label: Text(e),
                  selected: _exam == e,
                  onSelected: (_) => setState(() {
                    _exam = e;
                    // Sınav değişince ders/konu geçerliliği bozulabilir.
                    if (!_subjects.containsKey(_subject)) {
                      _subject = _subjects.keys.first;
                    }
                    if (!_conceptValid) _concept = null;
                    _extras.removeWhere((String c) => !_topicExists(c));
                  }),
                  labelStyle: TextStyle(
                    color: _exam == e ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: AppColors.blue,
                  backgroundColor: const Color(0xFFF4F4F4),
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 18),
          _label('Ders'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String s in _subjects.keys)
                ChoiceChip(
                  label: Text(s),
                  selected: _subject == s,
                  onSelected: (_) => setState(() {
                    _subject = s;
                    _concept = null;
                    _extras.removeWhere((String c) => !_topicExists(c));
                  }),
                  labelStyle: TextStyle(
                    color: _subject == s ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: subjectColor(s),
                  backgroundColor: const Color(0xFFF4F4F4),
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 18),
          _label('Konu'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickTopic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _conceptValid ? AppColors.line : AppColors.red,
                  width: _conceptValid ? 1.5 : 2,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _concept ?? 'Konu seç',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _concept == null
                            ? AppColors.inkLight
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded,
                      color: AppColors.inkLight),
                ],
              ),
            ),
          ),
          if (_concept != null) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String c in _extras)
                  Chip(
                    label: Text(c, style: const TextStyle(fontSize: 12.5)),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    backgroundColor: AppColors.purple.withValues(alpha: 0.12),
                    side: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.35)),
                    deleteIconColor: AppColors.purpleDark,
                    onDeleted: () => setState(() => _extras.remove(c)),
                  ),
                if (_extras.length < _maxExtras)
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded,
                        size: 16, color: AppColors.inkLight),
                    label: const Text('Başka konuya da değiyor',
                        style: TextStyle(fontSize: 12.5)),
                    backgroundColor: const Color(0xFFF4F4F4),
                    side: BorderSide.none,
                    onPressed: _pickExtra,
                  ),
              ],
            ),
          ],
          if (q.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            _label('Doğru şık'),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (int i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _correctIndex = i),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _correctIndex == i
                              ? AppColors.green
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _correctIndex == i
                                ? AppColors.green
                                : AppColors.line,
                            width: 2.5,
                          ),
                        ),
                        child: Text(
                          q.options[i].label.isEmpty
                              ? String.fromCharCode(65 + i)
                              : q.options[i].label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: _correctIndex == i
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 26),
          GameButton(
            label: _saving ? 'Kaydediliyor...' : 'KAYDET',
            enabled: _conceptValid && !_saving,
            onPressed: _save,
          ),
          const SizedBox(height: 12),
          if (q.moderation == 'removed')
            OutlinedButton.icon(
              onPressed: () => _action('restore', 'Geri alma'),
              icon: const Icon(Icons.undo_rounded, color: AppColors.green),
              label: const Text('Yayına geri al',
                  style: TextStyle(
                      color: AppColors.green, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: AppColors.green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _action('hide', 'Yayından kaldırma'),
              icon: const Icon(Icons.visibility_off_outlined,
                  color: AppColors.orange),
              label: const Text('Yayından kaldır',
                  style: TextStyle(
                      color: AppColors.orange, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: AppColors.orange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _action('delete', 'Silme'),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.red, size: 20),
            label: const Text('Soruyu tamamen sil',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink));
}

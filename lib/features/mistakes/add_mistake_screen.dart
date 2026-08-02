import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../state/mistake_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_style.dart';

/// Hatalı soru ekleme ekranı. Fotoğraf yükleme mock; kayıt hata bankasına
/// eklenir.
class AddMistakeScreen extends StatefulWidget {
  const AddMistakeScreen({super.key});

  @override
  State<AddMistakeScreen> createState() => _AddMistakeScreenState();
}

class _AddMistakeScreenState extends State<AddMistakeScreen> {
  static const List<String> _subjects = <String>[
    'Matematik',
    'Geometri',
    'Fizik',
    'Kimya',
    'Türkçe',
    'Biyoloji',
  ];

  final TextEditingController _concept = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _hasPhoto = false;
  String? _subject;
  MistakeType? _type;

  @override
  void initState() {
    super.initState();
    _concept.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _concept.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _concept.text.trim().isNotEmpty && _subject != null && _type != null;

  void _pickPhoto() {
    sound.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.blue),
                title: const Text('Kamera ile çek'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _hasPhoto = true);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library_rounded, color: AppColors.green),
                title: const Text('Galeriden seç'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _hasPhoto = true);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _save() {
    mistakeStore.add(
      MistakeEntry(
        subject: _subject!,
        concept: _concept.text.trim(),
        type: _type!,
        note: _note.text.trim(),
        date: DateTime.now(),
        hasPhoto: _hasPhoto,
      ),
    );
    sound.correct();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Hatalı Soru Ekle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          _photoArea(),
          const SizedBox(height: 22),
          _label('Konu / Kavram'),
          const SizedBox(height: 8),
          TextField(
            controller: _concept,
            decoration: _inputDecoration('Örn. Oran - Orantı'),
          ),
          const SizedBox(height: 22),
          _label('Ders'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String s in _subjects)
                ChoiceChip(
                  label: Text(s),
                  selected: _subject == s,
                  onSelected: (_) => setState(() => _subject = s),
                  labelStyle: TextStyle(
                    color: _subject == s ? Colors.white : AppColors.ink,
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
          const SizedBox(height: 22),
          _label('Hata türü'),
          const SizedBox(height: 8),
          for (final MistakeType t in MistakeType.values) _typeTile(t),
          const SizedBox(height: 22),
          _label('Not (opsiyonel)'),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: _inputDecoration('Neyi yanlış yaptığını kısaca yaz...'),
          ),
          const SizedBox(height: 28),
          GameButton(
            label: 'KAYDET',
            enabled: _canSave,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _photoArea() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: _hasPhoto ? AppColors.greenBg : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hasPhoto ? AppColors.green : AppColors.line,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              _hasPhoto ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
              size: 40,
              color: _hasPhoto ? AppColors.green : AppColors.inkLight,
            ),
            const SizedBox(height: 10),
            Text(
              _hasPhoto ? 'Fotoğraf eklendi' : 'Soruyu fotoğrafla veya yükle',
              style: TextStyle(
                color: _hasPhoto ? AppColors.greenDark : AppColors.inkLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeTile(MistakeType type) {
    final bool selected = _type == type;
    final Color color = mistakeColor(type);
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.line,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Text(type.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.ink,
                  fontSize: 15,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
}

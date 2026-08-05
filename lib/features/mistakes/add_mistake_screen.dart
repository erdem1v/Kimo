import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/mistake_repository.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/mistake_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_style.dart';

/// Hatalı soru ekleme. Fotoğraf seçilince AI şıkları çıkarır; kullanıcı doğru
/// şıkkı işaretler. Kayıt hata bankasına eklenir.
class AddMistakeScreen extends StatefulWidget {
  const AddMistakeScreen({super.key});

  @override
  State<AddMistakeScreen> createState() => _AddMistakeScreenState();
}

class _AddMistakeScreenState extends State<AddMistakeScreen> {
  // Tüm YKS dersleri (AI önerisi bunlardan biriyle eşleşsin diye geniş tutuldu).
  final List<String> _subjects = <String>[
    'Türkçe',
    'Matematik',
    'Geometri',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Edebiyat',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'Din Kültürü',
  ];

  final TextEditingController _concept = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _subject;
  String? _exam; // 'TYT' | 'AYT' (AI önerir, kullanıcı düzenleyebilir)
  MistakeType? _type;
  bool _saving = false;

  // AI ile çıkarılan şıklar
  bool _analyzing = false;
  String? _analysisReason;
  final List<TextEditingController> _optionCtrls = <TextEditingController>[];
  final List<String> _optionLabels = <String>[];
  int? _correctIndex;

  @override
  void initState() {
    super.initState();
    _concept.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _concept.dispose();
    _note.dispose();
    _clearOptions();
    super.dispose();
  }

  bool get _canSave {
    final bool base = _concept.text.trim().isNotEmpty &&
        _subject != null &&
        _type != null;
    if (!SupabaseConfig.isConfigured) {
      return base && (_optionCtrls.isEmpty || _correctIndex != null);
    }
    // Supabase modunda şıklar zorunlu: şık yoksa/doğru işaretlenmediyse kaydetme.
    return base &&
        !_analyzing &&
        _optionCtrls.isNotEmpty &&
        _correctIndex != null;
  }

  void _clearOptions() {
    for (final TextEditingController c in _optionCtrls) {
      c.dispose();
    }
    _optionCtrls.clear();
    _optionLabels.clear();
    _correctIndex = null;
  }

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
                  _pick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.green),
                title: const Text('Galeriden seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
      if (SupabaseConfig.isConfigured) _analyze(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf alınamadı.')),
      );
    }
  }

  Future<void> _analyze(Uint8List bytes) async {
    setState(() {
      _analyzing = true;
      _analysisReason = null;
    });
    try {
      final QuestionAnalysis res =
          await mistakeRepository.analyzeQuestion(bytes);
      if (!mounted) return;
      _clearOptions();
      setState(() {
        if (res.ok) {
          for (final QuestionOption o in res.options) {
            _optionLabels.add(o.label);
            _optionCtrls.add(TextEditingController(text: o.text));
          }
          // AI'nın ders/konu/sınav önerilerini otomatik doldur (düzenlenebilir).
          if (res.subject != null) {
            if (!_subjects.contains(res.subject)) {
              _subjects.insert(0, res.subject!);
            }
            _subject = res.subject;
          }
          if (res.concept != null && res.concept!.isNotEmpty) {
            _concept.text = res.concept!;
          }
          if (res.exam == 'TYT' || res.exam == 'AYT') _exam = res.exam;
          _analysisReason = null;
        } else {
          _analysisReason =
              res.reason ?? 'Fotoğrafta net bir soru ve şıklar görünmeli.';
        }
        _analyzing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _analysisReason = 'Şıklar çıkarılamadı. Tekrar dene.';
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final List<QuestionOption>? options = _optionCtrls.isEmpty
          ? null
          : <QuestionOption>[
              for (int i = 0; i < _optionCtrls.length; i++)
                QuestionOption(
                    label: _optionLabels[i], text: _optionCtrls[i].text.trim()),
            ];

      if (SupabaseConfig.isConfigured) {
        await mistakeRepository.add(
          subject: _subject!,
          concept: _concept.text.trim(),
          type: _type!,
          note: _note.text.trim(),
          imageBytes: _imageBytes,
          options: options,
          correctIndex: _correctIndex,
          exam: _exam,
        );
      } else {
        mistakeStore.add(
          MistakeEntry(
            subject: _subject!,
            concept: _concept.text.trim(),
            type: _type!,
            note: _note.text.trim(),
            date: DateTime.now(),
            hasPhoto: _imageBytes != null,
            imageBytes: _imageBytes,
            options: options,
            correctIndex: _correctIndex,
          ),
        );
      }
      sound.correct();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi. Tekrar dene.')),
        );
        setState(() => _saving = false);
      }
    }
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
          if (SupabaseConfig.isConfigured &&
              _imageBytes != null &&
              !_analyzing) ...<Widget>[
            const SizedBox(height: 22),
            _label('Şıklar'),
            const SizedBox(height: 8),
            _optionsBlock(),
          ],
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              _label('Konu / Kavram'),
              if (SupabaseConfig.isConfigured &&
                  _imageBytes != null &&
                  !_analyzing &&
                  _optionCtrls.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                _aiHint(),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _concept,
            decoration: _inputDecoration('Örn. Birinci Dereceden Denklem'),
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
          _label('Sınav'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String e in const <String>['TYT', 'AYT'])
                ChoiceChip(
                  label: Text(e),
                  selected: _exam == e,
                  onSelected: (_) => setState(() => _exam = e),
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
            label: _saving ? 'Kaydediliyor...' : 'KAYDET',
            enabled: _canSave && !_saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _optionsBlock() {
    if (_optionCtrls.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.redBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded, color: AppColors.redDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _analysisReason ??
                        'Fotoğrafta net bir soru ve şıklar görünmeli.',
                    style: const TextStyle(
                        color: AppColors.redDark, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Soruyu şıklarıyla birlikte, net ve yakın çek.',
              style: TextStyle(color: AppColors.redDark, fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _analyze(_imageBytes!),
                child: const Text('Tekrar dene'),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Doğru şıkka dokunup işaretle:',
            style: TextStyle(color: AppColors.inkLight, fontSize: 13)),
        const SizedBox(height: 8),
        for (int i = 0; i < _optionCtrls.length; i++) _optionRow(i),
      ],
    );
  }

  Widget _optionRow(int i) {
    final bool correct = _correctIndex == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => setState(() => _correctIndex = i),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: correct ? AppColors.green : Colors.transparent,
                border: Border.all(
                    color: correct ? AppColors.green : AppColors.line, width: 2),
              ),
              child: correct
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(_optionLabels[i],
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _optionCtrls[i],
              decoration: _inputDecoration('Şık ${_optionLabels[i]}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoArea() {
    final bool hasImage = _imageBytes != null;
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasImage ? AppColors.green : AppColors.line,
            width: 2,
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.edit, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Değiştir',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const <Widget>[
                  Icon(Icons.add_a_photo_rounded,
                      size: 40, color: AppColors.inkLight),
                  SizedBox(height: 10),
                  Text('Soruyu fotoğrafla veya yükle',
                      style: TextStyle(
                          color: AppColors.inkLight, fontWeight: FontWeight.w700)),
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

  /// Ders/konu/sınav alanlarının AI tarafından dolduğunu belirten küçük rozet.
  Widget _aiHint() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 13, color: AppColors.purpleDark),
            SizedBox(width: 4),
            Text('AI doldurdu · düzenleyebilirsin',
                style: TextStyle(
                    color: AppColors.purpleDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ],
        ),
      );

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

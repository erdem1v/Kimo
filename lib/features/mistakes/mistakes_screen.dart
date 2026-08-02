import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/mistake_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_style.dart';
import 'add_mistake_screen.dart';

/// Hata bankası: kaydedilmiş hatalı soruların listesi ve yeni hata ekleme.
class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});

  Future<void> _openAdd(BuildContext context) async {
    final bool? added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AddMistakeScreen()),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hata bankana eklendi 🎯'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Hatalarım')),
      body: ListenableBuilder(
        listenable: mistakeStore,
        builder: (BuildContext context, _) {
          final List<MistakeEntry> items = mistakeStore.items;
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _summaryCard(items.length),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int i) =>
                      _MistakeCard(entry: items[i]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GameButton(
          label: 'HATALI SORU EKLE',
          icon: Icons.add_a_photo_rounded,
          onPressed: () => _openAdd(context),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _summaryCard(int total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.purple, AppColors.purpleDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const Text('📌', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$total hatalı soru',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tekrar çözerek kalıcı öğren.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.entry});

  final MistakeEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color color = mistakeColor(entry.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Fotoğraf ön izleme.
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: entry.imageBytes != null
                ? Image.memory(
                    entry.imageBytes!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.blueBg,
                    child: Icon(
                      entry.hasPhoto ? Icons.image_rounded : Icons.notes_rounded,
                      color: AppColors.blueDark,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.concept,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.ink),
                      ),
                    ),
                    Text(
                      formatShortDate(entry.date),
                      style: const TextStyle(
                          color: AppColors.inkLight, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subject,
                  style: const TextStyle(color: AppColors.inkLight, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${entry.type.emoji} ${entry.type.label}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (entry.note.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    entry.note,
                    style: const TextStyle(
                        color: AppColors.ink, fontSize: 13, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/mistake_repository.dart';
import '../../models/models.dart';
import '../../services/supabase_config.dart';
import '../../state/mistake_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../../widgets/mistake_photo.dart';
import '../../widgets/mistake_style.dart';
import 'add_mistake_screen.dart';

/// Hata bankası. Supabase yapılandırılmışsa uzak veriden, değilse mock
/// depodan beslenir.
class MistakesScreen extends StatefulWidget {
  const MistakesScreen({super.key});

  @override
  State<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends State<MistakesScreen> {
  final bool _remote = SupabaseConfig.isConfigured;
  List<MistakeEntry> _items = <MistakeEntry>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_remote) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<MistakeEntry> items = await mistakeRepository.fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Hatalar yüklenemedi.';
        _loading = false;
      });
    }
  }

  Future<void> _openAdd() async {
    final bool? added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AddMistakeScreen()),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hata bankana eklendi 🎯'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_remote) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Hatalarım')),
      body: _remote
          ? _remoteBody()
          : ListenableBuilder(
              listenable: mistakeStore,
              builder: (BuildContext context, _) => _list(mistakeStore.items),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GameButton(
          label: 'HATALI SORU EKLE',
          icon: Icons.add_a_photo_rounded,
          onPressed: _openAdd,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _remoteBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, style: const TextStyle(color: AppColors.inkLight)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    return RefreshIndicator(onRefresh: _load, child: _list(_items));
  }

  Widget _list(List<MistakeEntry> items) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _summaryCard(items.length),
        ),
        Expanded(
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'Henüz hata eklenmemiş.\nAşağıdan ilkini ekle 👇',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkLight),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int i) =>
                      _MistakeCard(entry: items[i]),
                ),
        ),
      ],
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 56, height: 56, child: _thumbnail()),
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
                    if (entry.isLeech)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppColors.redDark),
                            SizedBox(width: 4),
                            Text('Zorlanıyorsun',
                                style: TextStyle(
                                    color: AppColors.redDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ],
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

  Widget _thumbnail() {
    if (entry.imageBytes != null) {
      return Image.memory(entry.imageBytes!, fit: BoxFit.cover);
    }
    if (entry.photoPath != null) {
      return MistakePhoto(path: entry.photoPath!, fit: BoxFit.cover);
    }
    return _thumbPlaceholder();
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppColors.blueBg,
      child: Icon(
        entry.hasPhoto ? Icons.image_rounded : Icons.notes_rounded,
        color: AppColors.blueDark,
      ),
    );
  }
}

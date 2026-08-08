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
      appBar: AppBar(
        title: const Text('Hatalarım'),
        actions: <Widget>[
          if (_remote)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Yenile',
              onPressed: _loading ? null : _load,
            ),
        ],
      ),
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
    return _list(_items);
  }

  Widget _list(List<MistakeEntry> items) {
    final List<_Grp> groups = _groups(items);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      child: Column(
        children: <Widget>[
          _summaryCard(items.length),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Henüz hata eklenmemiş.\nAşağıdan ilkini ekle 👇',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkLight),
                ),
              ),
            )
          else
            Expanded(child: _grid(groups, items.length)),
        ],
      ),
    );
  }

  /// Kutucuklar 3 sütun halinde, kalan alana sığdırılır. Kutular okunur
  /// boyutun altına düşecekse sığdırmayı bırakıp kaydırmaya izin verir.
  Widget _grid(List<_Grp> groups, int total) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double spacing = 10;
        const int cols = 3;
        const double minCellH = 108; // kutunun okunur kaldığı en küçük yükseklik
        final int rows = (groups.length / cols).ceil();

        final double cellW = (c.maxWidth - (cols - 1) * spacing) / cols;
        final double availH = c.maxHeight - (rows - 1) * spacing;
        final double cellH = rows == 0 ? minCellH : availH / rows;
        final bool fits = cellH >= minCellH;
        final double h = fits ? cellH : minCellH;

        return GridView.count(
          crossAxisCount: cols,
          physics: fits
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: cellW / h,
          children: <Widget>[
            for (final _Grp g in groups) _groupBox(g, total),
          ],
        );
      },
    );
  }

  /// Hataları sınav+ders bazında gruplar; TYT → AYT → Belirsiz, her sınav
  /// içinde çoktan aza sıralanır.
  List<_Grp> _groups(List<MistakeEntry> items) {
    final Map<String, _Grp> map = <String, _Grp>{};
    for (final MistakeEntry e in items) {
      final String exam =
          (e.exam == 'TYT' || e.exam == 'AYT') ? e.exam! : 'Belirsiz';
      final String key = '$exam|${e.subject}';
      (map[key] ??= _Grp(exam, e.subject)).items.add(e);
    }
    int rank(String x) => x == 'TYT' ? 0 : (x == 'AYT' ? 1 : 2);
    final List<_Grp> list = map.values.toList();
    list.sort((_Grp a, _Grp b) {
      final int r = rank(a.exam).compareTo(rank(b.exam));
      if (r != 0) return r;
      final int c = b.items.length.compareTo(a.items.length);
      if (c != 0) return c;
      return a.subject.compareTo(b.subject);
    });
    return list;
  }

  /// Sınav+ders kutucuğu — dolu, canlı renk (ana ekranla aynı ton). Yazı rengi
  /// zemine göre okunur seçilir. Dokununca o grubun hataları ayrı ekranda açılır.
  Widget _groupBox(_Grp g, int total) {
    final Color color = subjectColor(g.subject);
    final Color fg =
        color.computeLuminance() > 0.55 ? AppColors.ink : Colors.white;
    final int count = g.items.length;
    final int percent = total == 0 ? 0 : (count / total * 100).round();
    final String examLabel = g.exam == 'Belirsiz' ? '?' : g.exam;
    return GestureDetector(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _GroupDetailScreen(
            title: '$examLabel · ${g.subject}',
            color: color,
            items: g.items,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(examLabel,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 10)),
                ),
                const Spacer(),
                Text(subjectEmoji(g.subject),
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
            const Spacer(),
            Flexible(
              child: Text(
                g.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13.5, color: fg),
              ),
            ),
            const SizedBox(height: 3),
            Text('$count soru · %$percent',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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

/// Sınav+ders bazlı hata grubu (Hatalarım ekranındaki kutucuklar).
class _Grp {
  _Grp(this.exam, this.subject);
  final String exam; // 'TYT' | 'AYT' | 'Belirsiz'
  final String subject;
  final List<MistakeEntry> items = <MistakeEntry>[];
}

/// Bir grubun (ör. "TYT · Matematik") hatalarını listeleyen detay ekranı.
class _GroupDetailScreen extends StatelessWidget {
  const _GroupDetailScreen({
    required this.title,
    required this.color,
    required this.items,
  });

  final String title;
  final Color color;
  final List<MistakeEntry> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        itemBuilder: (BuildContext context, int i) =>
            _MistakeCard(entry: items[i]),
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

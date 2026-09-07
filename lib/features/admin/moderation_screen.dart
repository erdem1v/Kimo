import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/moderation_repository.dart';
import '../../services/crash_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mistake_photo.dart';

/// Moderasyon kuyruğu: bildirilen sorular incelenir, kaldırılır ya da geri
/// alınır. Yalnızca moderatörlere görünür (yetki veritabanında doğrulanır).
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  List<PendingReport> _items = <PendingReport>[];

  /// Makine taramasının şüpheli bulduğu fotoğraflar (0050).
  List<FlaggedPhoto> _flagged = <FlaggedPhoto>[];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = <String>{};

  /// Kaldırıldığı hâlde dosyası hâlâ duran içerik sayısı (yarım kalan temizlik).
  int _pendingPurges = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _retryPurges();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<PendingReport> items = await moderationRepository.pending();
      // Şüpheli fotoğraflar ayrı bir kuyruk; okunamazsa şikâyet kuyruğunu
      // düşürmesin.
      List<FlaggedPhoto> flagged = _flagged;
      try {
        flagged = await moderationRepository.flaggedPhotos();
      } catch (e, st) {
        unawaited(reportError(e, st, context: 'admin.flaggedPhotos'));
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _flagged = flagged;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Kuyruk yüklenemedi.';
        _loading = false;
      });
    }
  }

  /// Yarım kalan dosya temizliklerini tamamlar.
  ///
  /// Kaldırma kararı ile dosyanın silinmesi iki ayrı adım: karar veritabanında,
  /// silme moderatörün oturumunda oluyor. Arada bağlantı koparsa nesne depoda
  /// kalır — yeni imzalı adres üretilemez ama dağıtılmış adresler ömürleri
  /// boyunca çalışır. Bu yüzden ekran her açıldığında kalanlar tekrar deneniyor;
  /// başarısız olanlar kuyrukta kalır ve aşağıda sayı olarak görünür.
  Future<void> _retryPurges() async {
    try {
      final List<({String mistakeId, String photoPath})> pending =
          await moderationRepository.pendingPurges();
      for (final ({String mistakeId, String photoPath}) p in pending) {
        try {
          await moderationRepository.purgePhoto(p.mistakeId, p.photoPath);
        } catch (e, st) {
          // Tek tek başarısızlık akışı durdurmasın; sayaç aşağıda gösterilecek.
          unawaited(reportError(e, st, context: 'admin.purgePhoto'));
        }
      }
      final List<({String mistakeId, String photoPath})> left =
          await moderationRepository.pendingPurges();
      if (!mounted) return;
      setState(() => _pendingPurges = left.length);
    } catch (e, st) {
      // Moderatör değilse ya da ağ yoksa sessizce geç: bu ekranın asıl işi
      // şikayet kuyruğu, temizlik ikincil. İz yine de bırakılıyor.
      unawaited(reportError(e, st, context: 'admin.pendingPurges'));
    }
  }

  Future<void> _decide(PendingReport r, {required bool remove}) async {
    if (_busy.contains(r.reportId)) return;
    setState(() => _busy.add(r.reportId));
    try {
      await moderationRepository.decide(r.reportId, remove: remove);
      if (remove) {
        // Karar 'removed' yazdı: artık yeni imzalı adres üretilemiyor, ama
        // dağıtılmış olanlar ömürleri boyunca çalışır. Dosyanın kendisini de
        // sil (Değişmez 3). Başarısız olursa satır admin_photo_purge_queue()
        // kuyruğunda kalır.
        await moderationRepository.purgePhoto(r.mistakeId, r.photoPath);
      }
      if (!mounted) return;
      setState(() => _items.removeWhere(
          (PendingReport x) => x.reportId == r.reportId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(remove
              ? 'İçerik yayından kaldırıldı.'
              : 'Şikayet reddedildi, soru geri döndü.'),
          backgroundColor: remove ? AppColors.red : AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem tamamlanamadı.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(r.reportId));
    }
  }

  /// Şüpheli fotoğraf kararı. `clear` = yanlış pozitif → paylaşım açılır.
  Future<void> _decideFlagged(FlaggedPhoto f, {required bool clear}) async {
    if (_busy.contains(f.mistakeId)) return;
    setState(() => _busy.add(f.mistakeId));
    try {
      await moderationRepository.reviewPhotoScan(f.mistakeId, clear: clear);
      if (!clear) {
        // Kaldırma mevcut purge değişmezine akar: dosya da silinmeli.
        await moderationRepository.purgePhoto(f.mistakeId, f.photoPath);
      }
      if (!mounted) return;
      setState(() => _flagged
          .removeWhere((FlaggedPhoto x) => x.mistakeId == f.mistakeId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(clear
              ? 'Temiz işaretlendi; paylaşım açıldı.'
              : 'İçerik yayından kaldırıldı.'),
          backgroundColor: clear ? AppColors.green : AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem tamamlanamadı.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(f.mistakeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_items.isEmpty && _flagged.isEmpty
            ? 'Moderasyon'
            : 'Moderasyon (${_items.length + _flagged.length})'),
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
          if (_pendingPurges > 0) _purgeWarning(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  /// Kaldırıldığı hâlde dosyası silinemeyen içerikler. Sessizce geçmiyoruz:
  /// bu satırlar dururken "kaldırıldı" tam olarak doğru değil — eski imzalı
  /// adresler ömürleri boyunca çalışmaya devam eder.
  Widget _purgeWarning() {
    return Container(
      width: double.infinity,
      color: AppColors.red.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cleaning_services_outlined,
              size: 18, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_pendingPurges kaldırılmış içeriğin fotoğrafı hâlâ silinemedi.',
              style: const TextStyle(fontSize: 13, color: AppColors.red),
            ),
          ),
          TextButton(
            onPressed: _retryPurges,
            child: const Text('Tekrar dene'),
          ),
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
            Text(_error!, style: const TextStyle(color: AppColors.inkLight)),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    if (_items.isEmpty && _flagged.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('✅', style: TextStyle(fontSize: 52)),
              SizedBox(height: 14),
              Text('Bekleyen şikayet ya da şüpheli fotoğraf yok.',
                  style: TextStyle(color: AppColors.inkLight, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        // Makine kuyruğu şikâyetlerin ÜSTÜNDE: kimse şikâyet etmeden yakalandı
        // ve paylaşımı sunucu zaten kapattı; karar bekleyen tarafı bu.
        for (final FlaggedPhoto f in _flagged) _flaggedCard(f),
        for (final PendingReport r in _items) _card(r),
      ],
    );
  }

  Widget _flaggedCard(FlaggedPhoto f) {
    final bool busy = _busy.contains(f.mistakeId);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.red.withValues(alpha: 0.40), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Text('Makine taraması: şüpheli içerik',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.red)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${f.subject} · ${f.concept}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                if (f.photoPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: MistakePhoto(path: f.photoPath!),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            busy ? null : () => _decideFlagged(f, clear: true),
                        child: const Text('Temiz — paylaşımı aç'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red),
                        onPressed:
                            busy ? null : () => _decideFlagged(f, clear: false),
                        child: const Text('Kaldır'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(PendingReport r) {
    final bool busy = _busy.contains(r.reportId);
    final Color color = r.reason.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Sebep başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: <Widget>[
                Icon(r.reason.icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.reason.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: color)),
                ),
                if (r.reason.isSafety)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('ACİL',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10)),
                  ),
                const SizedBox(width: 6),
                Text('${r.reportCount} bildirim',
                    style: const TextStyle(
                        color: AppColors.inkLight, fontSize: 11.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (r.photoPath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: MistakePhoto(
                              path: r.photoPath!, fit: BoxFit.cover),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${r.subject} · ${r.concept}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text('Sahibi: ${r.ownerNickname}',
                              style: const TextStyle(
                                  color: AppColors.inkLight, fontSize: 12)),
                          if (r.note != null && r.note!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text('“${r.note}”',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.ink)),
                          ],
                          if (r.options.isNotEmpty &&
                              r.correctIndex != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              'Doğru şık: '
                              '${r.options[r.correctIndex!.clamp(0, r.options.length - 1)].label}',
                              style: const TextStyle(
                                  color: AppColors.inkLight, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                else
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _decide(r, remove: false),
                          icon: const Icon(Icons.undo_rounded,
                              size: 18, color: AppColors.green),
                          label: const Text('Haksız, geri al',
                              style: TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            side: const BorderSide(color: AppColors.green),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _decide(r, remove: true),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: const Text('Kaldır',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

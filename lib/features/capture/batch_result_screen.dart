import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/daily_state_repository.dart';
import '../../data/photo_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../state/refresh_bus.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import 'confirm_screen.dart';

/// Parti sonuç ekranı — KARMA ONAY (Tur 7 · n4).
///
/// Tasarımın akış kararı aynen: "analiz bitince TEK LİSTE açılır, AI'ın
/// çıkardığı konular hazır işaretlidir; 'Hepsini onayla' tek dokunuş, şüpheli
/// satıra dokununca tekli onay ekranı açılır."
///
/// ÜÇ DAVRANIŞ KURALI:
///
/// 1. **Başarısız fotoğraf akışı DURDURMUYOR.** Bal rengi satıra düşüyor,
///    kaydediliyor, konusunu öğrenci yazıyor. Kuyruğun `needsUser` durumu tam
///    bu; yeni bir durum icat edilmiyor.
///
/// 2. **Hak parti ortasında biterse kayıtlar `needsAnalysis` KALIYOR.** Eski
///    davranış onları sessizce `needsUser`a düşürüyordu — yani kullanıcı 10
///    kare çekip 3 sonuç alıyor ve kalan 7'yi elle doldurması gerektiğini
///    kimse söylemiyordu. Şimdi üstte "kalan N fotoğraf hakkın dönünce
///    okunacak" satırı çıkıyor.
///
/// 3. **İLERLEME BELİRLENİMLİ.** Belirsiz spinner yok: "6 tamam · 1 sırada ·
///    1 okunamadı" ve halka. Sonuçlar tamamlandıkça akıyor.
class BatchResultScreen extends StatefulWidget {
  const BatchResultScreen({super.key, required this.batchId});

  final String batchId;

  @override
  State<BatchResultScreen> createState() => _BatchResultScreenState();
}

class _BatchResultScreenState extends State<BatchResultScreen> {
  List<PendingPhoto> _rows = <PendingPhoto>[];
  DailyState? _state;
  bool _working = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    unawaited(_drain());
    // Kuyruk işlerken listeyi tazeliyoruz: `flush()` sırayla ilerliyor ve
    // sonuçlar TAMAMLANDIKÇA görünmeli.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final List<PendingPhoto> all = await photoQueue.list();
    final DailyState? s = await dailyStateRepository.read();
    if (!mounted) return;
    setState(() {
      _rows = all.where((PendingPhoto p) => p.batchId == widget.batchId).toList();
      if (s != null) _state = s;
    });
    // Parti bittiyse yoklamayı bırak.
    if (_rows.every((PendingPhoto p) => p.state != PhotoQueueState.needsAnalysis)) {
      _poll?.cancel();
    }
  }

  /// Kuyruğu boşaltır. İŞLEMEYİ BU EKRAN YAPMIYOR: `flush()` sıra, hata
  /// sınıflandırma ve yeniden deneme kararlarının tek sahibi.
  Future<void> _drain() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await photoQueue.flush();
    } catch (e) {
      debugPrint('parti işlenemedi: $e');
    } finally {
      if (mounted) {
        setState(() => _working = false);
        await _refresh();
      }
    }
  }

  int get _done =>
      _rows.where((PendingPhoto p) => p.state == PhotoQueueState.ready).length;

  int get _queued => _rows
      .where((PendingPhoto p) => p.state == PhotoQueueState.needsAnalysis)
      .length;

  /// Okunamayanlar: analiz çalıştı ama konu/şık eksik kaldı.
  int get _failed =>
      _rows.where((PendingPhoto p) => p.state == PhotoQueueState.needsUser).length;

  /// Kota parti ortasında bitti mi.
  bool get _creditPaused =>
      _queued > 0 && (_state?.aiState?.hasCredit == false);

  Future<void> _openRow(PendingPhoto p) async {
    sound.tap();
    final Map<String, dynamic>? fields = await photoQueue.entry(p.id);
    final Uint8List? bytes = await photoQueue.bytesOf(p.id);
    if (!mounted) return;
    await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ConfirmMistakeScreen(
          imageBytes: bytes,
          queueEntryId: p.id,
          initialFields: fields,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  /// "Hepsini onayla": hazır olanları gönderir.
  ///
  /// AI'ın çıkardığı konular ZATEN kayıtta; `ready` durumu "eksiksiz" demek.
  /// Eksik kalanlar (`needsUser`) bu düğmeyle GİTMİYOR — onlar kullanıcının
  /// bir alan doldurmasını bekliyor ve tasarım bunu satırda söylüyor.
  Future<void> _approveAll() async {
    await _drain();
    if (!mounted) return;
    refreshBus.ping();
    if (_rows.isEmpty && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final int total = _rows.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.batchTitle(total)),
        leading: IconButton(
          icon: KimoIcon(KimoIcons.close, size: 20, color: c.ink),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l.actionCancel,
        ),
      ),
      body: total == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.screen),
                child: EmptyState(message: l.batchSafeNote),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.md, Gap.screen, Gap.section),
              children: <Widget>[
                _progress(context, l, t, c, total),
                if (_creditPaused) ...<Widget>[
                  const SizedBox(height: Gap.md),
                  KimoCard(
                    radius: Radii.tile,
                    color: c.honeyTint,
                    padding: const EdgeInsets.all(Gap.md),
                    child: Text(
                      l.batchCreditPaused(_queued),
                      style: t.caption.copyWith(color: c.honeyText),
                    ),
                  ),
                ],
                const SizedBox(height: Gap.xl),
                SectionHeader(title: l.batchExtracted),
                const SizedBox(height: Gap.md),
                for (int i = 0; i < _rows.length; i++) ...<Widget>[
                  _row(context, l, t, c, _rows[i], i + 1),
                  const SizedBox(height: Gap.sm),
                ],
                const SizedBox(height: Gap.md),
                Text(l.batchSafeNote,
                    style: t.caption.copyWith(color: c.inkMuted)),
              ],
            ),
      bottomNavigationBar: total == 0
          ? null
          : Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(
                Gap.screen,
                Gap.md,
                Gap.screen,
                Gap.md + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  KimoButton(
                    label: l.batchApproveAll(total),
                    onPressed: _working ? null : () => unawaited(_approveAll()),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(l.batchTapRowHint,
                      style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
    );
  }

  Widget _progress(BuildContext context, L10n l, KimoTypography t,
      KimoColors c, int total) {
    return KimoCard(
      radius: Radii.card,
      padding: const EdgeInsets.all(Gap.screen),
      child: Row(
        children: <Widget>[
          // BELİRLENİMLİ halka: belirsiz spinner yok.
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CircularProgressIndicator(
                  value: total == 0 ? 0 : (_done + _failed) / total,
                  strokeWidth: 5,
                ),
                Text('${_done + _failed}/$total', style: t.caption),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.batchReading, style: t.bodyStrong),
                const SizedBox(height: Gap.xxs),
                Text(
                  l.batchProgress(_done, _queued, _failed),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, L10n l, KimoTypography t, KimoColors c,
      PendingPhoto p, int index) {
    final bool waiting = p.state == PhotoQueueState.needsAnalysis;
    final bool needsUser = p.state == PhotoQueueState.needsUser;
    return KimoCard(
      radius: Radii.tile,
      // BAL RENGİ: okunamayan satır. Kırmızı KULLANILMIYOR — hata değil,
      // kullanıcının bir alan doldurması gereken bir durum.
      color: needsUser ? c.honeyTint : c.card,
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.md, vertical: Gap.md),
      onTap: waiting ? null : () => unawaited(_openRow(p)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  waiting
                      ? l.batchRowReading
                      : (p.concept ?? l.batchRowNoTopic),
                  style: t.label.copyWith(
                      color: needsUser ? c.honeyText : c.ink),
                ),
                Text(
                  // İADE KULLANICIYA SÖYLENİYOR (0083 + Task 13). Sunucu hakkı
                  // okunamayan fotoğraflar için geri veriyor ve ürün kuralı
                  // (Tur 7 · n4) bunu bir TAAHHÜT olarak yazıyor: "hak sayımı
                  // yalnızca okunabilen fotoğraflar için düşer". Bu satıra
                  // kadar taahhüt hiçbir yerde GÖRÜNMÜYORDU — `refunded`
                  // modele kadar geliyor ve hiçbir ekran okumuyordu.
                  waiting
                      ? l.batchRowIndex(index)
                      : (p.refunded
                          ? l.batchRefunded
                          : (p.subject ?? l.batchRowNoTopicHint)),
                  style: t.caption.copyWith(
                      color: needsUser ? c.honeyText : c.inkMuted),
                ),
              ],
            ),
          ),
          if (needsUser)
            Text(l.batchRowFix,
                style: t.captionStrong.copyWith(color: c.honeyText))
          else if (waiting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            KimoIcon(KimoIcons.check, size: 18, color: c.mintText),
        ],
      ),
    );
  }
}

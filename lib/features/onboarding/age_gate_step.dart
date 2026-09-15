import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/daily_state_repository.dart';
import '../../data/photo_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/legal_links.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Yaş kapısı.
///
/// **Yalnızca doğum YILI toplanıyor.** Tam doğum tarihi gereğinden fazla
/// kişisel veri ve yaş sınırını uygulamak için gerekmiyor. Yıl bir kez
/// yazılıyor (`set_birth_year` ikinci çağrıyı reddediyor).
///
/// Reşitlik SAKLANMIYOR, türetiliyor (`is_minor_now`). Bir sonraki doğum günü
/// geldiğinde kimsenin bir alanı güncellemesi gerekmiyor.
///
/// **TASK 07 — iki değişiklik.**
///
/// 1. Veli onayı kaldırıldı. 13-17 yaş için hukuken zorunlu değil ve mekanizma
///    zaten hiç çalışmamıştı (onay bağlantısındaki parametre adı uyuşmuyordu).
///    Yaş artık HİÇBİR özelliği kapatmıyor; yalnızca 13 sınırı için soruluyor.
///
/// 2. 13 yaş alt sınırı sunucuda zorlanıyor. Çark aralığı BİLEREK
///    daraltılmadı: yalnızca geçerli yılları göstermek kapıyı ortadan
///    kaldırırdı — kullanıcı reddedilmez, sadece yalan söylerdi. Nötr yaş
///    kapısının davranışı budur: yıl serbestçe girilir, sunucu reddeder ve
///    kullanıcı NEDEN reddedildiğini öğrenir.
///
/// Reddedilen deneme bir YAZMA değil, dolayısıyla hesap kilitlenmiyor;
/// kullanıcı tek yazımlık hakkını da kaybetmiyor.
class AgeGateStep extends StatefulWidget {
  const AgeGateStep({
    super.key,
    required this.status,
    required this.onChanged,
  });

  /// Sunucudan okunan güncel durum. `null` = henüz okunmadı.
  final AgeStatus? status;

  /// Yıl kaydedildiğinde akış yeniden okusun diye.
  final Future<void> Function() onChanged;

  @override
  State<AgeGateStep> createState() => _AgeGateStepState();
}

class _AgeGateStepState extends State<AgeGateStep> {
  int? _year;
  bool _saving = false;

  /// 13 yaşından küçük olduğu için reddedildi. Ekranda nazik açıklama çıkıyor.
  bool _tooYoung = false;

  /// Yaş kapısının kapsadığı aralık. Alt sınır 1990: daha eskisi bu üründe
  /// gerçekçi değil ve uzun bir çark kaydırmayı zorlaştırıyor.
  static const int _minYear = 1990;

  int get _maxYear => DateTime.now().year;

  bool get _yearSet => widget.status?.birthYearSet ?? false;

  // 13 SINIRININ İSTEMCİ KOPYASI YOK — bilinçli. Kotada olduğu gibi: sınırın
  // iki yerde yaşaması, birinin sessizce eskimesi demek. Çark her yılı
  // gösteriyor, kararı `set_birth_year` veriyor ve reddini AYRI bir SQLSTATE
  // ile bildiriyor; buradaki tek iş o cevabı nazik bir ekrana çevirmek.

  Future<void> _saveYear() async {
    final int? y = _year;
    if (y == null || _saving) return;
    final L10n l = L10n.of(context);
    setState(() {
      _saving = true;
      _tooYoung = false;
    });
    try {
      await dailyStateRepository.setBirthYear(y);
      // YAŞ KAPISI AÇILDI (A-2): ilk çekimde kuyruğa alınan fotoğraf artık
      // analiz edilebilir. `flush` bilinçli ateşle-unut — kullanıcı sonraki
      // adıma geçerken analiz arkada çalışıyor; sonucu "tamamlanmayı
      // bekliyor" olarak bulacak.
      await photoQueue.releaseAgeGate();
      unawaited(photoQueue.flush());
      await widget.onChanged();
    } on PostgrestException catch (e) {
      // Sunucu 13 sınırını AYRI bir SQLSTATE ile bildiriyor: "geçersiz yıl"
      // ile "çok küçüksün" iki farklı ekran gerektiriyor.
      if (e.code == DailyStateRepository.tooYoungCode) {
        // 13 ALTI REDDEDİLDİ: bekleyen fotoğraf hiç analiz edilmemeli ve
        // hiçbir yerde bırakılmamalı. Depoya zaten yüklenmedi; silinecek tek
        // kopya cihazdaki dosya.
        await photoQueue.purgeAgeGated();
        if (mounted) setState(() => _tooYoung = true);
      } else {
        debugPrint('doğum yılı kaydedilemedi: $e');
        if (mounted) _snack(l.ageSaveFailed);
      }
    } catch (e) {
      debugPrint('doğum yılı kaydedilemedi: $e');
      if (mounted) _snack(l.ageSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        Text(l.ageTitle, style: t.title),
        const SizedBox(height: Gap.sm),
        Text(l.ageBody, style: t.body.copyWith(color: c.inkSecondary)),
        const SizedBox(height: Gap.lg),

        if (_yearSet)
          Row(
            children: <Widget>[
              StatusBadge(
                label: l.ageWriteOnceNote,
                tone: BadgeTone.mastered,
              ),
            ],
          )
        else ...<Widget>[
          _yearWheel(context),
          const SizedBox(height: Gap.sm),
          Text(
            l.ageWriteOnceNote,
            style: t.caption.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.md),
          KimoButton(
            label: l.actionSave,
            expand: false,
            minHeight: Sizes.rowMin,
            onPressed: (_year == null || _saving) ? null : _saveYear,
          ),
          if (_tooYoung) ...<Widget>[
            const SizedBox(height: Gap.lg),
            _tooYoungCard(context, l),
          ],
        ],
      ],
    );
  }

  /// 13 yaş altı reddi. Suçlayıcı DEĞİL: kullanıcı yanlış bir şey yapmadı,
  /// yalnızca ürün ona uygun değil. Kapı kapanmıyor — büyüyünce dönebilir.
  Widget _tooYoungCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      color: c.honeyTint,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.ageTooYoungTitle,
            style: t.bodyStrong.copyWith(color: c.honeyText),
          ),
          const SizedBox(height: Gap.xs),
          Text(l.ageTooYoungBody, style: t.caption),
          // İLETİŞİM YOLU (Task 14 · G2). Gövde metni "bir yanlışlık olduğunu
          // düşünüyorsan bize yazabilirsin" diyordu ama kart yalnızca başlık
          // ve gövde çiziyordu: reddedilen kullanıcı çıkmaz bir ekranda kalıp
          // yazacak bir yer bulamıyordu. Biçim `suspended_screen`in itiraz
          // yoluyla aynı — adres yoksa sessizce kaybolmuyor, söyleniyor.
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.ageTooYoungContact,
            kind: KimoButtonKind.tertiary,
            onPressed: () => _contactSupport(context, l),
          ),
        ],
      ),
    );
  }

  /// Yaş reddine itiraz e-postası.
  Future<void> _contactSupport(BuildContext context, L10n l) async {
    sound.tap();
    if (!LegalLinks.has(LegalLinks.supportEmail)) {
      _snack(l.ageTooYoungContactUnavailable);
      return;
    }
    final Uri mail = Uri(
      scheme: 'mailto',
      path: LegalLinks.supportEmail.trim(),
      queryParameters: const <String, String>{
        'subject': 'Kimo — yaş sınırı itirazı',
      },
    );
    final bool ok = await openLegalUrl(mail.toString());
    if (!ok && mounted) _snack(l.ageTooYoungContactUnavailable);
  }

  Widget _yearWheel(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final List<int> years = <int>[
      for (int y = _maxYear; y >= _minYear; y--) y,
    ];
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: Radii.all(Radii.card),
      ),
      child: ListWheelScrollView.useDelegate(
        itemExtent: 44,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (int i) {
          sound.tap();
          setState(() {
            _year = years[i];
            _tooYoung = false;
          });
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: years.length,
          builder: (BuildContext ctx, int i) => Center(
            child: Text(
              '${years[i]}',
              style: years[i] == _year
                  ? t.numberLarge.copyWith(color: c.actionText)
                  : t.numberMedium.copyWith(color: c.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}

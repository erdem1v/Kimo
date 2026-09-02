import 'package:flutter/material.dart';

import '../../data/daily_state_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// 3b — Yaş kapısı.
///
/// **Yalnızca doğum YILI toplanıyor.** Tam doğum tarihi gereğinden fazla
/// kişisel veri ve yaş sınırını uygulamak için gerekmiyor. Yıl bir kez
/// yazılıyor (`set_birth_year` ikinci çağrıyı `22023` ile reddediyor): 18 altı
/// bir kullanıcının kısıtı aşmak için yılı değiştirmesini engelliyor.
///
/// Reşitlik SAKLANMIYOR, türetiliyor (`is_minor_now`). Bir sonraki doğum günü
/// geldiğinde kimsenin bir alanı güncellemesi gerekmiyor.
///
/// Veli onayı **yalnızca arkadaş eklemeyi** kapatıyor. Kaydetme, tekrar, lig,
/// gelen kutusu — hepsi açık. Onay beklemek bir ceza değil; kapatılan tek şey
/// tanımadığın biriyle temas kurma yolu.
class AgeGateStep extends StatefulWidget {
  const AgeGateStep({
    super.key,
    required this.status,
    required this.onChanged,
  });

  /// Sunucudan okunan güncel durum. `null` = henüz okunmadı.
  final GuardianStatus? status;

  /// Yıl ya da onay durumu değiştiğinde akış yeniden okusun diye.
  final Future<void> Function() onChanged;

  @override
  State<AgeGateStep> createState() => _AgeGateStepState();
}

class _AgeGateStepState extends State<AgeGateStep> {
  final TextEditingController _email = TextEditingController();

  int? _year;
  bool _savingYear = false;
  bool _sending = false;

  /// Yaş kapısının kapsadığı aralık. Alt sınır 1990: daha eskisi bu üründe
  /// gerçekçi değil ve uzun bir çark kaydırmayı zorlaştırıyor.
  static const int _minYear = 1990;

  int get _maxYear => DateTime.now().year;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Girilen yıla göre reşit mi. Sunucu da aynı hesabı yapıyor
  /// (`is_minor_now`); buradaki yalnızca formu şekillendiriyor.
  bool get _minorByInput {
    final int? y = _year;
    if (y == null) return false;
    return _maxYear - y < 18;
  }

  bool get _minor => widget.status?.isMinor ?? _minorByInput;
  bool get _yearSet => widget.status?.birthYearSet ?? false;

  Future<void> _saveYear() async {
    final int? y = _year;
    if (y == null || _savingYear) return;
    final L10n l = L10n.of(context);
    setState(() => _savingYear = true);
    try {
      await dailyStateRepository.setBirthYear(y);
      await widget.onChanged();
    } catch (e) {
      debugPrint('doğum yılı kaydedilemedi: $e');
      if (mounted) _snack(l.ageSaveFailed);
    } finally {
      if (mounted) setState(() => _savingYear = false);
    }
  }

  Future<void> _sendGuardian() async {
    final String email = _email.text.trim();
    final L10n l = L10n.of(context);
    if (!_looksLikeEmail(email)) {
      _snack(l.ageGuardianInvalid);
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await dailyStateRepository.requestGuardianConsent(email);
      await widget.onChanged();
      if (mounted) _snack(l.ageGuardianSent);
    } catch (e) {
      debugPrint('veli onayı istenemedi: $e');
      if (mounted) _snack(l.ageGuardianFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Kaba biçim kontrolü. Adresin GERÇEK olup olmadığını yalnızca gönderilen
  /// e-postanın tıklanması kanıtlıyor; burada amaç bariz yazım hatasını
  /// kullanıcıya erken söylemek.
  static bool _looksLikeEmail(String v) {
    final int at = v.indexOf('@');
    final int dot = v.lastIndexOf('.');
    return at > 0 && dot > at + 1 && dot < v.length - 1 && !v.contains(' ');
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
                label: _minor ? l.guardianStatusMinor : l.ageWriteOnceNote,
                tone: _minor ? BadgeTone.pending : BadgeTone.mastered,
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
            onPressed: (_year == null || _savingYear) ? null : _saveYear,
          ),
        ],

        if (_yearSet && _minor) ...<Widget>[
          const SizedBox(height: Gap.xl),
          _guardianCard(context, l),
        ],
      ],
    );
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
          setState(() => _year = years[i]);
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

  Widget _guardianCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final GuardianStatus? s = widget.status;
    final bool granted = s?.consentGranted ?? false;
    final bool pending = !granted && (s?.guardianEmail != null);

    return KimoCard(
      color: granted ? c.mintTint : c.honeyTint,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.ageMinorTitle,
            style: t.bodyStrong.copyWith(
              color: granted ? c.mintText : c.honeyText,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(l.ageMinorBody, style: t.caption),
          const SizedBox(height: Gap.md),
          if (granted)
            StatusBadge(label: l.ageGuardianGranted, tone: BadgeTone.mastered)
          else ...<Widget>[
            if (pending) ...<Widget>[
              StatusBadge(
                label: l.ageGuardianPending,
                tone: BadgeTone.pending,
              ),
              const SizedBox(height: Gap.md),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: t.body,
              decoration: InputDecoration(
                hintText: l.ageGuardianHint,
                filled: true,
                fillColor: c.card,
                border: OutlineInputBorder(
                  borderRadius: Radii.all(Radii.tile),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendGuardian(),
            ),
            const SizedBox(height: Gap.sm),
            KimoButton(
              label: l.ageGuardianSend,
              minHeight: Sizes.rowMin,
              onPressed: _sending ? null : _sendGuardian,
            ),
          ],
        ],
      ),
    );
  }
}

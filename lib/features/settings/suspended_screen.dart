import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/sanction_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/legal_links.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Askıya alınan ya da yasaklanan kullanıcının gördüğü ekran.
///
/// **Tasarım ilkesi: suçlama yok, tarih ve yol var.** Üç şeyi bu sırayla
/// söylüyor:
///   1. NE kapandı (paylaşım ve gönderme) — belirsizlik bırakmadan;
///   2. neyin AÇIK kaldığı (arşiv, tekrar, lig) — ceza uygulamadan atmak değil;
///   3. İTİRAZ yolu — kararı otomatik bir sınıflandırıcı vermiş olabilir ve
///      onun insan incelemesine açık olması zorunlu.
///
/// Sunucudan gelen `reason_code` KAPALI BİR KÜME (photo_repeat/abuse/spam/
/// other) ve doğrudan gösterilmiyor; burada yerelleştirilmiş bir cümleye
/// çevriliyor. Serbest metin gösterseydik, sunucuya erişen birinin
/// kullanıcıya istediği cümleyi okutmasının yolu açılırdı — `analyze-question`
/// içinde aynı gerekçeyle `reason_code` enum'una geçilmişti.
///
/// Ekran KAPATILAMAZ bir duvar değil: "Uygulamaya dön" ile arşive geçiliyor.
/// Askı okuma yollarını kapatmıyor; kapattığı tek şey üretim.
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({
    super.key,
    required this.status,
    required this.onContinue,
  });

  final SanctionStatus status;
  final VoidCallback onContinue;

  bool get _permanent => status.kind == SanctionKind.permanent;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Gap.screen, Gap.section, Gap.screen, Gap.md),
                children: <Widget>[
                  KimoIcon(KimoIcons.lock, size: 40, color: c.inkMuted),
                  const SizedBox(height: Gap.lg),
                  Text(
                    _permanent ? l.suspendedTitlePermanent : l.suspendedTitle,
                    style: t.title,
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    l.suspendedWhat,
                    style: t.body.copyWith(color: c.inkSecondary),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(_untilLine(l), style: t.bodyStrong),
                  const SizedBox(height: Gap.lg),
                  KimoCard(
                    color: c.mintTint,
                    elevated: false,
                    child: Text(l.suspendedStillOpen, style: t.body),
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(
                    _reasonLine(l),
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.md, Gap.screen, Gap.screen),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  KimoButton(
                    label: l.suspendedAppeal,
                    onPressed: () => _appeal(context, l),
                  ),
                  const SizedBox(height: Gap.sm),
                  KimoButton(
                    label: l.suspendedContinue,
                    kind: KimoButtonKind.tertiary,
                    onPressed: () {
                      sound.tap();
                      onContinue();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kalıcı yasakta "süresiz" denmiyor, tarih de uydurulmuyor: bitiş yoksa
  /// bunu açıkça söylemek, boş bir alan bırakmaktan dürüst.
  String _untilLine(L10n l) {
    final DateTime? until = status.until;
    if (_permanent || until == null) return l.suspendedNoEnd;
    final String d = '${until.day.toString().padLeft(2, '0')}.'
        '${until.month.toString().padLeft(2, '0')}.${until.year}';
    return l.suspendedUntil(d);
  }

  String _reasonLine(L10n l) => status.reasonCode == 'photo_repeat'
      ? l.suspendedReasonPhoto
      : l.suspendedReasonOther;

  /// İtiraz e-postası. Adres verilmemişse sessizce kaybolmuyor — kullanıcıya
  /// söyleniyor, çünkü itiraz yolunun yokluğu ekranın tek gerçek eksiği olurdu.
  Future<void> _appeal(BuildContext context, L10n l) async {
    sound.tap();
    if (!LegalLinks.has(LegalLinks.supportEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.suspendedAppealUnavailable)),
      );
      return;
    }
    final Uri mail = Uri(
      scheme: 'mailto',
      path: LegalLinks.supportEmail.trim(),
      queryParameters: <String, String>{
        'subject': 'Kimo — hesap kısıtlaması itirazı',
      },
    );
    final bool ok = await openLegalUrl(mail.toString());
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.suspendedAppealUnavailable)),
      );
    }
  }
}

/// İçerik ihlali uyarısı. Kademeli yaptırımın kullanıcıya bakan yüzü.
///
/// Bugüne kadar şüpheli işaretlenen bir fotoğraf SESSİZCE paylaşımdan
/// düşüyordu: kullanıcı ne olduğunu asla öğrenmiyordu. Sertlik `strike_no`dan
/// geliyor — güncel sayaçtan değil — çünkü gösterilen metin uyarının yazıldığı
/// ana ait olmalı.
///
/// Gösterildikten sonra `ack_photo_warnings` çağrılıyor; o çağrı SAYACA
/// dokunmuyor (sunucuda da dokunamaz), yalnızca aynı uyarının her açılışta
/// tekrar çıkmasını önlüyor.
Future<void> showPhotoWarning(
  BuildContext context,
  PhotoWarning warning,
) async {
  final L10n l = L10n.of(context);
  final KimoColors c = context.c;
  final KimoTypography t = context.t;

  final (String, String) copy = switch (warning.tone) {
    WarningTone.gentle => (l.warningTitleGentle, l.warningBodyGentle),
    WarningTone.firm => (l.warningTitleFirm, l.warningBodyFirm),
    WarningTone.suspended => (l.warningTitleSuspended, l.warningBodySuspended),
  };

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.card,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (BuildContext ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.lg, Gap.screen, Gap.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(copy.$1, style: t.section),
          const SizedBox(height: Gap.sm),
          Text(copy.$2, style: t.body.copyWith(color: c.inkSecondary)),
          const SizedBox(height: Gap.xl),
          KimoButton(
            label: l.warningAction,
            onPressed: () {
              sound.tap();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    ),
  );

  unawaited(sanctionRepository.acknowledgeWarnings());
}

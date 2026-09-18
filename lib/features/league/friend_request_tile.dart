import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/social.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';

/// Gelen arkadaşlık isteği satırı.
///
/// İKİ SIRA (Task 18 turu). Üç düğme tek `Row`da eşit bölüşüyordu; 393pt
/// genişlikte her birine ~105pt düşüyor ve "Kabul et" `KimoButton`un yatay
/// dolgusuyla İKİ SATIRA kırılıyordu — ana eylem, üçünün en kötü görüneniydi.
/// Şimdi ana eylem tam genişlikte, "Reddet" ve "Engelle" altında yan yana:
/// 375pt (SE) dâhil hiçbir genişlikte etiket kırılmıyor ve düğme sırası
/// eylemin ağırlığını da söylüyor.
///
/// Ayrı dosya: `FriendsView` yedi depo çağrısıyla yükleniyor ve dikişsiz;
/// satırın yerleşimi bu sınıfla tek başına test ediliyor
/// (`friend_request_tile_test`).
class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.profile,
    required this.mutual,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
  });

  final PublicProfile profile;

  /// Ortak arkadaş sayısı; 0 ise satır çizilmiyor.
  final int mutual;

  /// İşlem sürerken üç düğme de kilitli.
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return KimoCard(
      padding: const EdgeInsets.all(Gap.md),
      radius: Radii.tile,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(
                name: profile.nickname,
                avatarPath: profile.avatarPath,
                size: 40,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(profile.nickname, style: t.label),
                    if (mutual > 0)
                      Text(
                        l.friendsMutual(mutual),
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          // İKİNCİL: bekleyen istek başına bir tane çiziliyor. Üç istekte,
          // "Ekle" ile birlikte dört birincil düğme aynı ekranda duruyordu.
          KimoButton(
            label: l.friendsAccept,
            kind: KimoButtonKind.secondary,
            minHeight: Sizes.rowMin,
            onPressed: busy ? null : onAccept,
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: <Widget>[
              // REDDET (Task 16). Gelen istekte yalnızca "Kabul et" ve
              // "Engelle" vardı: hayır demenin tek yolu karşı tarafı
              // ENGELLEMEKTİ. Engelleme çok daha ağır bir eylem — lig
              // tahtasında maskeliyor, bütün sosyal yüzeyleri kapatıyor ve
              // kullanıcının kendi "Engellenen kişiler" listesini şişiriyor.
              Expanded(
                child: KimoButton(
                  label: l.friendsDecline,
                  kind: KimoButtonKind.tertiary,
                  minHeight: Sizes.rowMin,
                  onPressed: busy ? null : onDecline,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: KimoButton(
                  label: l.friendsBlock,
                  kind: KimoButtonKind.tertiary,
                  minHeight: Sizes.rowMin,
                  onPressed: busy ? null : onBlock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Kart yüzeyi. Gölge tek katman ve sert: `0 2px 0`. Blur kullanılmaz —
/// tasarım dilinde yükseklik yumuşak gölgeyle değil, kalın bir alt çizgiyle
/// kuruluyor.
class KimoCard extends StatelessWidget {
  const KimoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.radius = Radii.card,
    this.color,
    this.onTap,
    this.border,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Varsayılan kart yüzeyi dışında bir zemin (ör. `actionTint`).
  final Color? color;

  final VoidCallback? onTap;

  /// Kenar çizgisi; verilmezse çizilmez.
  final Color? border;

  /// Aksan zeminli bilgi kartlarında gölge yok — tint zaten yükseklik taşıyor.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: Radii.all(radius),
        border: border == null ? null : Border.all(color: border!),
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(color: c.cardShadow, offset: const Offset(0, 2)),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}

/// Bölüm başlığı: solda ad, sağda isteğe bağlı sayaç/eylem.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final KimoTypography t = context.t;
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: t.bodyStrong)),
        ?trailing,
      ],
    );
  }
}

/// Boş durum: kesikli kenar, tek cümlelik davet, tek buton.
/// Asla onay işareti göstermez — boş bir liste bir başarı değil.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.illustration,
    this.action,
  });

  final String message;
  final Widget? illustration;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: c.page,
        borderRadius: Radii.all(Radii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (illustration != null) ...<Widget>[
            illustration!,
            const SizedBox(height: Gap.lg),
          ],
          Text(message, style: t.body, textAlign: TextAlign.center),
          if (action != null) ...<Widget>[
            const SizedBox(height: Gap.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Fotoğrafları hedef genişliğe göre çözerek belleğe alan sarmalayıcı.
///
/// Soru fotoğrafları 1600px genişlikte yükleniyor; küçük bir küçük resimde
/// tam çözünürlüklü bit eşlemi tutmak düşük donanımlı Android'de doğrudan
/// bellek baskısı demek. `cacheWidth` bunu kaynağında keser.
class SizedPhoto extends StatelessWidget {
  const SizedPhoto({
    super.key,
    required this.image,
    required this.logicalWidth,
    this.fit = BoxFit.cover,
    this.height,
  });

  /// Görsel sağlayıcısı (ağ, bellek ya da dosya).
  final ImageProvider<Object> image;

  /// Widget'ın mantıksal genişliği; cihaz piksel oranıyla çarpılır.
  final double logicalWidth;

  final BoxFit fit;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int cacheWidth = (logicalWidth * dpr).round();
    return Image(
      image: ResizeImage(image, width: cacheWidth, allowUpscaling: false),
      width: logicalWidth,
      height: height,
      fit: fit,
      // Yükleme sırasında zıplamayı önlemek için sabit boyutlu bir yer tutucu.
      frameBuilder: (
        BuildContext context,
        Widget child,
        int? frame,
        bool wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return SizedBox(
          width: logicalWidth,
          height: height,
          child: ColoredBox(color: context.c.sunken),
        );
      },
    );
  }
}

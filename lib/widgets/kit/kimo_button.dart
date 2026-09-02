import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Buton türü. Tasarımda tek birincil aksiyon rengi var (mercan); ikincil ve
/// üçüncül türler renk değil ağırlık farkıyla ayrışır.
enum KimoButtonKind {
  /// Mercan zemin, altında 5px sert kabartma. Ekranda en fazla bir tane.
  primary,

  /// Çerçeveli, zeminsiz. Aynı ağırlıkta ikinci bir davet.
  secondary,

  /// Oyuk zemin, sessiz. İptal ve geri adım.
  tertiary,
}

/// Tasarımın imza butonu: düz, gömülmeyen, altında sert kabartma.
/// Basınca 4px iner ve gölge kapanır — Material dalgası kullanılmaz.
///
/// Etiket iki satıra sığar; yükseklik sabit değil, [Sizes.buttonMin] tabandır.
/// Türkçe etiketler İngilizceden %15–20 uzun olduğu için bu şart.
class KimoButton extends StatefulWidget {
  const KimoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = KimoButtonKind.primary,
    this.icon,
    this.expand = true,
    this.playTapSound = true,
    this.minHeight,
  });

  final String label;

  /// `null` ise buton devre dışıdır: soluklaşır ve dokunuşa yanıt vermez.
  final VoidCallback? onPressed;

  final KimoButtonKind kind;

  /// Etiketin solunda görünen ikon (24px ızgara, dolgusuz kontur).
  final Widget? icon;

  /// Satırı doldursun mu; `false` ise içeriği kadar yer kaplar.
  final bool expand;

  final bool playTapSound;

  final double? minHeight;

  @override
  State<KimoButton> createState() => _KimoButtonState();
}

class _KimoButtonState extends State<KimoButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  void _handleTap() {
    if (!_enabled) return;
    if (widget.playTapSound) {
      // Ateşle ve unut: ses bir sonuç taşımıyor, aksiyonu bekletmemeli.
      unawaited(sound.tap());
    }
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;

    final _ButtonSkin skin = _skinFor(widget.kind, c, enabled: _enabled);
    final double lip = skin.lip;
    // İniş mesafesi kabartmadan büyük olamaz: ikincil butonun kabartması 2px,
    // birincilin 5px. Sabit 4px iniş ikincilde negatif gölge üretirdi.
    final double drop =
        _down && _enabled ? (lip < Sizes.lipPressed ? lip : Sizes.lipPressed) : 0;
    final double restingLip = lip - drop;

    final Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          IconTheme(
            data: IconThemeData(color: skin.foreground, size: 20),
            child: widget.icon!,
          ),
          const SizedBox(width: Gap.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            // İki satıra izin var; kesme yok.
            style: t.button.copyWith(color: skin.foreground),
          ),
        ),
      ],
    );

    final Widget body = Padding(
      // Kabartma için altta yer ayrılır; basıldığında düzen kaymaz.
      padding: EdgeInsets.only(bottom: lip),
      child: Transform.translate(
        offset: Offset(0, drop),
        child: AnimatedContainer(
          duration: Motion.press,
          curve: Curves.easeOut,
          constraints: BoxConstraints(
            minHeight: widget.minHeight ?? Sizes.buttonMin,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.screen,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(
            color: skin.background,
            borderRadius: Radii.all(Radii.button),
            border: skin.border == null
                ? null
                : Border.all(color: skin.border!, width: 1.6),
            boxShadow: restingLip <= 0
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: skin.lipColor,
                      offset: Offset(0, restingLip),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    final Widget tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: _handleTap,
      child: body,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: widget.expand
          ? SizedBox(width: double.infinity, child: tappable)
          : tappable,
    );
  }
}

class _ButtonSkin {
  const _ButtonSkin({
    required this.background,
    required this.foreground,
    required this.lipColor,
    required this.lip,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color lipColor;
  final double lip;
  final Color? border;
}

_ButtonSkin _skinFor(KimoButtonKind kind, KimoColors c, {required bool enabled}) {
  switch (kind) {
    case KimoButtonKind.primary:
      return enabled
          ? _ButtonSkin(
              background: c.action,
              foreground: c.onAction,
              lipColor: c.actionShadow,
              lip: Sizes.lip,
            )
          : _ButtonSkin(
              background: c.sunken,
              foreground: c.inkMuted,
              lipColor: c.sunken,
              lip: 0,
            );
    case KimoButtonKind.secondary:
      return enabled
          ? _ButtonSkin(
              background: c.card,
              foreground: c.ink,
              lipColor: c.cardShadow,
              lip: 2,
              border: c.border,
            )
          : _ButtonSkin(
              background: c.card,
              foreground: c.inkMuted,
              lipColor: c.cardShadow,
              lip: 0,
              border: c.border,
            );
    case KimoButtonKind.tertiary:
      return _ButtonSkin(
        background: c.sunken,
        foreground: enabled ? c.inkSecondary : c.inkMuted,
        lipColor: c.sunken,
        lip: 0,
      );
  }
}

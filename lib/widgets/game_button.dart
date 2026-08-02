import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../theme/app_colors.dart';

Color _darken(Color c, [double amount = 0.16]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Duolingo tarzı, altında kalın bir "kenar" olan ve basınca içeri gömülen
/// canlı buton. Uygulamanın imza etkileşim öğesi.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.green,
    this.shadowColor,
    this.textColor = Colors.white,
    this.icon,
    this.enabled = true,
    this.expand = true,
    this.playTapSound = true,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color? shadowColor;
  final Color textColor;
  final IconData? icon;
  final bool enabled;
  final bool expand;
  final bool playTapSound;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  static const double _lip = 5;
  bool _down = false;

  void _set(bool value) {
    if (widget.enabled) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool on = widget.enabled;
    final Color color = on ? widget.color : AppColors.disabled;
    final Color shadow =
        on ? (widget.shadowColor ?? _darken(widget.color)) : const Color(0xFFCFCFCF);
    final Color textColor = on ? widget.textColor : AppColors.disabledText;

    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: on
          ? () {
              if (widget.playTapSound) sound.tap();
              widget.onPressed();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: _down ? _lip : 0, bottom: _down ? 0 : _lip),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _down
              ? null
              : <BoxShadow>[
                  BoxShadow(color: shadow, offset: const Offset(0, _lip), blurRadius: 0),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, color: textColor, size: 22),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

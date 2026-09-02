import 'package:flutter/widgets.dart';

import 'svg_path.dart';

/// Tek stilli ikon seti: 24 birimlik ızgara, yuvarlak uç, dolgusuz kontur.
/// Dolgulu olanlar yalnızca kaynak göstergeleri (alev, kalp, elmas) ve
/// oynat/onay işaretleri — tasarımda böyle tanımlı.
///
/// Yol verileri onaylanan tasarım dosyasından birebir alındı. Emoji arayüzden
/// tamamen kaldırıldığı için maskot dışındaki her simge buradan gelir.
@immutable
class KimoIconData {
  const KimoIconData(
    this.paths, {
    this.filled = false,
    this.strokeWidth = 2,
  });

  /// 24×24 ızgarada tanımlı SVG yolları.
  final List<String> paths;

  /// Dolgu mu kontur mu.
  final bool filled;

  /// Kontur kalınlığı (dolgulu ikonlarda yok sayılır).
  final double strokeWidth;
}

/// Uygulamanın ikon kataloğu.
class KimoIcons {
  const KimoIcons._();

  /// Alt sekme: Bugün.
  static const KimoIconData home = KimoIconData(<String>[
    'M4 19V9.6l8-5.6 8 5.6V19h-5.5v-6h-5v6z',
  ]);

  /// Alt sekme: Hatalarım (defter).
  static const KimoIconData notebook = KimoIconData(<String>[
    'M8 4h8a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3z',
    'M9 9.5h6',
    'M9 13.5h4',
  ]);

  /// Alt sekme: Lig (sütunlar).
  static const KimoIconData bars = KimoIconData(<String>[
    'M7 20V10',
    'M12 20V5',
    'M17 20v-7',
  ]);

  /// Alt sekme: Profil.
  static const KimoIconData person = KimoIconData(<String>[
    'M8.4 8.5a3.6 3.6 0 1 0 7.2 0a3.6 3.6 0 1 0-7.2 0',
    'M5.5 20c0-3.7 2.9-6.2 6.5-6.2s6.5 2.5 6.5 6.2',
  ]);

  /// Merkezdeki kamera düğmesi.
  static const KimoIconData camera = KimoIconData(<String>[
    'M3 8.5A2 2 0 0 1 5 6.5h2l1.2-2h7.6L17 6.5h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
    'M8.6 13a3.4 3.4 0 1 0 6.8 0a3.4 3.4 0 1 0-6.8 0',
  ]);

  /// Seri (alev) — dolgulu.
  static const KimoIconData flame = KimoIconData(
    <String>[
      'M12 2c1 3.5-1.5 4.8-1.5 7 0 1.2.8 2 1.8 2 1.4 0 2.2-1.2 2.2-2.8 2 1.8 3.5 4 3.5 6.6 0 3.7-3 6.2-6.3 6.2S5.5 18.6 5.5 15c0-4.6 4.5-6.6 6.5-13z',
    ],
    filled: true,
  );

  /// Can (kalp) — dolgulu. Kalan hak sayısı kadar tekrarlanır.
  static const KimoIconData heart = KimoIconData(
    <String>[
      'M12 21C7 17.5 3.5 14.6 3.5 10.8 3.5 8 5.6 6 8.2 6c1.6 0 3 .8 3.8 2 .8-1.2 2.2-2 3.8-2 2.6 0 4.7 2 4.7 4.8 0 3.8-3.5 6.7-8.5 10.2z',
    ],
    filled: true,
  );

  /// Elmas — dolgulu.
  static const KimoIconData gem = KimoIconData(
    <String>['M12 2l6 6-6 14L6 8z'],
    filled: true,
  );

  /// Oynat / devam et — dolgulu.
  static const KimoIconData play = KimoIconData(
    <String>['M8 5.5v13l11-6.5z'],
    filled: true,
  );

  /// Onay işareti.
  static const KimoIconData check = KimoIconData(
    <String>['M5 12l5 5 9-10'],
    strokeWidth: 2.4,
  );

  /// Kapat / iptal.
  static const KimoIconData close = KimoIconData(<String>[
    'M6 6l12 12',
    'M18 6L6 18',
  ]);

  /// Geri.
  static const KimoIconData back = KimoIconData(<String>[
    'M14.5 5.5L8 12l6.5 6.5',
  ]);

  /// Ayarlar (dişli yerine sade kaydırıcı — tasarımın sade dili).
  static const KimoIconData settings = KimoIconData(<String>[
    'M4 7h10',
    'M18 7h2',
    'M4 17h6',
    'M14 17h6',
    'M14 4.5a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5',
    'M10 14.5a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5',
  ]);

  /// Bildir / şikâyet (bayrak).
  static const KimoIconData flag = KimoIconData(<String>[
    'M6 21V4',
    'M6 5h11l-2.2 3.5L17 12H6',
  ]);

  /// Kilit — veli onayı beklenirken kapalı özellikleri işaretler.
  static const KimoIconData lock = KimoIconData(<String>[
    'M8 10h8a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2z',
    'M9 10V7.5a3 3 0 0 1 6 0V10',
  ]);

  /// Katalogdaki her ikon. Test bu listeyi gezerek her yolun ayrıştığını ve
  /// 24 birimlik ızgaranın dışına taşmadığını doğruluyor; yeni ikon eklendiğinde
  /// buraya da eklenmezse testte görünmez kalır.
  static const List<KimoIconData> all = <KimoIconData>[
    home,
    notebook,
    bars,
    person,
    camera,
    flame,
    heart,
    gem,
    play,
    check,
    close,
    back,
    settings,
    flag,
    lock,
  ];
}

/// [KimoIconData]'yı çizen widget.
class KimoIcon extends StatelessWidget {
  const KimoIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth,
  });

  final KimoIconData icon;
  final double size;

  /// Verilmezse çevredeki [IconTheme] rengi kullanılır.
  final Color? color;

  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? IconTheme.of(context).color ?? const Color(0xFF191713);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IconPainter(
          icon: icon,
          color: resolved,
          strokeWidth: strokeWidth ?? icon.strokeWidth,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  final KimoIconData icon;
  final Color color;
  final double strokeWidth;

  // Aynı yol verisi her karede yeniden ayrıştırılmasın: ikonlar sabit ve
  // sayıları az, önbellek sınırsız büyümez.
  static final Map<String, Path> _cache = <String, Path>{};

  static Path _path(String d) => _cache.putIfAbsent(d, () => parseSvgPath(d));

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (icon.filled) {
      paint.style = PaintingStyle.fill;
    } else {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    for (final String d in icon.paths) {
      canvas.drawPath(_path(d), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

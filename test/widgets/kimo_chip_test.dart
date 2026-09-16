import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:kimo/widgets/kit/kimo_chips.dart';

/// Çipin ÖLÇÜSÜ (Task 15).
void main() {
  testWidgets('Wrap içindeki çipler yan yana diziliyor, satırı kaplamıyor',
      (WidgetTester tester) async {
    // REGRESYON: `AnimatedContainer`ın `alignment`ı vardı ve `Container`
    // hizalama verilince gelen sınırlı kısıtın TAMAMINA yayılıyor. `Wrap`
    // çocuklarına sınırlı genişlik verdiği için her çip satırı kaplıyor,
    // beş sınav yılı beş ayrı satır oluyordu.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String y in <String>['2027', '2028', '2029'])
                KimoChip(label: y, selected: y == '2028', onTap: () {}),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();

    final List<Rect> boxes = <Rect>[
      for (final Element e in find.byType(KimoChip).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(boxes.length, 3);
    for (final Rect r in boxes) {
      expect(r.width, lessThan(200), reason: 'çip içeriği kadar olmalı');
      expect(r.height, greaterThanOrEqualTo(40), reason: 'dokunma hedefi 40');
    }
    // Üçü de AYNI satırda: dikey merkezleri eşit.
    expect(boxes[0].center.dy, boxes[1].center.dy);
    expect(boxes[1].center.dy, boxes[2].center.dy);
  });
}

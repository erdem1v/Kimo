import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/models/mascot.dart';
import 'package:kimo/widgets/kimo/kimo_painter.dart';
import 'package:kimo/widgets/kimo/kimo_pose.dart';

/// Maskotun ÇİZİMİ — deponun ilk görsel testi.
///
/// NEDEN GOLDEN DEĞİL: golden dosyaları platforma duyarlı; bu makine macOS, CI
/// Linux ve aynı golden ikisinde eşleşmiyor. `TestRecordingCanvas` çağrıları
/// kaydediyor, yani iddialar platformdan bağımsız ve "kaç şekil, hangi renkte"
/// sorusu doğrudan sorulabiliyor.
///
/// NEDEN GEREKLİ: `KimoPainter` için HİÇ görsel test yoktu. Bir koordinat ya da
/// renk sessizce kaysa hiçbir test kırmızıya dönmüyordu — ve Task 12 o dosyaya
/// dört yeni çizim dalı ekliyor.
void main() {
  /// [accessory] ile çizimi kaydeder.
  List<RecordedInvocation> record(KimoAccessory accessory) {
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    KimoPainter(pose: const KimoPose(), accessory: accessory)
        .paint(canvas, const Size(200, 200));
    return canvas.invocations;
  }

  /// Çağrılardaki [Paint] renklerini toplar.
  Set<int> colorsOf(List<RecordedInvocation> calls) => <int>{
        for (final RecordedInvocation i in calls)
          for (final Object? a in i.invocation.positionalArguments)
            if (a is Paint) a.color.toARGB32(),
      };

  int drawCalls(List<RecordedInvocation> calls) => calls
      .where((RecordedInvocation i) =>
          i.invocation.memberName.toString().contains('draw'))
      .length;

  group('taban ayı dört varyantta AYNI', () {
    test('aksesuarsız çizim bir taban üretiyor', () {
      expect(drawCalls(record(KimoAccessory.none)), greaterThan(5));
    });

    test('her aksesuar tabana ŞEKİL EKLİYOR, değiştirmiyor', () {
      final int base = drawCalls(record(KimoAccessory.none));
      for (final KimoAccessory a in <KimoAccessory>[
        KimoAccessory.anac,
        KimoAccessory.usta,
        KimoAccessory.ceo,
        KimoAccessory.arabeskci,
      ]) {
        final int withAcc = drawCalls(record(a));
        expect(withAcc, greaterThan(base),
            reason: '$a şekil eklemiyor — katman çizilmiyor olabilir');
      }
    });

    test('taban paleti hiçbir varyantta kaybolmuyor', () {
      // Kafa, ağız ve mürekkep her varyantta çizilmeli: aksesuar tabanı
      // ÖRTMÜYOR, üstüne biniyor.
      for (final KimoAccessory a in KimoAccessory.values) {
        final Set<int> colors = colorsOf(record(a));
        expect(colors, contains(KimoPalette.head.toARGB32()), reason: '$a');
        expect(colors, contains(KimoPalette.muzzle.toARGB32()), reason: '$a');
        expect(colors, contains(KimoPalette.earOuter.toARGB32()), reason: '$a');
      }
    });
  });

  group('her persona kendi aksesuarını çiziyor', () {
    test('Anaç: çiçek ve örgü renkleri', () {
      final Set<int> c = colorsOf(record(KimoAccessory.anac));
      expect(c, contains(KimoPalette.flowerPetal.toARGB32()));
      expect(c, contains(KimoPalette.flowerCore.toARGB32()));
      expect(c, contains(KimoPalette.braidDark.toARGB32()));
      // Başka personanın aksesuarı sızmıyor.
      expect(c, isNot(contains(KimoPalette.navy.toARGB32())));
      expect(c, isNot(contains(KimoPalette.jacket.toARGB32())));
    });

    test('Usta: lacivert kasket, çiçek yok, papyon DÜĞÜMÜ yok', () {
      final Set<int> c = colorsOf(record(KimoAccessory.usta));
      expect(c, contains(KimoPalette.navy.toARGB32()));
      expect(c, contains(KimoPalette.navyDeep.toARGB32()));
      expect(c, isNot(contains(KimoPalette.flowerPetal.toARGB32())));
      // Kasket ve papyon AYNI laciverti paylaşıyor; ikisini renkle ayıran tek
      // ton düğüm. Bunu iddia etmek, iki dalın karışmadığını kanıtlıyor.
      expect(c, isNot(contains(KimoPalette.navyKnot.toARGB32())));
    });

    test('CEO: papyon düğümü VAR (Usta''dan ayıran ton)', () {
      final Set<int> c = colorsOf(record(KimoAccessory.ceo));
      expect(c, contains(KimoPalette.navy.toARGB32()));
      expect(c, contains(KimoPalette.navyKnot.toARGB32()));
      expect(c, isNot(contains(KimoPalette.flowerPetal.toARGB32())));
    });

    test('Arabeskçi: ceket ve zincir renkleri', () {
      final Set<int> c = colorsOf(record(KimoAccessory.arabeskci));
      expect(c, contains(KimoPalette.jacket.toARGB32()));
      expect(c, contains(KimoPalette.chain.toARGB32()));
      expect(c, contains(KimoPalette.medallion.toARGB32()));
    });

    test('aksesuarsızda HİÇBİR aksesuar rengi yok', () {
      final Set<int> c = colorsOf(record(KimoAccessory.none));
      for (final Color a in <Color>[
        KimoPalette.flowerPetal,
        KimoPalette.navy,
        KimoPalette.navyKnot,
        KimoPalette.jacket,
      ]) {
        expect(c, isNot(contains(a.toARGB32())));
      }
    });
  });

  group('aksesuar tasarımın kutusunun içinde kalıyor', () {
    // Aksesuar yolları tasarımın `viewBox="42 6 216 200"` uzayında verildi,
    // painter ise `52 4 196 200` kullanıyor. Dönüşüm yazılmadı çünkü bütün
    // aksesuar noktalarının painter kutusunda kaldığı ÖLÇÜLDÜ. Bu test o
    // ölçümü sabitliyor: bir tasarım güncellemesi kutuyu aşarsa kırmızı döner.
    test('çizilen her şey 200x200 tuvalin içinde', () {
      for (final KimoAccessory a in KimoAccessory.values) {
        final TestRecordingCanvas canvas = TestRecordingCanvas();
        KimoPainter(pose: const KimoPose(), accessory: a)
            .paint(canvas, const Size(200, 200));
        for (final RecordedInvocation i in canvas.invocations) {
          for (final Object? arg in i.invocation.positionalArguments) {
            if (arg is ui.Path) {
              final Rect b = arg.getBounds();
              // Tasarım uzayı koordinatları; ölçek paint() içinde uygulanıyor,
              // yani sınırları tasarım kutusuna göre denetliyoruz.
              expect(b.left, greaterThanOrEqualTo(50.0), reason: '$a sol');
              expect(b.right, lessThanOrEqualTo(250.0), reason: '$a sağ');
              expect(b.top, greaterThanOrEqualTo(2.0), reason: '$a üst');
              expect(b.bottom, lessThanOrEqualTo(206.0), reason: '$a alt');
            }
          }
        }
      }
    });
  });

  group('Mascot → aksesuar eşlemesi', () {
    test('dört personanın dördü FARKLI aksesuar veriyor', () {
      final Set<KimoAccessory> seen =
          Mascot.values.map((Mascot m) => m.accessory).toSet();
      expect(seen.length, Mascot.values.length,
          reason: 'iki persona aynı aksesuarı paylaşıyor');
      expect(seen, isNot(contains(KimoAccessory.none)));
    });
  });
}

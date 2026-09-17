// Uygulama ikonlarını ÇİZEREK üretir — `flutter test tool/gen_app_icons.dart`.
//
// NEDEN BURADA: depoda Flutter'ın VARSAYILAN ikonu duruyordu (mavi Flutter
// logosu). İki mağaza da yer tutucu varlıkla gönderilen yapıyı reddediyor ve
// bu, turda değil ancak `AppIcon.appiconset`e bakarak görülebilecek türden bir
// eksikti. Marka varlığı zaten kodda: Kimo `KimoPainter` ile çiziliyor, yani
// ikon için ayrı bir tasarım dosyası gerekmiyor — aynı geometri, tek kaynak.
//
// `test/` ALTINDA DEĞİL: `flutter test` varsayılan taramasına girmesin,
// üretim CI'da her koşuda dosya yazmasın. Elle çalıştırılan bir araç.
//
// `tools/` DEĞİL `tool/`: `tools/` kendi `pubspec.yaml`ını taşıyan AYRI bir
// paket (`meb_import`) ve oradan `package:kimo`/`package:flutter` import
// etmek `flutter analyze`ı beş `depend_on_referenced_packages` bildirimiyle
// kırmızıya döndürüyor. `tool/` kök paketin içinde — Dart'ın betikler için
// zaten önerdiği ad.
//
// Çıktı:
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png  (Contents.json'daki
//     her yuva; iOS ikonları OPAK ve köşesiz olmak zorunda — maskeyi sistem
//     uyguluyor)
//   android/app/src/main/res/mipmap-*/ic_launcher.png     (eski yol)
//   android/app/src/main/res/mipmap-*/ic_launcher_foreground.png + anydpi-v26
//     (uyarlanabilir ikon; ön plan 108dp ızgarasında ve güvenli alan 72dp)

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/theme/app_colors.dart';
import 'package:kimo/widgets/kimo/kimo_painter.dart';
import 'package:kimo/widgets/kimo/kimo_pose.dart';

/// Marka zemini. Birincil eylem rengi: uygulamanın her ekranında bu duruyor.
const Color kBackground = AppColors.green;

/// Ayının ikon karesindeki oranı. Iyi ikonlar kenara yaslanmaz.
const double kInset = 0.16;

/// Uyarlanabilir ikonda ön plan 108dp'lik tuvalin ortasındaki 72dp'ye
/// sığmalı: sistem maskesi dışarıyı kırpıyor.
const double kAdaptiveInset = 0.25;

Future<Uint8List> render(int px, {required double inset, bool opaque = true}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final double size = px.toDouble();
  if (opaque) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = kBackground,
    );
  }
  final double pad = size * inset;
  canvas.save();
  canvas.translate(pad, pad);
  // Poz NÖTR ve SABİT: ikon her derlemede birebir aynı çıkmalı.
  KimoPainter(pose: const KimoPose()).paint(
    canvas,
    Size(size - pad * 2, size - pad * 2),
  );
  canvas.restore();
  final ui.Image image = await recorder.endRecording().toImage(px, px);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<void> write(String path, Uint8List bytes) async {
  final File f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes);
  // ignore: avoid_print
  print('${bytes.length ~/ 1024} KB  $path');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS ikon yuvaları', () async {
    const String dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final Map<String, dynamic> contents =
        jsonDecode(File('$dir/Contents.json').readAsStringSync())
            as Map<String, dynamic>;
    final List<dynamic> images = contents['images'] as List<dynamic>;
    expect(images, isNotEmpty);
    for (final dynamic raw in images) {
      final Map<String, dynamic> img = (raw as Map).cast<String, dynamic>();
      final String? name = img['filename'] as String?;
      if (name == null) continue;
      final double pt = double.parse((img['size'] as String).split('x').first);
      final double scale =
          double.parse((img['scale'] as String).replaceAll('x', ''));
      final int px = (pt * scale).round();
      await write('$dir/$name', await render(px, inset: kInset));
    }
  });

  // AÇILIŞ EKRANI. İki platformda da Flutter'ın varsayılanı duruyordu: iOS'ta
  // 1x1 piksellik beyaz bir PNG, Android'de düz beyaz bir katman. Rejimi
  // değiştirmiyoruz (zemin yine tema rengi), yalnızca ortaya maskotu koyuyoruz
  // — ilk kare artık markalı.
  //
  // ZEMİN SAYDAM: iOS storyboard'u beyaz, Android karanlık temada siyah
  // çiziyor; opak bir kare iki zeminden birinde çirkin bir kutu olurdu.
  test('açılış ekranı görseli', () async {
    const String ios = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    // storyboard `contentMode="center"`: görsel DOĞAL boyutunda ortalanıyor,
    // gerilmiyor. 120pt genişlik küçük telefonda da nefes alıyor.
    for (final MapEntry<String, int> e in <String, int>{
      'LaunchImage.png': 120,
      'LaunchImage@2x.png': 240,
      'LaunchImage@3x.png': 360,
    }.entries) {
      await write('$ios/${e.key}',
          await render(e.value, inset: 0, opaque: false));
    }

    const String res = 'android/app/src/main/res';
    for (final MapEntry<String, int> e in <String, int>{
      'drawable-mdpi': 120,
      'drawable-hdpi': 180,
      'drawable-xhdpi': 240,
      'drawable-xxhdpi': 360,
      'drawable-xxxhdpi': 480,
    }.entries) {
      await write('$res/${e.key}/launch_image.png',
          await render(e.value, inset: 0, opaque: false));
    }
  });

  test('Android eski ve uyarlanabilir ikonlar', () async {
    const String res = 'android/app/src/main/res';
    const Map<String, int> legacy = <String, int>{
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    for (final MapEntry<String, int> e in legacy.entries) {
      await write('$res/${e.key}/ic_launcher.png',
          await render(e.value, inset: kInset));
      // Uyarlanabilir ön plan 108/48 = 2.25 kat daha büyük tuval.
      await write(
        '$res/${e.key}/ic_launcher_foreground.png',
        await render((e.value * 2.25).round(),
            inset: kAdaptiveInset, opaque: false),
      );
    }
  });
}

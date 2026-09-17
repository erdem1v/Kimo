import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/models/social.dart';

/// LİG KURALI TEK KAYNAKTAN (Task 17).
///
/// Terfi/düşme kararını `settle_past_leagues` veriyor; istemcinin ekranda
/// yazdığı cümle o kararın KOPYASI ve kopyalar bayatlıyor. Ekran eskiden
/// "altı kişiden büyük her grupta son 5 düşer" diyordu; sunucu ise düşmeyi
/// yalnızca 11+ kişilik kohortta uyguluyor. Sonuç: 6-10 kişilik gruplara hiç
/// gerçekleşmeyecek bir tehdit, dokuz kişilik grupta da beşinci sıranın iki
/// kümeye birden düşmesi.
///
/// Bu test sayıları göçten okuyor: kural sunucuda değişirse burası kırmızıya
/// döner.
void main() {
  late String sql;

  setUpAll(() {
    final List<File> files = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((File f) =>
            f.readAsStringSync().contains('function public.settle_past_leagues'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'settle_past_leagues göçü bulunamadı');
    // EN SON tanım geçerli olan; ilk grep sonucu DEĞİL.
    sql = files.last.readAsStringSync();
  });

  test('terfi sayısı sunucuyla aynı', () {
    final RegExpMatch? m = RegExp(r"rnk <= (\d+) then 'up'").firstMatch(sql);
    expect(m, isNotNull, reason: 'terfi kuralı okunamadı');
    expect(League.promotionCount, int.parse(m!.group(1)!));
  });

  test('düşme eşiği ve sayısı sunucuyla aynı', () {
    final RegExpMatch? m =
        RegExp(r'when n >= (\d+)\s*\n\s*and rnk > n - (\d+)').firstMatch(sql);
    expect(m, isNotNull, reason: 'düşme kuralı okunamadı');
    expect(League.demotionMinCohort, int.parse(m!.group(1)!),
        reason: 'ekran, sunucunun düşme uygulamadığı kohortta düşme vaat ediyor');
    expect(League.demotionCount, int.parse(m.group(2)!));
  });

  test('iki küme ÖRTÜŞMÜYOR', () {
    // Eşiğin tek işi bu: en küçük düşme kohortunda bile terfi ve düşme
    // kümeleri ayrık kalmalı.
    expect(League.promotionCount + League.demotionCount,
        lessThanOrEqualTo(League.demotionMinCohort),
        reason: 'ilk ${League.promotionCount} ile son ${League.demotionCount} '
            'kesişiyor');
  });
}

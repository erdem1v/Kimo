import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kaydetme yolunun iki kez kapandığı yer (Task 14 · D2 ve B2).
///
/// Bu iki hata da ancak ÇALIŞMA ZAMANINDA görülüyordu — biri PostgREST
/// yükünde, biri depolama başlığında — yani `flutter analyze` ve bütün widget
/// testleri sessiz kalıyordu. Dosya bu yüzden KAYNAĞI okuyor: kanıtlanacak
/// şey bir davranış değil, yükün ŞEKLİ.
///
/// 1. `'is_public'` yükte kalmıştı. 0090 o sütunun INSERT yetkisini geri
///    almıştı, dolayısıyla HER kayıt 42501 ile düşüyordu.
/// 2. `upsert: true` yüklemeyi `x-upsert` başlığına çeviriyor; depolama
///    sunucusu bunu UPSERT olarak işleyip `storage.objects` üzerinde bir
///    UPDATE politikası arıyor. `mistake-photos` kovasında öyle bir politika
///    YOK (ve olmamalı: taraması temiz çıkmış bir fotoğrafın üzerine
///    yazılabilmemeli), dolayısıyla her yükleme 403 ile düşüyordu.
void main() {
  final String src =
      File('lib/data/mistake_repository.dart').readAsStringSync();

  // `add`in insert yükü: `from('mistakes').insert({...})` ile `.select` arası.
  final int start = src.indexOf("from('mistakes').insert(");
  final int end = src.indexOf(".select('id')", start);
  final String payload = src.substring(start, end);

  test('insert yükü is_public göndermiyor', () {
    expect(payload.contains("'is_public'"), isFalse,
        reason: '0090 sütunu geri aldı; göndermek kaydetme yolunu kapatıyor');
  });

  test('soru fotoğrafı upsert ile yüklenmiyor', () {
    final int up = src.indexOf('uploadBinary(');
    final int upEnd = src.indexOf(');', up);
    expect(src.substring(up, upEnd).contains('upsert'), isFalse,
        reason: 'x-upsert, mistake-photos kovasında olmayan bir UPDATE '
            'politikası arıyor ve yükleme 403 ile düşüyor');
  });
}

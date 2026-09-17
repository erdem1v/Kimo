import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

/// Task 15'in bloke edicisinin regresyonu.
///
/// HATA NEYDİ: sunucu müfredatı `auth.jwt() -> 'user_metadata' ->> 'curriculum'`
/// ile okuyor ve `mistakes.curriculum` varsayılanı ondan geliyor
/// (`my_curriculum()`, 0059). İstemci `auth.updateUser` ile metadata'ya
/// yazıyordu ama **erişim jetonu yeniden üretilmiyordu**: üretimde jetonun
/// `user_metadata`'sı `{}` iken saklanan kullanıcı nesnesi
/// `{"curriculum":"maarif",...}` gösteriyordu. Sonuç: sunucu "eski" varsayıp
/// maarif ağacından gelen her konuyu `KM022` ile reddediyordu — yani sınav
/// yılı 2028 ve sonrasını seçen her yeni kullanıcı ilk sorusunu HİÇ
/// kaydedemiyordu.
///
/// Bu dosya ZİNCİRİ sınıyor: metadata → jeton → `my_curriculum()` →
/// `mistakes.curriculum` → konu doğrulama tetikleyicisi. Zincirin herhangi bir
/// halkası koparsa burası kırmızıya döner.
void main() {
  // Bu konular müfredat tohumundan (0057) geliyor ve BİLEREK farklı ağaçlarda:
  // "eski" TYT/Matematik 17 konu taşıyor, "maarif" 12 ve listeler ayrık.
  const String eskiKonu = 'Birinci Dereceden Denklemler ve Eşitsizlikler';
  const String maarifKonu = 'Denklem-Eşitsizlik';

  Future<PostgrestException?> insertMistake(
    SupabaseClient c,
    String concept,
  ) async {
    try {
      await c.from('mistakes').insert(<String, dynamic>{
        'subject': 'Matematik',
        'concept': concept,
        'exam': 'TYT',
      });
      return null;
    } on PostgrestException catch (e) {
      return e;
    }
  }

  test('metadata yazılıp jeton tazelenince zincirin tamamı maarife dönüyor',
      () async {
    final SupabaseClient c = await newUser(anonymous: true);
    addTearDown(() => dropUser(c));

    // 1) Müfredat belirtilmemiş: sunucu "eski" varsayıyor.
    expect(
      jwtClaims(c.auth.currentSession!.accessToken)['user_metadata'],
      isNot(containsPair('curriculum', 'maarif')),
      reason: 'yeni oturumda müfredat claimi olmamalı',
    );
    expect(await insertMistake(c, eskiKonu), isNull,
        reason: 'eski ağacın konusu eski müfredatta geçerli');
    expect((await insertMistake(c, maarifKonu))?.code, 'KM022',
        reason: 'maarif konusu eski ağaçta YOK — sunucu reddetmeli');

    // 2) İstemcinin yaptığı: metadata'ya yaz, SONRA jetonu tazele.
    await c.auth.updateUser(
      UserAttributes(data: <String, dynamic>{'curriculum': 'maarif'}),
    );
    await c.auth.refreshSession();

    expect(
      jwtClaims(c.auth.currentSession!.accessToken)['user_metadata'],
      containsPair('curriculum', 'maarif'),
      reason: 'tazelenen jeton yeni metadata claimini taşımalı',
    );
    expect(await insertMistake(c, maarifKonu), isNull,
        reason: 'jeton maarif diyorsa maarif konusu kabul edilmeli');

    final List<dynamic> rows = await c
        .from('mistakes')
        .select('concept, curriculum')
        .eq('concept', maarifKonu);
    expect((rows.single as Map<String, dynamic>)['curriculum'], 'maarif',
        reason: 'satırın müfredatı JETONDAN türemeli');
  });

  test('DAVRANIŞ BELGESİ: updateUser tek başına jetonu yeniliyor mu', () async {
    // Bu test bir KURAL değil, bir GÖZLEM tutanağı. `UserProfile._save`'den
    // sonra çağrılan `refreshSession()` yalnızca GoTrue jetonu kendiliğinden
    // yenilemediği için var. Bir gün yenilemeye başlarsa burası kırmızıya
    // döner ve o tazeleme çağrısını kaldırabiliriz — sessizce gereksiz bir
    // ağ turu taşımaya devam etmek yerine.
    final SupabaseClient c = await newUser(anonymous: true);
    addTearDown(() => dropUser(c));

    await c.auth.updateUser(
      UserAttributes(data: <String, dynamic>{'curriculum': 'maarif'}),
    );

    expect(c.auth.currentUser?.userMetadata?['curriculum'], 'maarif',
        reason: 'kullanıcı NESNESİ her hâlükârda güncel');
    expect(
      jwtClaims(c.auth.currentSession!.accessToken)['user_metadata'],
      isNot(containsPair('curriculum', 'maarif')),
      reason: 'GÖZLEM: jeton yenilenmiyor — `refreshSession` bu yüzden gerekli',
    );
  });
}

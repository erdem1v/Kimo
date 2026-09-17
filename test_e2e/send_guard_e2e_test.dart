import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

/// Task 16'nın bloke edicisinin regresyonu.
///
/// HATA NEYDİ: fotoğraflı bir kayıt eklenince `mistakes_photo_scan_reset`
/// tetikleyicisi `photo_scan`i `'pending'` yapıyor ve tarama edge fonksiyonu
/// ateşle-unut çağrılıyor. `send_question_to_friends` ise `'clear'` istiyor.
/// İstemci kaydın ardından AYNI KAREDE gönderiyordu; üretimde ölçüldü: kayıt
/// `00:06:41.022`, tarama `00:06:43.444` (2,4 saniye) ve arada gönderim
/// düştü — `question_sends`'te satır HİÇ oluşmadı. Kullanıcıya "yakında
/// göndermiş olabilirsin" deniyordu.
///
/// Burada SUNUCU SÖZLEŞMESİ sabitleniyor: tarama bitmeden gönderim yok, ve
/// reddin sebebi `not_sendable` olarak ayırt edilebiliyor. İstemcinin bu
/// sözleşmeye uyması (`QuestionSendRepository.sendToFriends`'in beklemesi)
/// `test/data/send_result_test.dart` tarafında sınanıyor.
void main() {
  Future<void> befriend(String a, String b) async {
    final SupabaseClient admin = adminClient();
    try {
      await admin.from('friendships').insert(<String, dynamic>{
        'requester_id': a,
        'addressee_id': b,
        'status': 'accepted',
      });
    } finally {
      await admin.dispose();
    }
  }

  Future<Map<String, dynamic>> send(SupabaseClient c, String mistakeId,
      String receiver) async {
    final List<dynamic> rows = await c.rpc<List<dynamic>>(
      'send_question_to_friends',
      params: <String, dynamic>{
        'p_mistake': mistakeId,
        'p_receivers': <String>[receiver],
        'p_note': null,
      },
    );
    return rows.single as Map<String, dynamic>;
  }

  test('tarama bitmeden gönderim YOK, sebebi not_sendable', () async {
    final SupabaseClient a = await newUser();
    final SupabaseClient b = await newUser();
    addTearDown(() => dropUser(a));
    addTearDown(() => dropUser(b));

    final String uidA = a.auth.currentUser!.id;
    final String uidB = b.auth.currentUser!.id;
    await befriend(uidA, uidB);

    // FOTOĞRAFLI kayıt: tetikleyici `photo_scan`i 'pending' yapıyor.
    final Map<String, dynamic> row = await a
        .from('mistakes')
        .insert(<String, dynamic>{
          'subject': 'Matematik',
          'concept': 'Birinci Dereceden Denklemler ve Eşitsizlikler',
          'exam': 'TYT',
          'photo_path': '$uidA/e2e.jpg',
        })
        .select('id, photo_scan')
        .single();

    expect(row['photo_scan'], 'pending',
        reason: 'fotoğraflı kayıt taranmadan clear olmamalı');

    final String mistakeId = row['id'] as String;
    final Map<String, dynamic> blocked = await send(a, mistakeId, uidB);
    expect(blocked['sent'], 0);
    expect(blocked['reason'], 'not_sendable',
        reason: 'sebep ayırt edilebilmeli: "arkadaş almadı" DEĞİL');

    // Alıcının kutusuna hiçbir şey düşmemeli.
    final List<dynamic> before = await b.from('question_sends').select('id');
    expect(before, isEmpty);

    // Tarama biter (üretimde edge fonksiyonu yapıyor, burada kurulum).
    final SupabaseClient admin = adminClient();
    try {
      await admin
          .from('mistakes')
          .update(<String, dynamic>{'photo_scan': 'clear'})
          .eq('id', mistakeId);
    } finally {
      await admin.dispose();
    }

    final Map<String, dynamic> ok = await send(a, mistakeId, uidB);
    expect(ok['sent'], 1, reason: 'tarama bitince gönderim geçmeli');

    final List<dynamic> after = await b.from('question_sends').select('id');
    expect(after, hasLength(1));
  });

  test('ANONİM kullanıcı hiç gönderemiyor — sebebi ayrı', () async {
    // Bu testi süitin İLK KOŞUSU yazdırdı: gönderim testleri anonim kurulumla
    // yazılmıştı ve sunucu `not_sendable` yerine `anonymous` döndü. Kural
    // gerçek ve kasıtlı (0043): anonim kullanıcı sosyal yüzeyin tamamından
    // dışlanıyor. Artık sözleşme olarak sabitleniyor.
    final SupabaseClient a = await newUser(anonymous: true);
    final SupabaseClient b = await newUser();
    addTearDown(() => dropUser(a));
    addTearDown(() => dropUser(b));

    await befriend(a.auth.currentUser!.id, b.auth.currentUser!.id);

    final Map<String, dynamic> row = await a
        .from('mistakes')
        .insert(<String, dynamic>{
          'subject': 'Matematik',
          'concept': 'Birinci Dereceden Denklemler ve Eşitsizlikler',
          'exam': 'TYT',
        })
        .select('id')
        .single();

    final Map<String, dynamic> res =
        await send(a, row['id'] as String, b.auth.currentUser!.id);
    expect(res['sent'], 0);
    expect(res['reason'], 'anonymous',
        reason: 'anonimlik reddi, içerik reddinden AYRI anlatılmalı');
  });

  test('fotoğrafsız kayıt beklemeden gönderilebiliyor', () async {
    // `photo_scan` varsayılanı 'clear' ve tetikleyici yalnızca `photo_path`
    // doluyken 'pending' yazıyor. Elle giriş yolu bu yüzden beklemiyor —
    // istemcideki bekleme merdiveninin boşa çalışmadığının kanıtı.
    final SupabaseClient a = await newUser();
    final SupabaseClient b = await newUser();
    addTearDown(() => dropUser(a));
    addTearDown(() => dropUser(b));

    await befriend(a.auth.currentUser!.id, b.auth.currentUser!.id);

    final Map<String, dynamic> row = await a
        .from('mistakes')
        .insert(<String, dynamic>{
          'subject': 'Matematik',
          'concept': 'Birinci Dereceden Denklemler ve Eşitsizlikler',
          'exam': 'TYT',
        })
        .select('id, photo_scan')
        .single();

    expect(row['photo_scan'], 'clear');
    final Map<String, dynamic> res =
        await send(a, row['id'] as String, b.auth.currentUser!.id);
    expect(res['sent'], 1);
  });
}

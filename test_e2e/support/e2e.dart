/// YEREL Supabase yığınına karşı koşan testlerin ortak zemini.
///
/// **NEDEN BU KLASÖR VAR.** Task 15 ve 16'nın iki bloke edicisi de
/// istemci/sunucu sınırının iki yakasında bir SIRA hatasıydı ve depodaki
/// hiçbir kapı göremedi: 836 pgTAP iddiası şemayı tek başına doğruluyor, 414
/// birim testi istemciyi tek başına. Aradaki boşlukta "yeni kullanıcı ilk
/// sorusunu kaydedemiyor" ve "arkadaşa soru gönderme hiç çalışmıyor" aylarca
/// yaşayabildi.
///
/// Buradaki testler GERÇEK bir yığına bağlanıyor: gerçek GoTrue, gerçek RLS,
/// gerçek tetikleyiciler. CI zaten `supabase start` + `supabase db reset`
/// koşuyor (pgTAP için), yani ek altyapı maliyeti yok.
///
/// **SESSİZCE ATLANMIYOR.** Ortam değişkeni yoksa süit hata veriyor, `skip`
/// etmiyor. Deponun kendi dersi: CI'daki "atlanan göç" kontrolü tam olarak
/// "yeşil yanan ama hiçbir şey kanıtlamayan" koşuyu engellemek için var.
///
/// `test/` DEĞİL `test_e2e/`: birim testleri ağsız kalmalı ve `flutter test`
/// bu klasörü kendiliğinden toplamamalı. `tools/check_imports.py` bu kökü de
/// tarıyor, yani kör nokta değil.
library;

import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

const String envUrl = 'SUPABASE_E2E_URL';
const String envAnonKey = 'SUPABASE_E2E_ANON_KEY';
const String envServiceKey = 'SUPABASE_E2E_SERVICE_ROLE_KEY';

String _require(String name) {
  final String? value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError(
      'E2E süiti yerel Supabase yığını istiyor; $name tanımlı değil.\n'
      'Kurulum:\n'
      '  supabase start\n'
      '  supabase status -o env > .e2e.env   # API_URL / ANON_KEY / SERVICE_ROLE_KEY\n'
      'Sonra o üç değeri $envUrl / $envAnonKey / $envServiceKey olarak ver.\n'
      'Süit bilerek ATLAMIYOR: atlanan bir süit yeşil yanar ve hiçbir şey kanıtlamaz.',
    );
  }
  return value;
}

/// Anonim anahtarla istemci — uygulamanın gördüğü koltuk.
SupabaseClient anonClient() =>
    SupabaseClient(_require(envUrl), _require(envAnonKey));

/// Servis rolü — YALNIZCA kurulum ve temizlik için; iddialar anon koltuktan.
SupabaseClient adminClient() =>
    SupabaseClient(_require(envUrl), _require(envServiceKey));

/// Erişim jetonunun içindeki claim'ler.
///
/// Doğrulama YAPMIYOR, yalnızca çözüyor: testin sorusu "sunucu bu jetonda ne
/// görüyor", imzanın geçerliliği değil.
Map<String, dynamic> jwtClaims(String accessToken) {
  final List<String> parts = accessToken.split('.');
  if (parts.length != 3) {
    throw ArgumentError('JWT üç parçalı değil: ${parts.length}');
  }
  final String payload = base64Url.normalize(parts[1]);
  return jsonDecode(utf8.decode(base64Url.decode(payload)))
      as Map<String, dynamic>;
}

/// Yeni anonim oturum açar ve yaş kapısını geçer.
///
/// Yaş kapısı ŞART: `mistakes` insert politikası `has_birth_year(auth.uid())`
/// istiyor (0062). Yani bu, kısayol değil, uygulamanın gerçek sırası.
Future<SupabaseClient> newUser({int birthYear = 2008}) async {
  final SupabaseClient c = anonClient();
  await c.auth.signInAnonymously();
  await c.rpc<dynamic>('set_birth_year', params: <String, dynamic>{
    'p_year': birthYear,
  });
  return c;
}

/// Testin açtığı hesabı ve ona bağlı her şeyi siler.
///
/// `auth.users` üzerinden: FK'ların tamamı CASCADE (Task 16'da sayımla
/// doğrulandı). Depolama nesnesinin auth.users'a FK'si YOK, ama bu süit
/// depoya dosya yüklemiyor.
Future<void> dropUser(SupabaseClient client) async {
  final String? uid = client.auth.currentUser?.id;
  await client.auth.signOut();
  if (uid == null) return;
  final SupabaseClient admin = adminClient();
  try {
    await admin.auth.admin.deleteUser(uid);
  } finally {
    await admin.dispose();
  }
  await client.dispose();
}

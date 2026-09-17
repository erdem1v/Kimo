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

/// PKCE DEĞİL, IMPLICIT.
///
/// `signUp` varsayılan olarak PKCE akışını kullanıyor ve PKCE doğrulayıcıyı
/// saklamak için `asyncStorage` istiyor — o da `Supabase.initialize` ile gelen
/// Flutter eklentisinden. Bu süit bilerek Flutter eklentisi kurmuyor (testler
/// saf Dart istemcisiyle konuşuyor), dolayısıyla akış implicit olmalı.
/// `signInAnonymously` PKCE kullanmadığı için ilk koşuda bu sınıra
/// takılmamıştı; süite kalıcı hesap eklenince ortaya çıktı.
const AuthClientOptions _authOptions =
    AuthClientOptions(authFlowType: AuthFlowType.implicit);

/// Anonim anahtarla istemci — uygulamanın gördüğü koltuk.
SupabaseClient anonClient() => SupabaseClient(
      _require(envUrl),
      _require(envAnonKey),
      authOptions: _authOptions,
    );

/// Servis rolü — YALNIZCA kurulum ve temizlik için; iddialar anon koltuktan.
SupabaseClient adminClient() => SupabaseClient(
      _require(envUrl),
      _require(envServiceKey),
      authOptions: _authOptions,
    );

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

/// Yeni oturum açar ve yaş kapısını geçer.
///
/// Yaş kapısı ŞART: `mistakes` insert politikası `has_birth_year(auth.uid())`
/// istiyor (0062). Yani bu, kısayol değil, uygulamanın gerçek sırası.
///
/// **VARSAYILAN KALICI HESAP.** Anonim kullanıcı sosyal yüzeyin tamamından
/// dışlanıyor (`profiles.is_anonymous`, 0043): `send_question_to_friends`
/// daha ilk kapıda `'anonymous'` dönüyor, arkadaşlık ve lig de kapalı. Bunu
/// bu süitin ilk koşusu öğretti — anonim kurulumla yazılan gönderim testi
/// `not_sendable` yerine `anonymous` aldı.
///
/// [anonymous] yalnızca karşılama akışını taklit eden testler için: uygulama
/// kaydı SONA bıraktığı için yaş ve müfredat anonimken yazılıyor.
Future<SupabaseClient> newUser({
  int birthYear = 2008,
  bool anonymous = false,
}) async {
  final SupabaseClient c = anonClient();
  if (anonymous) {
    await c.auth.signInAnonymously();
  } else {
    // Yerelde e-posta doğrulaması kapalı (`config.toml` enable_confirmations),
    // yani `signUp` doğrudan oturum döndürüyor.
    final String tag =
        '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    await c.auth.signUp(email: 'e2e-$tag@kimo.test', password: 'Kimo12345!');
  }
  await c.rpc<dynamic>('set_birth_year', params: <String, dynamic>{
    'p_year': birthYear,
  });
  return c;
}

/// Aynı mikrosaniyede açılan iki hesabın e-postası çakışmasın.
int _counter = 0;

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

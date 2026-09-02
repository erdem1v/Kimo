import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_config.dart';

/// Hesap silme.
///
/// Silme sunucuda yapılıyor (`delete-account` edge fonksiyonu): depolama
/// nesneleri yalnızca Storage API üzerinden kaldırılabiliyor ve
/// `auth.admin.deleteUser` servis rolü istiyor. İkisi de istemcide olamaz.
///
/// **Yumuşak silme, 30 günlük bekleme yok** — "gerçekten silme" (KVKK Md. 7 /
/// GDPR Md. 17). Fonksiyon önce depolamayı boşaltıyor, ancak hepsi silindiyse
/// hesabı siliyor; kısmi başarıda hata dönüyor ve hesap DURUYOR. Bu yüzden
/// buradaki hata **yutulmuyor**: kullanıcı "silindi" sanıp fotoğraflarını
/// sunucuda bırakmamalı.
class AccountRepository {
  AccountRepository._();
  static final AccountRepository instance = AccountRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Hesabı ve tüm verisini siler; başarılıysa oturumu kapatır.
  ///
  /// Dönen sayı silinen depolama nesnesi adedi (kayıt/teşhis için).
  /// Başarısızlıkta [Exception] fırlatıyor.
  Future<int> deleteAccount() async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase yapılandırılmadı');
    }

    // `uid` GÖNDERİLMİYOR: fonksiyon onu çağıranın JWT'sinden okuyor. Gövdeden
    // göndermek, servis rolüyle çalışan bir uç noktayı "herkesi sil"
    // primitifine çevirirdi.
    final FunctionResponse res = await _client.functions.invoke(
      'delete-account',
      body: const <String, dynamic>{},
    );

    final dynamic data = res.data;
    if (data is Map && data['ok'] == true) {
      final int removed = (data['objects_removed'] as num?)?.toInt() ?? 0;
      debugPrint('hesap silindi, $removed nesne kaldırıldı');
      // Oturumu yerelde de kapat. Sunucudaki kullanıcı zaten yok; jeton
      // elde kalırsa uygulama silinmiş bir hesapla açık görünürdü.
      await _client.auth.signOut();
      return removed;
    }

    throw Exception('hesap silinemedi: ${res.status} $data');
  }
}

final AccountRepository accountRepository = AccountRepository.instance;

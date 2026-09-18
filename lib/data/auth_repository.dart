import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth sarmalayıcısı. Yalnızca Supabase yapılandırılmışken kullanılır
/// (bkz. SupabaseConfig / AuthGate).
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Giriş ekranı testinin dikişi (Task 18): `Supabase.instance` test
  /// ortamında kurulu değil ve ona dokunmak fırlatıyor. Deponun
  /// `PhotoQueue.analyzeOverride` deseni.
  @visibleForTesting
  static Future<void> Function({required String email, required String password})?
      signInOverride;

  Future<void> signIn({required String email, required String password}) {
    final Future<void> Function({required String email, required String password})?
        seam = signInOverride;
    if (seam != null) return seam(email: email, password: password);
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Oturum anonim mi (kayıt öncesi deneme).
  ///
  /// Supabase 2.x `User.isAnonymous` alanını taşıyor. Sunucu tarafında da
  /// `profiles.is_anonymous` var ve tetikleyiciyle senkronlanıyor (0046);
  /// buradaki değer yalnızca ARAYÜZ kararları için — sosyal yüzeyi kapatan
  /// asıl kural politikaların içinde.
  /// Onboarding testinin dikişi (Task 18): `currentUser` `Supabase.instance`
  /// üzerinden geliyor ve test ortamında yok.
  @visibleForTesting
  static bool? isAnonymousOverride;

  bool get isAnonymous =>
      isAnonymousOverride ?? (currentUser?.isAnonymous ?? false);

  /// Kayıt öncesi geçici kimlik.
  ///
  /// "İlk yanlışını çek" denildiği anda çağrılıyor — uygulama açılışında
  /// DEĞİL. Her açılışta çağırmak, uygulamayı yalnızca açıp kapatan herkes
  /// için bir çöp hesap (ve bir MAU) üretirdi.
  Future<void> signInAnonymously() => _client.auth.signInAnonymously();

  /// Anonim oturumu kalıcı hesaba çevirir. **`uid` DEĞİŞMEZ.**
  ///
  /// Bu yüzden fotoğraflar (`<uid>/...`), `mistakes` satırları ve onay defteri
  /// kayıtları olduğu yerde kalıyor; taşınacak hiçbir şey yok. Yeni bir hesap
  /// açıp veriyi kopyalamak, yükleme yarıda kalırsa kullanıcının ilk
  /// fotoğrafını kaybetmesi demekti.
  ///
  /// TASK 06: e-posta doğrulaması kaldırıldığı için (`enable_confirmations =
  /// false`) `updateUser` ANINDA tamamlanıyor — adres askıda kalmıyor ve
  /// sunucudaki `profiles.is_anonymous` hemen düşüyor. Katman ayrımı bu tek
  /// bayrağa dayandığı için kullanıcı kayıt anında ücretsiz kotaya geçiyor.
  /// Anonim oturumu kalıcıya çevirir; `uid` aynı kalır.
  ///
  /// JETON HEMEN TAZELENİYOR (Task 17 · T17-7). `updateUser` `auth.users`ı
  /// güncelliyor ama JETONU YENİDEN ÜRETMİYOR: `is_anonymous` claim'i bir
  /// sonraki yenilemeye kadar (en kötü durumda ~1 saat) `true` kalıyor.
  /// Sunucunun çoğu yeri bundan etkilenmiyor — sosyal yüzey ve `user_tier()`
  /// `profiles.is_anonymous`'ı okuyor ve onu bir tetikleyici anında
  /// güncelliyor — ama `verify-purchase` kararını JWT'den veriyor ve anonim
  /// kullanıcıyı 401 ile reddediyor. Sonuç: "kaydol, hemen Plus al" akışı
  /// sessizce düşüyordu. Task 15'in müfredat hatası da tam olarak bu sınıftı.
  ///
  /// Hata YUTULMUYOR gibi görünse de tazeleme ayrı: kayıt BAŞARILI, jeton
  /// tazelenemezse (çevrimdışı) satın alma yolundaki tek seferlik yeniden
  /// deneme ikinci şansı veriyor.
  Future<void> convertToPermanent({
    required String email,
    required String password,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
    try {
      await _client.auth.refreshSession();
    } catch (e) {
      debugPrint('kayıt sonrası jeton tazelenemedi: $e');
    }
  }

  // signUp() SİLİNDİ (Task 03): sıfır çağrısı vardı — kayıt tek yoldan,
  // karşılama akışının sonundaki convertToPermanent ile yapılıyor. Ölü ikinci
  // bir kayıt yolu, e-posta doğrulama akışını da ikiye bölerdi.

  // pendingEmail / emailConfirmed / refreshUser / resendEmailChange SİLİNDİ
  // (Task 06): dördünü de yalnızca karşılama akışındaki e-posta doğrulama
  // adımı kullanıyordu, o adım kaldırıldı. Doğrulama geri gelirse bunlar da
  // geri gelir; şu hâlleriyle sıfır çağrılı ölü yüzeydiler.

  // resendSignUp() SİLİNDİ (Task 08): tek çağıranı giriş ekranındaki
  // `email_not_confirmed` dalıydı ve o dal da kaldırıldı. E-posta doğrulaması
  // Task 06'da kapatıldı; üretimde `enable_confirmations = false` olduğu
  // teyit edildi ve açılmayacak. Doğrulama bir gün geri gelirse bu metot da
  // geri gelir — şu hâliyle çalışması mümkün olmayan bir yüzeydi.

  Future<void> signOut() => _client.auth.signOut();
}

final AuthRepository authRepository = AuthRepository.instance;

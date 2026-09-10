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

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Oturum anonim mi (kayıt öncesi deneme).
  ///
  /// Supabase 2.x `User.isAnonymous` alanını taşıyor. Sunucu tarafında da
  /// `profiles.is_anonymous` var ve tetikleyiciyle senkronlanıyor (0046);
  /// buradaki değer yalnızca ARAYÜZ kararları için — sosyal yüzeyi kapatan
  /// asıl kural politikaların içinde.
  bool get isAnonymous => currentUser?.isAnonymous ?? false;

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
  Future<void> convertToPermanent({
    required String email,
    required String password,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  // signUp() SİLİNDİ (Task 03): sıfır çağrısı vardı — kayıt tek yoldan,
  // karşılama akışının sonundaki convertToPermanent ile yapılıyor. Ölü ikinci
  // bir kayıt yolu, e-posta doğrulama akışını da ikiye bölerdi.

  // pendingEmail / emailConfirmed / refreshUser / resendEmailChange SİLİNDİ
  // (Task 06): dördünü de yalnızca karşılama akışındaki e-posta doğrulama
  // adımı kullanıyordu, o adım kaldırıldı. Doğrulama geri gelirse bunlar da
  // geri gelir; şu hâlleriyle sıfır çağrılı ölü yüzeydiler.

  /// İlk kayıt onayının postasını yeniden gönderir (giriş ekranındaki
  /// "e-postan doğrulanmamış" durumu için).
  Future<void> resendSignUp(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email);

  Future<void> signOut() => _client.auth.signOut();
}

final AuthRepository authRepository = AuthRepository.instance;

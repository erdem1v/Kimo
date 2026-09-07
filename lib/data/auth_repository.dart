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

  /// Onay bekleyen e-posta değişikliği (anonim → kalıcı dönüşümün askıdaki
  /// adresi). Sunucuda e-posta onayı KAPALIYSA hiç askıda kalmaz, null döner.
  String? get pendingEmail => currentUser?.newEmail;

  /// Oturumun e-postası onaylanmış mı?
  bool get emailConfirmed => currentUser?.emailConfirmedAt != null;

  /// Sunucudaki güncel kullanıcıyı çeker (onay başka cihazda/tarayıcıda
  /// verilmiş olabilir; push gelmez, SORMAK gerekir). Oturum ve `currentUser`
  /// tazelenir.
  Future<void> refreshUser() async {
    await _client.auth.refreshSession();
  }

  /// Askıdaki e-posta değişikliğinin onay postasını yeniden gönderir.
  Future<void> resendEmailChange(String email) =>
      _client.auth.resend(type: OtpType.emailChange, email: email);

  /// İlk kayıt onayının postasını yeniden gönderir (giriş ekranındaki
  /// "e-postan doğrulanmamış" durumu için).
  Future<void> resendSignUp(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email);

  Future<void> signOut() => _client.auth.signOut();
}

final AuthRepository authRepository = AuthRepository.instance;

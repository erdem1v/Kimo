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

  /// Hesap açar. Takma ad burada alınmaz: karşılama akışında Kimo sorar ve
  /// oradan metadata'ya yazılır.
  ///
  /// Anonim bir oturum varsa bu YOL KULLANILMAZ — [convertToPermanent] çağrılır.
  Future<void> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();
}

final AuthRepository authRepository = AuthRepository.instance;

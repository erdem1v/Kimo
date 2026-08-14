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

  /// Hesap açar. Takma ad burada alınmaz: karşılama akışında Kimo sorar ve
  /// oradan metadata'ya yazılır.
  Future<void> signUp({
    required String email,
    required String password,
    required bool guardianConsent,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{'guardian_consent': guardianConsent},
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}

final AuthRepository authRepository = AuthRepository.instance;

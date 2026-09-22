import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/auth_session.dart';

abstract class AccessTokenProvider {
  Future<String?> accessToken();
}

abstract class PeladinhasAuthService implements AccessTokenProvider {
  AuthSession? get currentSession;

  Stream<AuthSession?> get authStateChanges;

  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  });

  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class SupabasePeladinhasAuthService implements PeladinhasAuthService {
  SupabasePeladinhasAuthService({supabase.SupabaseClient? client})
      : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  AuthSession? get currentSession => _mapSession(_client.auth.currentSession);

  @override
  Stream<AuthSession?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((state) {
      return _mapSession(state.session);
    });
  }

  @override
  Future<String?> accessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return null;
    }
    if (!session.isExpired) {
      return session.accessToken;
    }

    try {
      final response = await _client.auth.refreshSession();
      return response.session?.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    final session = _mapSession(response.session);
    return AuthActionResult(
      session: session,
      message: session == null
          ? 'Check your email to confirm the Supabase account before logging in.'
          : null,
    );
  }

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return AuthActionResult(session: _mapSession(response.session));
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  AuthSession? _mapSession(supabase.Session? session) {
    if (session == null) {
      return null;
    }

    final user = session.user;
    return AuthSession(
      accessToken: session.accessToken,
      userId: user.id,
      email: user.email,
    );
  }
}

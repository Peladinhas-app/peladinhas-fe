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

class AuthUserFacingException implements Exception {
  const AuthUserFacingException(this.message);

  final String message;

  @override
  String toString() => message;
}

String safeAuthenticationErrorMessage(Object error) {
  if (error is AuthUserFacingException) {
    return error.message;
  }
  if (error is supabase.AuthRetryableFetchException) {
    return "We couldn’t connect. Please check your connection and try again.";
  }
  if (error is supabase.AuthException) {
    return _safeSupabaseAuthMessage(error);
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('xmlhttprequest') ||
      text.contains('network')) {
    return "We couldn’t connect. Please check your connection and try again.";
  }
  return 'Something went wrong. Please try again.';
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

String _safeSupabaseAuthMessage(supabase.AuthException error) {
  final code = error.code?.toLowerCase();
  final message = error.message.toLowerCase();
  final statusCode = error.statusCode;

  if (code == 'invalid_credentials' ||
      code == 'invalid_grant' ||
      code == 'user_not_found' ||
      message.contains('invalid login credentials')) {
    return 'The email or password is incorrect.';
  }
  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed') ||
      message.contains('confirm your email')) {
    return 'Please confirm your email before logging in.';
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      message.contains('already registered') ||
      message.contains('already exists')) {
    return 'An account already exists for this email.';
  }
  if (code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit' ||
      code == 'over_sms_send_rate_limit' ||
      statusCode == '429' ||
      message.contains('rate limit') ||
      message.contains('too many')) {
    return 'Too many attempts. Please wait and try again.';
  }
  return 'Something went wrong. Please try again.';
}

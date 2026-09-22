import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peladinhas/auth/app_session_controller.dart';
import 'package:peladinhas/auth/peladinhas_auth_service.dart';
import 'package:peladinhas/models/auth_session.dart';
import 'package:peladinhas/network/peladinhas_api_client.dart';

void main() {
  test('starts unauthenticated when no Supabase session exists', () async {
    final auth = _FakeAuthService();
    final controller = _controllerFor(auth, _profileResponse(200));

    await controller.start();

    expect(controller.state.stage, AppSessionStage.unauthenticated);
  });

  test('successful login loads an existing Peladinhas profile', () async {
    final auth = _FakeAuthService(signInSession: _session);
    final controller = _controllerFor(auth, _profileResponse(200));

    await controller.signIn(email: 'test@example.com', password: 'secret');

    expect(controller.state.stage, AppSessionStage.ready);
    expect(controller.state.profile?.name, 'Test User');
  });

  test('missing local profile enters onboarding state', () async {
    final auth = _FakeAuthService(signInSession: _session);
    final controller = _controllerFor(auth, _profileResponse(
      403,
      code: 'authenticated_user_not_found',
      message: 'Create a Peladinhas profile.',
    ));

    await controller.signIn(email: 'test@example.com', password: 'secret');

    expect(controller.state.stage, AppSessionStage.profileMissing);
  });

  test('profile creation makes the session ready', () async {
    final auth = _FakeAuthService(signInSession: _session);
    var requestCount = 0;
    final controller = _controllerFor(auth, (request) async {
      requestCount += 1;
      if (request.method == 'GET') {
        return _profileResponse(
          403,
          code: 'authenticated_user_not_found',
        )(request);
      }
      return _profileResponse(200)(request);
    });

    await controller.signIn(email: 'test@example.com', password: 'secret');
    await controller.createProfile(name: 'Test User', preferredLanguage: 'en');

    expect(controller.state.stage, AppSessionStage.ready);
    expect(requestCount, 2);
  });

  test('logout returns to unauthenticated state', () async {
    final auth = _FakeAuthService(signInSession: _session);
    final controller = _controllerFor(auth, _profileResponse(200));

    await controller.signIn(email: 'test@example.com', password: 'secret');
    await controller.signOut();

    expect(controller.state.stage, AppSessionStage.unauthenticated);
  });
}

final _session = AuthSession(
  accessToken: 'token',
  userId: 'supabase-user',
  email: 'test@example.com',
);

AppSessionController _controllerFor(
  _FakeAuthService auth,
  Future<http.Response> Function(http.Request request) handler,
) {
  final api = PeladinhasApiClient(
    baseUrl: 'http://localhost:8080/api/v1',
    tokenProvider: auth,
    httpClient: MockClient(handler),
  );
  return AppSessionController(authService: auth, apiClient: api);
}

Future<http.Response> Function(http.Request request) _profileResponse(
  int statusCode, {
  String code = 'ok',
  String message = 'ok',
}) {
  return (request) async {
    if (statusCode >= 200 && statusCode < 300) {
      return http.Response(
        jsonEncode({
          'id': 'user-1',
          'email': 'test@example.com',
          'name': 'Test User',
          'preferredLanguage': 'en',
        }),
        statusCode,
      );
    }
    return http.Response(
      jsonEncode({
        'code': code,
        'message': message,
        'timestamp': '2026-09-22T10:00:00Z',
        'fieldErrors': [],
      }),
      statusCode,
    );
  };
}

class _FakeAuthService implements PeladinhasAuthService {
  _FakeAuthService({this.signInSession});

  AuthSession? current;
  AuthSession? signInSession;
  final _controller = StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? get currentSession => current;

  @override
  Stream<AuthSession?> get authStateChanges => _controller.stream;

  @override
  Future<String?> accessToken() async => current?.accessToken;

  @override
  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    current = signInSession;
    return AuthActionResult(session: current);
  }

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async {
    current = signInSession;
    return AuthActionResult(session: current);
  }

  @override
  Future<void> signOut() async {
    current = null;
  }
}

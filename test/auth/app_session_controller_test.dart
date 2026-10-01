import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peladinhas/auth/app_session_controller.dart';
import 'package:peladinhas/auth/peladinhas_auth_service.dart';
import 'package:peladinhas/models/auth_session.dart';
import 'package:peladinhas/models/user_profile.dart';
import 'package:peladinhas/network/peladinhas_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
    await controller.createProfile(
      name: 'Test User',
      preferredLanguage: 'en',
      accountType: AccountUseChoice.player,
    );

    expect(controller.state.stage, AppSessionStage.ready);
    expect(requestCount, 2);
  });

  test('pitch owner profile creation sends account type and invitation', () async {
    final auth = _FakeAuthService(signInSession: _session);
    Map<String, dynamic>? capturedBody;
    final controller = _controllerFor(auth, (request) async {
      if (request.method == 'GET') {
        return _profileResponse(403, code: 'authenticated_user_not_found')(
          request,
        );
      }
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _profileResponse(200, pitchOwner: true)(request);
    });

    await controller.signIn(email: 'test@example.com', password: 'secret');
    await controller.createProfile(
      name: 'Owner User',
      preferredLanguage: 'pt',
      accountType: AccountUseChoice.pitchOwner,
      ownerInvitationCode: ' INVITE-123 ',
    );

    expect(capturedBody?['accountType'], 'PITCH_OWNER');
    expect(capturedBody?['ownerInvitationCode'], 'INVITE-123');
    expect(controller.state.profile?.capabilities.pitchOwner, isTrue);
  });

  test('signup stores pending pitch owner choice through profile lookup', () async {
    final auth = _FakeAuthService(signInSession: _session);
    final controller = _controllerFor(
      auth,
      _profileResponse(403, code: 'authenticated_user_not_found'),
    );

    await controller.signUp(
      email: 'owner@example.com',
      password: 'secret',
      accountChoice: AccountUseChoice.pitchOwner,
    );

    expect(controller.state.stage, AppSessionStage.profileMissing);
    expect(controller.state.pendingAccountChoice, AccountUseChoice.pitchOwner);
  });

  test('existing player activation refreshes pitch owner capability', () async {
    final auth = _FakeAuthService(signInSession: _session);
    final controller = _controllerFor(auth, (request) async {
      if (request.url.path.endsWith('/profile/pitch-owner')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['invitationCode'], 'OWNER-CODE');
        return _profileResponse(200, pitchOwner: true)(request);
      }
      return _profileResponse(200)(request);
    });

    await controller.signIn(email: 'test@example.com', password: 'secret');
    await controller.activatePitchOwner('OWNER-CODE');

    expect(controller.state.stage, AppSessionStage.ready);
    expect(controller.state.profile?.capabilities.pitchOwner, isTrue);
  });

  for (final code in [
    'owner_invitation_code_invalid',
    'owner_invitation_code_expired',
    'owner_invitation_code_used',
  ]) {
    test('owner activation surfaces $code errors', () async {
      final auth = _FakeAuthService(signInSession: _session);
      final controller = _controllerFor(auth, (request) async {
        if (request.url.path.endsWith('/profile/pitch-owner')) {
          return http.Response(
            jsonEncode({
              'code': code,
              'message': 'Invitation failed.',
              'timestamp': '2026-09-30T10:00:00Z',
              'fieldErrors': [],
            }),
            code.endsWith('_used') ? 409 : 400,
          );
        }
        return _profileResponse(200)(request);
      });

      await controller.signIn(email: 'test@example.com', password: 'secret');
      await controller.activatePitchOwner('BAD-CODE');

      expect(controller.state.stage, AppSessionStage.ready);
      expect(controller.state.message, contains(code));
      expect(controller.state.profile?.capabilities.pitchOwner, isFalse);
    });
  }

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
  bool pitchOwner = false,
}) {
  return (request) async {
    if (statusCode >= 200 && statusCode < 300) {
      return http.Response(
        jsonEncode({
          'id': 'user-1',
          'email': 'test@example.com',
          'name': 'Test User',
          'preferredLanguage': 'en',
          'capabilities': {'player': true, 'pitchOwner': pitchOwner},
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

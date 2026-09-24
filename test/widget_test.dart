import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peladinhas/auth/peladinhas_auth_service.dart';
import 'package:peladinhas/main.dart';
import 'package:peladinhas/models/auth_session.dart';
import 'package:peladinhas/network/peladinhas_api_client.dart';

void main() {
  testWidgets('shows clear configuration guidance when Supabase is missing', (
    tester,
  ) async {
    await tester.pumpWidget(const PeladinhasApp(hasSupabaseConfig: false));

    expect(
      find.text('Peladinhas authentication configuration is missing'),
      findsOneWidget,
    );
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });

  testWidgets('routes unauthenticated users to login and signup actions', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith(auth: _FakeAuthService()));
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Create Peladinhas Profile'), findsNothing);
  });

  testWidgets('routes authenticated users without a profile to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: _profileMissingResponse,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Peladinhas Profile'), findsWidgets);
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('shows main navigation when a profile exists', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: _profileResponse,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.textContaining('Welcome back, Test User'), findsOneWidget);
    expect(find.text('You have no upcoming matches.'), findsOneWidget);
    expect(find.text('Add pitch'), findsOneWidget);

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    expect(find.text('Create direct match'), findsOneWidget);
    expect(find.text('Open join'), findsOneWidget);
    expect(find.text('open_join'), findsNothing);

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('You don’t have any groups yet.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Pitches'));
    await tester.pumpAndSettle();
    expect(find.text('Pitches'), findsWidgets);
    expect(find.text('Price'), findsOneWidget);
    expect(find.text('Request booking'), findsOneWidget);
    expect(find.textContaining('No pitch selected yet.'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.textContaining('test@example.com'), findsOneWidget);
    expect(find.textContaining('Language: English'), findsOneWidget);
  });

  testWidgets('logout returns the app to authentication', (tester) async {
    final auth = _FakeAuthService(current: _session);
    await tester.pumpWidget(_appWith(auth: auth, handler: _profileResponse));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(auth.currentSession, isNull);
    expect(find.text('Log In'), findsOneWidget);
  });
}

final _session = AuthSession(
  accessToken: 'token',
  userId: 'supabase-user',
  email: 'test@example.com',
);

PeladinhasApp _appWith({
  required _FakeAuthService auth,
  Future<http.Response> Function(http.Request request)? handler,
}) {
  final apiClient = PeladinhasApiClient(
    baseUrl: 'http://localhost:8080/api/v1',
    tokenProvider: auth,
    httpClient: MockClient(handler ?? _profileResponse),
  );
  return PeladinhasApp(
    hasSupabaseConfig: true,
    authService: auth,
    apiClient: apiClient,
  );
}

Future<http.Response> _profileResponse(http.Request request) async {
  return http.Response(
    jsonEncode({
      'id': 'user-1',
      'email': 'test@example.com',
      'name': 'Test User',
      'preferredLanguage': 'en',
    }),
    200,
    headers: {'Content-Type': 'application/json'},
  );
}

Future<http.Response> _profileMissingResponse(http.Request request) async {
  return http.Response(
    jsonEncode({
      'code': 'authenticated_user_not_found',
      'message': 'Create a Peladinhas profile.',
      'timestamp': '2026-09-23T10:00:00Z',
      'fieldErrors': [],
    }),
    403,
    headers: {'Content-Type': 'application/json'},
  );
}

class _FakeAuthService implements PeladinhasAuthService {
  _FakeAuthService({this.current});

  AuthSession? current;
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
    current = _session;
    return AuthActionResult(session: current);
  }

  @override
  Future<AuthActionResult> signUp({
    required String email,
    required String password,
  }) async {
    current = _session;
    return AuthActionResult(session: current);
  }

  @override
  Future<void> signOut() async {
    current = null;
  }
}

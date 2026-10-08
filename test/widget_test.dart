import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peladinhas/auth/peladinhas_auth_service.dart';
import 'package:peladinhas/design/peladinhas_tokens.dart';
import 'package:peladinhas/main.dart';
import 'package:peladinhas/models/auth_session.dart';
import 'package:peladinhas/network/peladinhas_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Pitch owner'), findsOneWidget);
    expect(find.text('Create Peladinhas Profile'), findsNothing);
  });

  testWidgets('signup selection persists pitch owner onboarding choice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(signUpSession: _session),
        handler: _profileMissingResponse,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pitch owner'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Create Peladinhas Profile'), findsWidgets);
    expect(find.text('Invitation code'), findsOneWidget);
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
    expect(find.text('Invitation code'), findsNothing);
  });

  testWidgets('pitch owner onboarding shows code only when required', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: _profileMissingResponse,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invitation code'), findsNothing);

    await tester.tap(find.text('Pitch owner'));
    await tester.pumpAndSettle();

    expect(find.text('Invitation code'), findsOneWidget);
  });

  testWidgets('shows main navigation when a profile exists', (tester) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: _profileResponse(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.textContaining('Welcome back, Test User'), findsOneWidget);
    expect(find.text('You have no upcoming matches.'), findsOneWidget);
    expect(find.text('Add pitch'), findsNothing);
    expect(find.text('Pitch admin'), findsNothing);

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a match').last);
    await tester.pumpAndSettle();
    expect(find.text('Create a match'), findsWidgets);
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
    expect(find.textContaining('Create or select a match'), findsOneWidget);
    expect(find.textContaining('No pitch selected yet.'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.textContaining('test@example.com'), findsOneWidget);
    expect(find.textContaining('Language: English'), findsOneWidget);
    expect(find.text('Become a pitch owner'), findsOneWidget);
  });

  testWidgets('theme uses bundled Manrope with deliberate fallbacks', (
    tester,
  ) async {
    ThemeData? theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPeladinhasTheme(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(theme?.textTheme.bodyMedium?.fontFamily, 'Manrope');
    expect(
      theme?.textTheme.bodyMedium?.fontFamilyFallback,
      PeladinhasTypography.fontFamilyFallback,
    );
    expect(PeladinhasTypography.body.fontWeight, FontWeight.w400);
    expect(PeladinhasTypography.eyebrow.fontWeight, FontWeight.w500);
    expect(PeladinhasTypography.label.fontWeight, FontWeight.w600);
    expect(PeladinhasTypography.display.fontWeight, FontWeight.w700);

    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final manrope = manifest.cast<Map<String, dynamic>>().singleWhere(
      (font) => font['family'] == 'Manrope',
    );
    final weights = (manrope['fonts'] as List)
        .cast<Map<String, dynamic>>()
        .map((font) => font['weight'])
        .toSet();
    final assets = (manrope['fonts'] as List)
        .cast<Map<String, dynamic>>()
        .map((font) => Uri.decodeFull(font['asset'] as String))
        .toSet();

    expect(weights, <int>{400, 500, 600, 700});
    expect(assets, {
      'assets/fonts/manrope/Manrope-Regular.ttf',
      'assets/fonts/manrope/Manrope-Medium.ttf',
      'assets/fonts/manrope/Manrope-SemiBold.ttf',
      'assets/fonts/manrope/Manrope-Bold.ttf',
    });
  });

  testWidgets('authenticated shell renders at representative widths', (
    tester,
  ) async {
    for (final width in const [
      1440.0,
      1200.0,
      1199.0,
      1024.0,
      768.0,
      767.0,
      390.0,
      360.0,
    ]) {
      await _useViewport(tester, Size(width, 900));
      await tester.pumpWidget(
        _appWith(
          auth: _FakeAuthService(current: _session),
          handler: _profileResponse(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Welcome back, Test User'), findsOneWidget);
      final navigationBarFinder = find.byKey(const Key('mobile-navigation'));
      final desktopSidebarFinder = find.byKey(const Key('desktop-sidebar'));
      final tabletSidebarFinder = find.byKey(const Key('tablet-sidebar'));

      if (width >= 1200) {
        expect(desktopSidebarFinder, findsOneWidget);
        expect(tabletSidebarFinder, findsNothing);
        expect(navigationBarFinder, findsNothing);
      } else if (width >= 768) {
        expect(desktopSidebarFinder, findsNothing);
        expect(tabletSidebarFinder, findsOneWidget);
        expect(navigationBarFinder, findsNothing);
      } else {
        expect(desktopSidebarFinder, findsNothing);
        expect(tabletSidebarFinder, findsNothing);
        expect(navigationBarFinder, findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('nav-matches')));
      await tester.pumpAndSettle();
      expect(find.text('Find a match'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('existing player activates owner mode from profile', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: (request) async {
          if (request.url.path.endsWith('/profile/pitch-owner')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['invitationCode'], 'OWNER-CODE');
            return _profileResponse(pitchOwner: true)(request);
          }
          return _profileResponse()(request);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activate owner mode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'OWNER-CODE');
    await tester.tap(find.text('Activate owner mode'));
    await tester.pumpAndSettle();

    expect(find.text('Pitch admin'), findsOneWidget);
    expect(find.text('Invitation code'), findsNothing);
    expect(find.text('OWNER-CODE'), findsNothing);
  });

  testWidgets('invalid owner activation shows readable error', (tester) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: (request) async {
          if (request.url.path.endsWith('/profile/pitch-owner')) {
            return http.Response(
              jsonEncode({
                'code': 'owner_invitation_code_invalid',
                'message': 'Pitch owner invitation code is invalid.',
                'timestamp': '2026-09-30T10:00:00Z',
                'fieldErrors': [],
              }),
              400,
              headers: {'Content-Type': 'application/json'},
            );
          }
          return _profileResponse()(request);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activate owner mode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'BAD-CODE');
    await tester.tap(find.text('Activate owner mode'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('owner_invitation_code_invalid'),
      findsOneWidget,
    );
  });

  testWidgets('owner receives switch and keeps player navigation', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: _ownerHandler,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player mode'), findsOneWidget);
    expect(find.text('Pitch admin'), findsOneWidget);
    expect(find.text('Matches'), findsWidgets);

    await tester.tap(find.text('Pitch admin'));
    await tester.pumpAndSettle();

    expect(find.text('Owner dashboard'), findsWidgets);
    expect(find.text('My pitches'), findsWidgets);
    expect(find.text('Bookings'), findsWidgets);

    await tester.tap(find.text('Player'));
    await tester.pumpAndSettle();

    expect(find.text('Matches'), findsWidgets);
    expect(find.text('Log In'), findsNothing);
  });

  testWidgets('owner pitch and booking data render from owner endpoints', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: _ownerHandler,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pitch admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My pitches').first);
    await tester.pumpAndSettle();

    expect(find.text('Central Pitch'), findsOneWidget);
    expect(find.textContaining('Lisbon'), findsWidgets);

    await tester.tap(find.text('Bookings').first);
    await tester.pumpAndSettle();

    expect(find.text('Booking provisional'), findsOneWidget);
    expect(find.textContaining('60'), findsOneWidget);
  });

  testWidgets('owner empty states render from empty owner endpoints', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: (request) async {
          if (request.url.path.endsWith('/pitches/mine') ||
              request.url.path.endsWith('/bookings/owner')) {
            return http.Response('[]', 200);
          }
          return _profileResponse(pitchOwner: true)(request);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pitch admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My pitches').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('No pitches yet.'), findsOneWidget);

    await tester.tap(find.text('Bookings').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('No bookings yet.'), findsOneWidget);
  });

  testWidgets('owner dashboard failure is not shown as zero counts', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    var pitchRequests = 0;
    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: (request) async {
          if (request.url.path.endsWith('/pitches/mine')) {
            pitchRequests += 1;
            if (pitchRequests == 1) {
              return _serverError();
            }
            return http.Response('[]', 200);
          }
          if (request.url.path.endsWith('/bookings/owner')) {
            return http.Response('[]', 200);
          }
          return _profileResponse(pitchOwner: true)(request);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pitch admin'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't load"), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Retry'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(pitchRequests, 2);
  });

  testWidgets('owner pitches failure is not shown as an empty list', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    var pitchRequests = 0;
    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: (request) async {
          if (request.url.path.endsWith('/pitches/mine')) {
            pitchRequests += 1;
            if (pitchRequests == 2) {
              return _serverError();
            }
            return http.Response('[]', 200);
          }
          if (request.url.path.endsWith('/bookings/owner')) {
            return http.Response('[]', 200);
          }
          return _profileResponse(pitchOwner: true)(request);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pitch admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My pitches').first);
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't load"), findsOneWidget);
    expect(find.textContaining('No pitches yet.'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Retry'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(pitchRequests, greaterThan(1));
  });

  testWidgets('owner bookings failure is not shown as an empty list', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    var bookingRequests = 0;
    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: (request) async {
          if (request.url.path.endsWith('/pitches/mine')) {
            return http.Response('[]', 200);
          }
          if (request.url.path.endsWith('/bookings/owner')) {
            bookingRequests += 1;
            if (bookingRequests == 2) {
              return _serverError();
            }
            return http.Response('[]', 200);
          }
          return _profileResponse(pitchOwner: true)(request);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pitch admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings').first);
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't load"), findsOneWidget);
    expect(find.textContaining('No bookings yet.'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Retry'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(bookingRequests, greaterThan(1));
  });

  testWidgets('player cannot access owner screens from stored mode', (
    tester,
  ) async {
    await _useDesktopViewport(tester);

    SharedPreferences.setMockInitialValues({
      'peladinhas.selectedMode': 'owner',
    });
    await tester.pumpWidget(
      _appWith(
        auth: _FakeAuthService(current: _session),
        handler: _profileResponse(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pitch admin'), findsNothing);
    expect(find.text('Owner dashboard'), findsNothing);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('logout returns the app to authentication', (tester) async {
    await _useDesktopViewport(tester);

    final auth = _FakeAuthService(current: _session);
    await tester.pumpWidget(_appWith(auth: auth, handler: _profileResponse()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(auth.currentSession, isNull);
    expect(find.text('Log In'), findsOneWidget);
  });
}

Future<void> _useDesktopViewport(WidgetTester tester) async {
  await _useViewport(tester, const Size(1440, 1024));
}

Future<void> _useViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
    httpClient: MockClient(handler ?? _profileResponse()),
  );
  return PeladinhasApp(
    hasSupabaseConfig: true,
    authService: auth,
    apiClient: apiClient,
  );
}

Future<http.Response> Function(http.Request request) _profileResponse({
  bool pitchOwner = false,
}) {
  return (request) async {
    return http.Response(
      jsonEncode({
        'id': 'user-1',
        'email': 'test@example.com',
        'name': 'Test User',
        'preferredLanguage': 'en',
        'capabilities': {'player': true, 'pitchOwner': pitchOwner},
      }),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  };
}

Future<http.Response> _ownerHandler(http.Request request) async {
  if (request.url.path.endsWith('/pitches/mine')) {
    return http.Response(
      jsonEncode([
        {
          'id': 'pitch-1',
          'ownerUserId': 'user-1',
          'name': 'Central Pitch',
          'address': 'Lisbon',
          'basePrice': 60,
          'currency': 'EUR',
          'active': true,
        },
      ]),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  }
  if (request.url.path.endsWith('/bookings/owner')) {
    return http.Response(
      jsonEncode([
        {
          'id': 'booking-1',
          'matchId': 'match-1',
          'pitchId': 'pitch-1',
          'startsAt': '2026-09-30T10:00:00Z',
          'endsAt': '2026-09-30T11:00:00Z',
          'totalPrice': 60,
          'currency': 'EUR',
          'status': 'provisional',
        },
      ]),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  }
  return _profileResponse(pitchOwner: true)(request);
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

http.Response _serverError() {
  return http.Response(
    jsonEncode({
      'code': 'server_error',
      'message': 'Temporary failure.',
      'timestamp': '2026-09-30T10:00:00Z',
      'fieldErrors': [],
    }),
    500,
    headers: {'Content-Type': 'application/json'},
  );
}

class _FakeAuthService implements PeladinhasAuthService {
  _FakeAuthService({this.current, this.signUpSession});

  AuthSession? current;
  AuthSession? signUpSession;
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
    current = signUpSession;
    return AuthActionResult(session: current);
  }

  @override
  Future<void> signOut() async {
    current = null;
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peladinhas/auth/peladinhas_auth_service.dart';
import 'package:peladinhas/models/match.dart';
import 'package:peladinhas/models/match_discovery.dart';
import 'package:peladinhas/models/user_profile.dart';
import 'package:peladinhas/network/peladinhas_api_client.dart';

void main() {
  test('selects open join endpoint', () {
    final client = PeladinhasApiClient(baseUrl: 'http://localhost:8080/api/v1');

    expect(
      client.joinEndpointFor(JoinMode.openJoin, 'match-1'),
      '/matches/match-1/join',
    );
  });

  test('selects request to join endpoint', () {
    final client = PeladinhasApiClient(baseUrl: 'http://localhost:8080/api/v1');

    expect(
      client.joinEndpointFor(JoinMode.requestToJoin, 'match-1'),
      '/matches/match-1/join-requests',
    );
  });

  test('does not call protected API without a session token', () async {
    var called = false;
    final client = PeladinhasApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenProvider: _FakeTokenProvider(null),
      httpClient: MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    expect(
      client.getProfile(),
      throwsA(isA<PeladinhasAuthRequiredException>()),
    );
    expect(called, isFalse);
  });

  test('adds bearer token to authenticated backend requests', () async {
    late http.BaseRequest captured;
    final client = PeladinhasApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'email': 'test@example.com',
            'name': 'Test User',
            'preferredLanguage': 'en',
          }),
          200,
        );
      }),
    );

    await client.getProfile();

    expect(captured.headers['Authorization'], 'Bearer test-token');
  });

  test('creates pitch owner profile with backend account fields', () async {
    late Map<String, dynamic> body;
    final client = PeladinhasApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_profileJson(pitchOwner: true), 201);
      }),
    );

    final profile = await client.createProfile(
      const CreateProfileRequest(
        name: 'Owner',
        preferredLanguage: 'en',
        accountType: AccountUseChoice.pitchOwner,
        ownerInvitationCode: ' CODE-1 ',
      ),
    );

    expect(body['accountType'], 'PITCH_OWNER');
    expect(body['ownerInvitationCode'], 'CODE-1');
    expect(profile.capabilities.pitchOwner, isTrue);
  });

  test('activates pitch owner capability using invitationCode', () async {
    late Map<String, dynamic> body;
    final client = PeladinhasApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/profile/pitch-owner');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_profileJson(pitchOwner: true), 200);
      }),
    );

    final profile = await client.activatePitchOwner(' OWNER-CODE ');

    expect(body, {'invitationCode': 'OWNER-CODE'});
    expect(profile.capabilities.pitchOwner, isTrue);
  });

  test('loads owner pitches and bookings', () async {
    final client = PeladinhasApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/pitches/mine')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'pitch-1',
                'ownerUserId': 'owner-1',
                'name': 'Central Pitch',
                'address': 'Lisbon',
                'basePrice': 60,
                'currency': 'EUR',
                'active': true,
              },
            ]),
            200,
          );
        }
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
        );
      }),
    );

    final pitches = await client.getMyPitches();
    final bookings = await client.getOwnerBookings();

    expect(pitches.single.name, 'Central Pitch');
    expect(bookings.single.status, 'provisional');
    expect(bookings.single.startsAt, isNotNull);
  });

  test('loads match discovery with filters and bearer token', () async {
    late http.BaseRequest captured;
    final client = PeladinhasApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      tokenProvider: _FakeTokenProvider('test-token'),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'matches': [
              {
                'matchId': '00000000-0000-4000-8000-000000000101',
                'displayName': 'Sunday Football',
                'startsAt': '2026-10-10T18:00:00Z',
                'endsAt': '2026-10-10T19:30:00Z',
                'durationMinutes': 90,
                'maxPlayers': 10,
                'occupiedPlaces': 6,
                'availablePlaces': 4,
                'pitchId': 'pitch-1',
                'pitchName': 'Central Pitch',
                'pitchAddress': 'Lisbon',
                'pitchBasePrice': 60,
                'pitchCurrency': 'EUR',
                'groupVisibility': 'public',
                'joinMode': 'request_to_join',
              },
            ],
            'page': 2,
            'size': 10,
            'totalElements': 21,
            'totalPages': 3,
          }),
          200,
        );
      }),
    );

    final page = await client.discoverMatches(
      filters: MatchDiscoveryFilters(
        area: 'Lisbon North',
        startsFrom: DateTime.utc(2026, 10, 10),
        startsTo: DateTime.utc(2026, 10, 11),
        timeFrom: '18:00',
        timeTo: '22:30',
        joinMode: JoinMode.requestToJoin,
        availableOnly: true,
      ),
      page: 2,
      size: 10,
    );

    expect(captured.headers['Authorization'], 'Bearer test-token');
    expect(captured.url.path, '/api/v1/matches/discovery');
    expect(captured.url.queryParameters['area'], 'Lisbon North');
    expect(captured.url.queryParameters['startsFrom'], contains('2026-10-10'));
    expect(captured.url.queryParameters['startsTo'], contains('2026-10-11'));
    expect(captured.url.queryParameters['timeFrom'], '18:00');
    expect(captured.url.queryParameters['timeTo'], '22:30');
    expect(captured.url.queryParameters['joinMode'], 'request_to_join');
    expect(captured.url.queryParameters['availableOnly'], 'true');
    expect(captured.url.queryParameters['page'], '2');
    expect(captured.url.queryParameters['size'], '10');
    expect(page.matches.single.displayName, 'Sunday Football');
    expect(page.matches.single.joinMode, JoinMode.requestToJoin);
    expect(page.hasMore, isFalse);
  });
}

String _profileJson({bool pitchOwner = false}) {
  return jsonEncode({
    'id': 'user-1',
    'email': 'test@example.com',
    'name': 'Test User',
    'preferredLanguage': 'en',
    'capabilities': {'player': true, 'pitchOwner': pitchOwner},
  });
}

class _FakeTokenProvider implements AccessTokenProvider {
  const _FakeTokenProvider(this.token);

  final String? token;

  @override
  Future<String?> accessToken() async => token;
}

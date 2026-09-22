import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peladinhas/auth/peladinhas_auth_service.dart';
import 'package:peladinhas/models/match.dart';
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

    expect(client.getProfile(), throwsA(isA<PeladinhasAuthRequiredException>()));
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
}

class _FakeTokenProvider implements AccessTokenProvider {
  const _FakeTokenProvider(this.token);

  final String? token;

  @override
  Future<String?> accessToken() async => token;
}

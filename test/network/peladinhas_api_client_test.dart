import 'package:flutter_test/flutter_test.dart';
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
}

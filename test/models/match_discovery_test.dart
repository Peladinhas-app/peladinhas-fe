import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/models/match.dart';
import 'package:peladinhas/models/match_discovery.dart';

void main() {
  test('parses match discovery page response', () {
    final page = MatchDiscoveryPage.fromJson({
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
          'joinMode': 'open_join',
        },
      ],
      'page': 0,
      'size': 10,
      'totalElements': 11,
      'totalPages': 2,
    });

    final match = page.matches.single;

    expect(page.hasMore, isTrue);
    expect(match.matchId, '00000000-0000-4000-8000-000000000101');
    expect(match.displayName, 'Sunday Football');
    expect(match.startsAt.toUtc().hour, 18);
    expect(match.endsAt.toUtc().minute, 30);
    expect(match.joinMode, JoinMode.openJoin);
    expect(match.pitchBasePrice, 60);
  });

  test('discovery filters omit empty values and preserve API enum codes', () {
    final query = MatchDiscoveryFilters(
      area: '  ',
      startsFrom: DateTime.utc(2026, 10, 10, 18),
      timeFrom: '19:00',
      joinMode: JoinMode.requestToJoin,
      availableOnly: true,
    ).toQueryParameters(page: 1, size: 20);

    expect(query.containsKey('area'), isFalse);
    expect(query['startsFrom'], '2026-10-10T18:00:00.000Z');
    expect(query['timeFrom'], '19:00');
    expect(query['joinMode'], 'request_to_join');
    expect(query['availableOnly'], 'true');
    expect(query['page'], '1');
    expect(query['size'], '20');
  });

  test('rejects malformed required discovery fields', () {
    final valid = _validPage();

    expect(
      () => MatchDiscoveryPage.fromJson({
        ...valid,
        'matches': [
          {..._validMatch(), 'matchId': 'not-a-uuid'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => MatchDiscoveryPage.fromJson({
        ...valid,
        'matches': [
          {..._validMatch(), 'displayName': ' '},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => MatchDiscoveryPage.fromJson({
        ...valid,
        'matches': [
          {..._validMatch(), 'startsAt': 'not-a-date'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => MatchDiscoveryPage.fromJson({
        ...valid,
        'matches': [
          {..._validMatch(), 'maxPlayers': 'many'},
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'rejects unsupported discovery join mode without open join fallback',
    () {
      expect(
        () => MatchDiscoveryItem.fromJson({
          ..._validMatch(),
          'joinMode': 'invite_only',
        }),
        throwsFormatException,
      );
    },
  );

  test('accepts valid nullable pitch fields', () {
    final match = MatchDiscoveryItem.fromJson({
      ..._validMatch(),
      'pitchId': null,
      'pitchName': null,
      'pitchAddress': null,
      'pitchBasePrice': null,
      'pitchCurrency': null,
    });

    expect(match.pitchId, isNull);
    expect(match.pitchName, isNull);
    expect(match.pitchBasePrice, isNull);
  });

  test('rejects invalid page metadata', () {
    expect(
      () => MatchDiscoveryPage.fromJson({..._validPage(), 'page': -1}),
      throwsFormatException,
    );
    expect(
      () =>
          MatchDiscoveryPage.fromJson({..._validPage(), 'totalPages': 'many'}),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _validPage() {
  return {
    'matches': [_validMatch()],
    'page': 0,
    'size': 10,
    'totalElements': 1,
    'totalPages': 1,
  };
}

Map<String, dynamic> _validMatch() {
  return {
    'matchId': '00000000-0000-4000-8000-000000000101',
    'displayName': 'Sunday Football',
    'startsAt': '2026-10-10T18:00:00Z',
    'endsAt': '2026-10-10T19:30:00Z',
    'durationMinutes': 90,
    'maxPlayers': 10,
    'occupiedPlaces': 6,
    'availablePlaces': 4,
    'pitchId': '00000000-0000-4000-8000-000000000201',
    'pitchName': 'Central Pitch',
    'pitchAddress': 'Lisbon',
    'pitchBasePrice': 60,
    'pitchCurrency': 'EUR',
    'groupVisibility': 'public',
    'joinMode': 'open_join',
  };
}

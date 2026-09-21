import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/models/match.dart';

void main() {
  test('parses match response json', () {
    final match = Match.fromJson({
      'id': 'match-123',
      'groupName': 'Thursday football',
      'startsAt': '2026-10-01T19:00:00Z',
      'endsAt': '2026-10-01T20:30:00Z',
      'durationMinutes': 90,
      'maxPlayers': 10,
      'joinMode': 'open_join',
      'status': 'draft',
      'publicVacanciesEnabled': true,
    });

    expect(match.id, 'match-123');
    expect(match.groupName, 'Thursday football');
    expect(match.durationMinutes, 90);
    expect(match.maxPlayers, 10);
    expect(match.joinMode, JoinMode.openJoin);
    expect(match.status, 'draft');
    expect(match.isDraft, isTrue);
    expect(match.publicVacanciesEnabled, isTrue);
  });

  test('derives duration when backend omits durationMinutes', () {
    final match = Match.fromJson({
      'matchId': 'match-456',
      'name': 'Late match',
      'startsAt': '2026-10-01T19:00:00Z',
      'endsAt': '2026-10-01T21:00:00Z',
      'maxPlayers': '12',
      'joinMode': 'request_to_join',
      'status': 'RECRUITING',
    });

    expect(match.durationMinutes, 120);
    expect(match.maxPlayers, 12);
    expect(match.joinMode, JoinMode.requestToJoin);
    expect(match.status, 'recruiting');
    expect(match.isRecruiting, isTrue);
  });
}

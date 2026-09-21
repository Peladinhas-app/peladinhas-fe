import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/models/participant.dart';

void main() {
  test('parses direct participant response json', () {
    final participant = Participant.fromJson({
      'userId': '00000000-0000-4000-8000-000000000002',
      'status': 'awaiting_payment',
      'joinedAt': '2026-10-01T18:01:00Z',
      'confirmedAt': null,
      'cancelledAt': null,
    });

    expect(participant.userId, '00000000-0000-4000-8000-000000000002');
    expect(participant.status, 'awaiting_payment');
    expect(participant.joinedAt, isNotNull);
    expect(participant.confirmedAt, isNull);
    expect(participant.cancelledAt, isNull);
  });

  test('parses nested user participant response json', () {
    final participant = Participant.fromJson({
      'user': {'id': 'player-2'},
      'status': 'requested',
    });

    expect(participant.userId, 'player-2');
    expect(participant.status, 'requested');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/models/booking.dart';

void main() {
  test('serializes provisional booking using only allowed fields', () {
    const request = CreateBookingRequest(
      matchId: 'match-1',
      pitchId: 'pitch-1',
      totalPrice: 60,
      currency: 'EUR',
    );

    expect(request.toJson(), {
      'matchId': 'match-1',
      'pitchId': 'pitch-1',
      'totalPrice': 60,
      'currency': 'EUR',
    });
    expect(request.toJson().containsKey('startsAt'), isFalse);
    expect(request.toJson().containsKey('endsAt'), isFalse);
    expect(request.toJson().containsKey('actingUserId'), isFalse);
    expect(request.toJson().containsKey('creatorUserId'), isFalse);
    expect(request.toJson().containsKey('adminUserId'), isFalse);
  });
}

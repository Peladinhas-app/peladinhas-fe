import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/models/pitch.dart';

void main() {
  test('serializes pitch creation using the backend contract', () {
    final request = CreatePitchRequest(
      name: 'Test Pitch',
      description: 'Technical test pitch',
      address: 'Lisbon',
      latitude: 38.72,
      longitude: -9.14,
      timezone: 'Europe/Lisbon',
      basePrice: 60,
      currency: 'EUR',
      active: true,
    );

    expect(request.toJson(), {
      'name': 'Test Pitch',
      'description': 'Technical test pitch',
      'address': 'Lisbon',
      'latitude': 38.72,
      'longitude': -9.14,
      'timezone': 'Europe/Lisbon',
      'basePrice': 60,
      'currency': 'EUR',
      'active': true,
    });
  });

  test('serializes pitch schedule using startsAt and endsAt', () {
    const request = CreatePitchScheduleRequest(
      dayOfWeek: 2,
      startsAt: '00:00',
      endsAt: '23:59',
    );

    expect(request.toJson(), {
      'dayOfWeek': 2,
      'startsAt': '00:00',
      'endsAt': '23:59',
    });
  });

  test('parses availability boolean from backend response', () {
    final availability = PitchAvailability.fromJson({'available': true});

    expect(availability.isAvailable, isTrue);
  });
}

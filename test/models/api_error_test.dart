import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/models/api_error.dart';

void main() {
  test('parses api error response json', () {
    final error = ApiError.fromJson({
      'code': 'validation_error',
      'message': 'Invalid request',
      'timestamp': '2026-10-01T18:01:00Z',
      'fieldErrors': {
        'groupName': 'must not be blank',
      },
    });

    expect(error.code, 'validation_error');
    expect(error.message, 'Invalid request');
    expect(error.timestamp, isNotNull);
    expect(error.fieldErrors['groupName'], 'must not be blank');
    expect(error.displayMessage, contains('groupName'));
  });

  test('parses list-shaped field errors', () {
    final error = ApiError.fromJson({
      'code': 'validation_error',
      'message': 'Invalid request',
      'fieldErrors': [
        {'field': 'startsAt', 'message': 'must be in the future'},
      ],
    });

    expect(error.fieldErrors['startsAt'], 'must be in the future');
  });
}

class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.timestamp,
    this.fieldErrors = const {},
  });

  final String code;
  final String message;
  final DateTime? timestamp;
  final Map<String, String> fieldErrors;

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final rawFieldErrors = json['fieldErrors'];
    final parsedFieldErrors = <String, String>{};

    if (rawFieldErrors is Map) {
      for (final entry in rawFieldErrors.entries) {
        parsedFieldErrors[entry.key.toString()] = entry.value.toString();
      }
    }

    if (rawFieldErrors is List) {
      for (final item in rawFieldErrors) {
        if (item is Map) {
          final field = item['field'] ?? item['name'] ?? item['path'];
          final message = item['message'] ?? item['error'] ?? item['reason'];
          if (field != null && message != null) {
            parsedFieldErrors[field.toString()] = message.toString();
          }
        }
      }
    }

    return ApiError(
      code: (json['code'] ?? 'unknown_error').toString(),
      message: (json['message'] ?? 'The backend returned an error.').toString(),
      timestamp: _parseDate(json['timestamp']),
      fieldErrors: parsedFieldErrors,
    );
  }

  String get displayMessage {
    if (fieldErrors.isEmpty) {
      return '$code: $message';
    }

    final fields = fieldErrors.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
    return '$code: $message ($fields)';
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}

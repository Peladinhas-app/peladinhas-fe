enum JoinMode {
  openJoin('open_join'),
  requestToJoin('request_to_join');

  const JoinMode(this.apiValue);

  final String apiValue;

  static JoinMode fromApi(String value) {
    return JoinMode.values.firstWhere(
      (mode) => mode.apiValue == value,
      orElse: () => JoinMode.openJoin,
    );
  }
}

class Match {
  const Match({
    required this.id,
    required this.groupName,
    required this.startsAt,
    required this.endsAt,
    required this.durationMinutes,
    required this.maxPlayers,
    required this.joinMode,
    required this.status,
    this.groupDescription,
    this.publicVacanciesEnabled,
  });

  final String id;
  final String groupName;
  final String? groupDescription;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationMinutes;
  final int maxPlayers;
  final JoinMode joinMode;
  final String status;
  final bool? publicVacanciesEnabled;

  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isRecruiting => status.toLowerCase() == 'recruiting';

  factory Match.fromJson(Map<String, dynamic> json) {
    final startsAt = _date(json, ['startsAt', 'startTime', 'startDateTime']);
    final endsAt = _date(json, ['endsAt', 'endTime', 'endDateTime']);
    final duration = _int(json, ['durationMinutes']) ??
        endsAt.difference(startsAt).inMinutes;

    return Match(
      id: _string(json, ['id', 'matchId']),
      groupName: _string(json, ['groupName', 'name', 'title']),
      groupDescription: _nullableString(json, ['groupDescription', 'description']),
      startsAt: startsAt,
      endsAt: endsAt,
      durationMinutes: duration,
      maxPlayers: _int(json, ['maxPlayers', 'playerLimit']) ?? 0,
      joinMode: JoinMode.fromApi(_string(json, ['joinMode'])),
      status: _string(json, ['status']).toLowerCase(),
      publicVacanciesEnabled:
          _bool(json, ['publicVacanciesEnabled', 'publicVacancies']),
    );
  }

  static String _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        return value.toString();
      }
    }
    return '';
  }

  static String? _nullableString(Map<String, dynamic> json, List<String> keys) {
    final value = _string(json, keys);
    return value.isEmpty ? null : value;
  }

  static DateTime _date(Map<String, dynamic> json, List<String> keys) {
    final value = _string(json, keys);
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value);
      }
    }
    return null;
  }

  static bool? _bool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        return bool.tryParse(value);
      }
    }
    return null;
  }
}

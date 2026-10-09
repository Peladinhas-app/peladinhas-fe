import 'match.dart';

class MatchDiscoveryPage {
  const MatchDiscoveryPage({
    required this.matches,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<MatchDiscoveryItem> matches;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  factory MatchDiscoveryPage.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'];
    if (rawMatches is! List) {
      throw const FormatException('Match discovery matches must be a list.');
    }
    final matches = rawMatches.map((item) {
      if (item is! Map) {
        throw const FormatException('Match discovery item must be an object.');
      }
      return MatchDiscoveryItem.fromJson(Map.from(item));
    }).toList();
    return MatchDiscoveryPage(
      matches: matches,
      page: _requiredInt(json['page'], 'page', minimum: 0),
      size: _requiredInt(json['size'], 'size', minimum: 1),
      totalElements: _requiredInt(
        json['totalElements'],
        'totalElements',
        minimum: 0,
      ),
      totalPages: _requiredInt(json['totalPages'], 'totalPages', minimum: 0),
    );
  }
}

class MatchDiscoveryItem {
  const MatchDiscoveryItem({
    required this.matchId,
    required this.displayName,
    required this.startsAt,
    required this.endsAt,
    required this.durationMinutes,
    required this.maxPlayers,
    required this.occupiedPlaces,
    required this.availablePlaces,
    required this.groupVisibility,
    required this.joinMode,
    this.pitchId,
    this.pitchName,
    this.pitchAddress,
    this.pitchBasePrice,
    this.pitchCurrency,
  });

  final String matchId;
  final String displayName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationMinutes;
  final int maxPlayers;
  final int occupiedPlaces;
  final int availablePlaces;
  final String? pitchId;
  final String? pitchName;
  final String? pitchAddress;
  final num? pitchBasePrice;
  final String? pitchCurrency;
  final String groupVisibility;
  final JoinMode joinMode;

  factory MatchDiscoveryItem.fromJson(Map<String, dynamic> json) {
    return MatchDiscoveryItem(
      matchId: _requiredUuid(json['matchId'], 'matchId'),
      displayName: _requiredString(json['displayName'], 'displayName'),
      startsAt: _requiredDate(json['startsAt'], 'startsAt'),
      endsAt: _requiredDate(json['endsAt'], 'endsAt'),
      durationMinutes: _requiredInt(
        json['durationMinutes'],
        'durationMinutes',
        minimum: 1,
      ),
      maxPlayers: _requiredInt(json['maxPlayers'], 'maxPlayers', minimum: 1),
      occupiedPlaces: _requiredInt(
        json['occupiedPlaces'],
        'occupiedPlaces',
        minimum: 0,
      ),
      availablePlaces: _requiredInt(
        json['availablePlaces'],
        'availablePlaces',
        minimum: 0,
      ),
      pitchId: _nullableString(json['pitchId']),
      pitchName: _nullableString(json['pitchName']),
      pitchAddress: _nullableString(json['pitchAddress']),
      pitchBasePrice: _num(json['pitchBasePrice']),
      pitchCurrency: _nullableString(json['pitchCurrency']),
      groupVisibility: _string(json['groupVisibility']),
      joinMode: _requiredJoinMode(json['joinMode']),
    );
  }
}

class MatchDiscoveryFilters {
  const MatchDiscoveryFilters({
    this.area,
    this.startsFrom,
    this.startsTo,
    this.timeFrom,
    this.timeTo,
    this.joinMode,
    this.availableOnly = false,
  });

  final String? area;
  final DateTime? startsFrom;
  final DateTime? startsTo;
  final String? timeFrom;
  final String? timeTo;
  final JoinMode? joinMode;
  final bool availableOnly;

  Map<String, String> toQueryParameters({
    required int page,
    required int size,
  }) {
    return {
      if (area != null && area!.trim().isNotEmpty) 'area': area!.trim(),
      if (startsFrom != null)
        'startsFrom': startsFrom!.toUtc().toIso8601String(),
      if (startsTo != null) 'startsTo': startsTo!.toUtc().toIso8601String(),
      if (timeFrom != null && timeFrom!.isNotEmpty) 'timeFrom': timeFrom!,
      if (timeTo != null && timeTo!.isNotEmpty) 'timeTo': timeTo!,
      if (joinMode != null) 'joinMode': joinMode!.apiValue,
      if (availableOnly) 'availableOnly': 'true',
      'page': '$page',
      'size': '$size',
    };
  }
}

String _string(Object? value) => value?.toString() ?? '';

String _requiredString(Object? value, String field) {
  final text = _string(value).trim();
  if (text.isEmpty) {
    throw FormatException('Match discovery field $field is required.');
  }
  return text;
}

String _requiredUuid(Object? value, String field) {
  final text = _requiredString(value, field);
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  if (!uuid.hasMatch(text)) {
    throw FormatException('Match discovery field $field must be a UUID.');
  }
  return text;
}

String? _nullableString(Object? value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

DateTime _requiredDate(Object? value, String field) {
  final parsed = DateTime.tryParse(_requiredString(value, field));
  if (parsed == null) {
    throw FormatException('Match discovery field $field must be a date.');
  }
  return parsed;
}

int _requiredInt(Object? value, String field, {int? minimum}) {
  final parsed = _int(value);
  if (parsed == null) {
    throw FormatException('Match discovery field $field must be a number.');
  }
  if (minimum != null && parsed < minimum) {
    throw FormatException('Match discovery field $field is out of range.');
  }
  return parsed;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    if (value % 1 != 0) {
      return null;
    }
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

JoinMode _requiredJoinMode(Object? value) {
  final text = _requiredString(value, 'joinMode');
  for (final mode in JoinMode.values) {
    if (mode.apiValue == text) {
      return mode;
    }
  }
  throw const FormatException('Match discovery join mode is unsupported.');
}

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

class Pitch {
  const Pitch({
    required this.id,
    required this.name,
    this.address,
    this.basePrice,
    this.currency,
    this.active,
  });

  final String id;
  final String name;
  final String? address;
  final num? basePrice;
  final String? currency;
  final bool? active;

  factory Pitch.fromJson(Map<String, dynamic> json) {
    return Pitch(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Pitch',
      address: json['address']?.toString(),
      basePrice: json['basePrice'] as num?,
      currency: json['currency']?.toString(),
      active: json['active'] as bool?,
    );
  }
}

class CreatePitchRequest {
  const CreatePitchRequest({
    required this.name,
    required this.address,
    required this.timezone,
    required this.basePrice,
    required this.currency,
    required this.active,
    this.description,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String address;
  final String timezone;
  final num basePrice;
  final String currency;
  final bool active;
  final String? description;
  final num? latitude;
  final num? longitude;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'address': address.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'timezone': timezone,
      'basePrice': basePrice,
      'currency': currency,
      'active': active,
    };
  }
}

class CreatePitchScheduleRequest {
  const CreatePitchScheduleRequest({
    required this.dayOfWeek,
    required this.startsAt,
    required this.endsAt,
  });

  final int dayOfWeek;
  final String startsAt;
  final String endsAt;

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startsAt': startsAt,
      'endsAt': endsAt,
    };
  }
}

class PitchAvailability {
  const PitchAvailability({required this.raw});

  final Map<String, dynamic> raw;

  bool get isAvailable => raw['available'] == true;

  factory PitchAvailability.fromJson(Map<String, dynamic> json) {
    return PitchAvailability(raw: json);
  }
}

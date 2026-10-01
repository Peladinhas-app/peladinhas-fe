class Booking {
  const Booking({
    required this.id,
    required this.matchId,
    required this.pitchId,
    required this.status,
    required this.totalPrice,
    required this.currency,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.confirmedAt,
    this.rejectedAt,
    this.cancelledAt,
  });

  final String id;
  final String matchId;
  final String pitchId;
  final String status;
  final num totalPrice;
  final String currency;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'].toString(),
      matchId: json['matchId'].toString(),
      pitchId: json['pitchId'].toString(),
      status: json['status'].toString(),
      totalPrice: json['totalPrice'] as num? ?? 0,
      currency: json['currency']?.toString() ?? 'EUR',
      startsAt: _parseDate(json['startsAt']),
      endsAt: _parseDate(json['endsAt']),
      createdAt: _parseDate(json['createdAt']),
      confirmedAt: _parseDate(json['confirmedAt']),
      rejectedAt: _parseDate(json['rejectedAt']),
      cancelledAt: _parseDate(json['cancelledAt']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    return value == null ? null : DateTime.tryParse(value.toString());
  }
}

class CreateBookingRequest {
  const CreateBookingRequest({
    required this.matchId,
    required this.pitchId,
    required this.totalPrice,
    required this.currency,
  });

  final String matchId;
  final String pitchId;
  final num totalPrice;
  final String currency;

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'pitchId': pitchId,
      'totalPrice': totalPrice,
      'currency': currency,
    };
  }
}

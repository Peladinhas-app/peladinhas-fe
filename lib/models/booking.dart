class Booking {
  const Booking({
    required this.id,
    required this.matchId,
    required this.pitchId,
    required this.status,
    required this.totalPrice,
    required this.currency,
  });

  final String id;
  final String matchId;
  final String pitchId;
  final String status;
  final num totalPrice;
  final String currency;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'].toString(),
      matchId: json['matchId'].toString(),
      pitchId: json['pitchId'].toString(),
      status: json['status'].toString(),
      totalPrice: json['totalPrice'] as num? ?? 0,
      currency: json['currency']?.toString() ?? 'EUR',
    );
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

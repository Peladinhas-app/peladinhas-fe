class Participant {
  const Participant({
    required this.userId,
    required this.status,
    this.joinedAt,
    this.confirmedAt,
    this.cancelledAt,
  });

  final String userId;
  final String status;
  final DateTime? joinedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;

  factory Participant.fromJson(Map<String, dynamic> json) {
    final userObject = json['user'];
    final userId = json['userId'] ??
        json['participantUserId'] ??
        (userObject is Map ? userObject['id'] : null);

    return Participant(
      userId: userId?.toString() ?? '',
      status: (json['status'] ?? '').toString().toLowerCase(),
      joinedAt: _date(json['joinedAt']),
      confirmedAt: _date(json['confirmedAt']),
      cancelledAt: _date(json['cancelledAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}

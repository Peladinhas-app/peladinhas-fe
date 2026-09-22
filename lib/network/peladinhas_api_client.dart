import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/peladinhas_auth_service.dart';
import '../config/development_config.dart';
import '../models/api_error.dart';
import '../models/booking.dart';
import '../models/match.dart';
import '../models/participant.dart';
import '../models/pitch.dart';
import '../models/user_profile.dart';

class PeladinhasApiException implements Exception {
  const PeladinhasApiException(this.error, this.statusCode);

  final ApiError error;
  final int statusCode;

  @override
  String toString() => error.displayMessage;
}

class PeladinhasAuthRequiredException implements Exception {
  const PeladinhasAuthRequiredException();

  @override
  String toString() => 'Sign in before calling the protected backend API.';
}

class CreateDirectMatchRequest {
  const CreateDirectMatchRequest({
    required this.groupName,
    required this.startsAt,
    required this.durationMinutes,
    required this.maxPlayers,
    required this.joinMode,
    required this.publicVacanciesEnabled,
    this.groupDescription,
  });

  final String groupName;
  final String? groupDescription;
  final DateTime startsAt;
  final int durationMinutes;
  final int maxPlayers;
  final JoinMode joinMode;
  final bool publicVacanciesEnabled;

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      if (groupDescription != null && groupDescription!.trim().isNotEmpty)
        'groupDescription': groupDescription!.trim(),
      'startsAt': startsAt.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      'maxPlayers': maxPlayers,
      'joinMode': joinMode.apiValue,
      'publicVacanciesEnabled': publicVacanciesEnabled,
    };
  }
}

class PeladinhasApiClient {
  PeladinhasApiClient({
    http.Client? httpClient,
    String baseUrl = DevelopmentConfig.apiBaseUrl,
    this.tokenProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUri = Uri.parse(baseUrl);

  final http.Client _httpClient;
  final AccessTokenProvider? tokenProvider;
  final Uri _baseUri;

  Future<UserProfile> getProfile() async {
    final response = await _get('/profile');
    return UserProfile.fromJson(_decodeObject(response));
  }

  Future<UserProfile> createProfile(CreateProfileRequest request) async {
    final response = await _post('/profile', request.toJson());
    return UserProfile.fromJson(_decodeObject(response));
  }

  Future<Match> createDirectMatch(CreateDirectMatchRequest request) async {
    final response = await _post('/matches/direct', request.toJson());
    return Match.fromJson(_decodeObject(response));
  }

  Future<Match> transitionMatchStatus({
    required String matchId,
    required String nextStatus,
  }) async {
    final response = await _post(
      '/matches/$matchId/status-transitions',
      {
        'nextStatus': nextStatus,
      },
    );
    return Match.fromJson(_decodeObject(response));
  }

  Future<Match> getMatch(String matchId) async {
    final response = await _get('/matches/$matchId');
    _ensureSuccess(response);
    return Match.fromJson(_decodeObject(response));
  }

  Future<Participant> joinOpenMatch(String matchId) async {
    final response = await _post(
      joinEndpointFor(JoinMode.openJoin, matchId),
      const {},
    );
    return Participant.fromJson(_decodeObject(response));
  }

  Future<Participant> requestToJoin(String matchId) async {
    final response = await _post(
      joinEndpointFor(JoinMode.requestToJoin, matchId),
      const {},
    );
    return Participant.fromJson(_decodeObject(response));
  }

  Future<Pitch> createPitch(CreatePitchRequest request) async {
    final response = await _post('/pitches', request.toJson());
    return Pitch.fromJson(_decodeObject(response));
  }

  Future<Map<String, dynamic>> createPitchSchedule({
    required String pitchId,
    required CreatePitchScheduleRequest request,
  }) async {
    final response = await _post(
      '/pitches/$pitchId/schedules',
      request.toJson(),
    );
    return _decodeObject(response);
  }

  Future<PitchAvailability> getPitchAvailability({
    required String pitchId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final response = await _get(
      '/pitches/$pitchId/availability',
      queryParameters: {
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
      },
    );
    return PitchAvailability.fromJson(_decodeObject(response));
  }

  Future<Booking> createBooking(CreateBookingRequest request) async {
    final response = await _post('/bookings', request.toJson());
    return Booking.fromJson(_decodeObject(response));
  }

  String joinEndpointFor(JoinMode joinMode, String matchId) {
    return switch (joinMode) {
      JoinMode.openJoin => '/matches/$matchId/join',
      JoinMode.requestToJoin => '/matches/$matchId/join-requests',
    };
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _httpClient.get(
      _uri(path, queryParameters: queryParameters),
      headers: await _headers(),
    );
    _ensureSuccess(response);
    return response;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    return _httpClient
        .post(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .then((response) {
      _ensureSuccess(response);
      return response;
    });
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.replace(
      path: '${_baseUri.path.replaceFirst(RegExp(r'/$'), '')}/$normalizedPath',
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider?.accessToken();
    if (token == null || token.trim().isEmpty) {
      throw const PeladinhasAuthRequiredException();
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw PeladinhasApiException(
      const ApiError(
        code: 'invalid_response',
        message: 'The backend response was not a JSON object.',
      ),
      response.statusCode,
    );
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    ApiError error;
    try {
      final decoded = jsonDecode(response.body);
      error = decoded is Map
          ? ApiError.fromJson(Map<String, dynamic>.from(decoded))
          : const ApiError(
              code: 'http_error',
              message: 'The backend returned an error.',
            );
    } on FormatException {
      error = ApiError(
        code: 'http_${response.statusCode}',
        message: response.body.isEmpty
            ? 'The backend returned an empty error response.'
            : response.body,
      );
    }

    throw PeladinhasApiException(error, response.statusCode);
  }
}

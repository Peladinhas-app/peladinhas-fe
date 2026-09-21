import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/development_config.dart';
import '../models/api_error.dart';
import '../models/match.dart';
import '../models/participant.dart';

class PeladinhasApiException implements Exception {
  const PeladinhasApiException(this.error, this.statusCode);

  final ApiError error;
  final int statusCode;

  @override
  String toString() => error.displayMessage;
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
      'creatorUserId': DevelopmentConfig.organizerUserId,
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
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUri = Uri.parse(baseUrl);

  final http.Client _httpClient;
  final Uri _baseUri;

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
        'actingAdminUserId': DevelopmentConfig.organizerUserId,
        'nextStatus': nextStatus,
      },
    );
    return Match.fromJson(_decodeObject(response));
  }

  Future<Match> getMatch(String matchId) async {
    final response = await _httpClient.get(
      _uri('/matches/$matchId'),
      headers: _headers,
    );
    _ensureSuccess(response);
    return Match.fromJson(_decodeObject(response));
  }

  Future<Participant> joinOpenMatch(String matchId) async {
    final response = await _post(
      joinEndpointFor(JoinMode.openJoin, matchId),
      {'userId': DevelopmentConfig.playerUserId},
    );
    return Participant.fromJson(_decodeObject(response));
  }

  Future<Participant> requestToJoin(String matchId) async {
    final response = await _post(
      joinEndpointFor(JoinMode.requestToJoin, matchId),
      {'userId': DevelopmentConfig.playerUserId},
    );
    return Participant.fromJson(_decodeObject(response));
  }

  String joinEndpointFor(JoinMode joinMode, String matchId) {
    return switch (joinMode) {
      JoinMode.openJoin => '/matches/$matchId/join',
      JoinMode.requestToJoin => '/matches/$matchId/join-requests',
    };
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return _httpClient
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .then((response) {
      _ensureSuccess(response);
      return response;
    });
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.replace(
      path: '${_baseUri.path.replaceFirst(RegExp(r'/$'), '')}/$normalizedPath',
    );
  }

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

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

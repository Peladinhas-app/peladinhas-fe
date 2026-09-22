class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    this.email,
    this.emailConfirmed,
  });

  final String accessToken;
  final String userId;
  final String? email;
  final bool? emailConfirmed;
}

class AuthActionResult {
  const AuthActionResult({this.session, this.message});

  final AuthSession? session;
  final String? message;
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../models/user_profile.dart';
import '../network/peladinhas_api_client.dart';
import 'peladinhas_auth_service.dart';

enum AppSessionStage {
  loading,
  unauthenticated,
  profileMissing,
  ready,
  error,
}

class AppSessionState {
  const AppSessionState({
    required this.stage,
    this.session,
    this.profile,
    this.message,
  });

  const AppSessionState.loading() : this(stage: AppSessionStage.loading);

  const AppSessionState.unauthenticated()
      : this(stage: AppSessionStage.unauthenticated);

  final AppSessionStage stage;
  final AuthSession? session;
  final UserProfile? profile;
  final String? message;
}

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required this.authService,
    required this.apiClient,
  });

  final PeladinhasAuthService authService;
  final PeladinhasApiClient apiClient;
  StreamSubscription<AuthSession?>? _authSubscription;

  AppSessionState _state = const AppSessionState.loading();

  AppSessionState get state => _state;

  Future<void> start() async {
    _authSubscription = authService.authStateChanges.listen((session) {
      _loadProfileForSession(session);
    });
    await _loadProfileForSession(authService.currentSession);
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      final result = await authService.signUp(email: email, password: password);
      if (result.session == null) {
        _setState(AppSessionState(
          stage: AppSessionStage.unauthenticated,
          message: result.message ??
              'Check your email to confirm the Supabase account before logging in.',
        ));
        return;
      }
      await _loadProfileForSession(result.session);
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      final result = await authService.signIn(email: email, password: password);
      await _loadProfileForSession(result.session);
    });
  }

  Future<void> signOut() async {
    _setState(const AppSessionState.loading());
    await authService.signOut();
    _setState(const AppSessionState.unauthenticated());
  }

  Future<void> createProfile({
    required String name,
    required String preferredLanguage,
  }) async {
    final session = _state.session;
    if (session == null) {
      _setState(const AppSessionState.unauthenticated());
      return;
    }

    _setState(AppSessionState(stage: AppSessionStage.loading, session: session));
    try {
      final profile = await apiClient.createProfile(CreateProfileRequest(
        name: name,
        preferredLanguage: preferredLanguage,
      ));
      _setState(AppSessionState(
        stage: AppSessionStage.ready,
        session: session,
        profile: profile,
      ));
    } catch (error) {
      _setState(AppSessionState(
        stage: AppSessionStage.error,
        session: session,
        message: error.toString(),
      ));
    }
  }

  Future<void> refreshProfile() async {
    await _loadProfileForSession(authService.currentSession);
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _setState(const AppSessionState.loading());
    try {
      await action();
    } catch (error) {
      _setState(AppSessionState(
        stage: AppSessionStage.error,
        message: error.toString(),
      ));
    }
  }

  Future<void> _loadProfileForSession(AuthSession? session) async {
    if (session == null) {
      _setState(const AppSessionState.unauthenticated());
      return;
    }

    _setState(AppSessionState(stage: AppSessionStage.loading, session: session));
    try {
      final profile = await apiClient.getProfile();
      _setState(AppSessionState(
        stage: AppSessionStage.ready,
        session: session,
        profile: profile,
      ));
    } on PeladinhasApiException catch (error) {
      if (error.statusCode == 403 &&
          error.error.code == 'authenticated_user_not_found') {
        _setState(AppSessionState(
          stage: AppSessionStage.profileMissing,
          session: session,
          message: error.error.message,
        ));
        return;
      }
      _setState(AppSessionState(
        stage: AppSessionStage.error,
        session: session,
        message: error.error.displayMessage,
      ));
    } catch (error) {
      _setState(AppSessionState(
        stage: AppSessionStage.error,
        session: session,
        message: error.toString(),
      ));
    }
  }

  void _setState(AppSessionState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

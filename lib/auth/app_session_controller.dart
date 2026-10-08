import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/user_profile.dart';
import '../network/peladinhas_api_client.dart';
import 'peladinhas_auth_service.dart';

enum AppSessionStage { loading, unauthenticated, profileMissing, ready, error }

class AppSessionState {
  const AppSessionState({
    required this.stage,
    this.session,
    this.profile,
    this.message,
    this.pendingAccountChoice,
  });

  const AppSessionState.loading() : this(stage: AppSessionStage.loading);

  const AppSessionState.unauthenticated()
    : this(stage: AppSessionStage.unauthenticated);

  final AppSessionStage stage;
  final AuthSession? session;
  final UserProfile? profile;
  final String? message;
  final AccountUseChoice? pendingAccountChoice;
}

class AppSessionController extends ChangeNotifier {
  AppSessionController({required this.authService, required this.apiClient});

  final PeladinhasAuthService authService;
  final PeladinhasApiClient apiClient;
  StreamSubscription<AuthSession?>? _authSubscription;
  AccountUseChoice? _pendingAccountChoice;
  static const _pendingAccountChoiceKey = 'peladinhas.pendingAccountChoice';

  AppSessionState _state = const AppSessionState.loading();

  AppSessionState get state => _state;

  Future<void> start() async {
    _pendingAccountChoice = await _readPendingAccountChoice();
    _authSubscription = authService.authStateChanges.listen((session) {
      _loadProfileForSession(session);
    });
    await _loadProfileForSession(authService.currentSession);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required AccountUseChoice accountChoice,
  }) async {
    await _runAuthAction(() async {
      _pendingAccountChoice = accountChoice;
      await _writePendingAccountChoice(accountChoice);
      final result = await authService.signUp(email: email, password: password);
      if (result.session == null) {
        _setState(
          AppSessionState(
            stage: AppSessionStage.unauthenticated,
            message: result.message ?? 'Check your email to confirm the Supabase account before logging in.',
          ),
        );
        return;
      }
      await _loadProfileForSession(result.session);
    });
  }

  Future<void> signIn({required String email, required String password}) async {
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
    required AccountUseChoice accountType,
    String? ownerInvitationCode,
  }) async {
    final session = _state.session;
    if (session == null) {
      _setState(const AppSessionState.unauthenticated());
      return;
    }

    _setState(
      AppSessionState(stage: AppSessionStage.loading, session: session),
    );
    try {
      final profile = await apiClient.createProfile(
        CreateProfileRequest(
          name: name,
          preferredLanguage: preferredLanguage,
          accountType: accountType,
          ownerInvitationCode: ownerInvitationCode,
        ),
      );
      _pendingAccountChoice = null;
      await _clearPendingAccountChoice();
      _setState(
        AppSessionState(
          stage: AppSessionStage.ready,
          session: session,
          profile: profile,
        ),
      );
    } catch (error) {
      _setState(
        AppSessionState(
          stage: AppSessionStage.error,
          session: session,
          message: 'We couldn’t create your profile. Please try again.',
        ),
      );
    }
  }

  Future<void> refreshProfile() async {
    await _loadProfileForSession(authService.currentSession);
  }

  Future<void> setPendingAccountChoice(AccountUseChoice accountChoice) async {
    _pendingAccountChoice = accountChoice;
    await _writePendingAccountChoice(accountChoice);
    if (_state.stage == AppSessionStage.profileMissing) {
      _setState(
        AppSessionState(
          stage: AppSessionStage.profileMissing,
          session: _state.session,
          message: _state.message,
          pendingAccountChoice: accountChoice,
        ),
      );
    }
  }

  Future<void> activatePitchOwner(String invitationCode) async {
    final session = _state.session;
    if (session == null) {
      _setState(const AppSessionState.unauthenticated());
      return;
    }
    _setState(
      AppSessionState(
        stage: AppSessionStage.loading,
        session: session,
        profile: _state.profile,
      ),
    );
    try {
      final profile = await apiClient.activatePitchOwner(invitationCode);
      _setState(
        AppSessionState(
          stage: AppSessionStage.ready,
          session: session,
          profile: profile,
        ),
      );
    } on PeladinhasApiException catch (error) {
      _setState(
        AppSessionState(
          stage: AppSessionStage.ready,
          session: session,
          profile: _state.profile,
          message: error.error.displayMessage,
        ),
      );
    } catch (error) {
      _setState(
        AppSessionState(
          stage: AppSessionStage.ready,
          session: session,
          profile: _state.profile,
          message: 'We couldn’t activate Pitch Owner mode. Please try again.',
        ),
      );
    }
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _setState(const AppSessionState.loading());
    try {
      await action();
    } catch (error) {
      _setState(
        AppSessionState(
          stage: AppSessionStage.error,
          message: safeAuthenticationErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _loadProfileForSession(AuthSession? session) async {
    if (session == null) {
      _setState(const AppSessionState.unauthenticated());
      return;
    }

    _setState(
      AppSessionState(stage: AppSessionStage.loading, session: session),
    );
    try {
      final profile = await apiClient.getProfile();
      _setState(
        AppSessionState(
          stage: AppSessionStage.ready,
          session: session,
          profile: profile,
        ),
      );
    } on PeladinhasApiException catch (error) {
      if (error.statusCode == 403 &&
          error.error.code == 'authenticated_user_not_found') {
        _setState(
          AppSessionState(
            stage: AppSessionStage.profileMissing,
            session: session,
            message: error.error.message,
            pendingAccountChoice: _pendingAccountChoice,
          ),
        );
        return;
      }
      _setState(
        AppSessionState(
          stage: AppSessionStage.error,
          session: session,
          message: error.error.displayMessage,
        ),
      );
    } catch (error) {
      _setState(
        AppSessionState(
          stage: AppSessionStage.error,
          session: session,
          message: 'We couldn’t load your profile. Please try again.',
        ),
      );
    }
  }

  void _setState(AppSessionState state) {
    _state = state;
    notifyListeners();
  }

  Future<AccountUseChoice?> _readPendingAccountChoice() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_pendingAccountChoiceKey);
    return AccountUseChoice.values
        .where((choice) => choice.apiValue == value)
        .firstOrNull;
  }

  Future<void> _writePendingAccountChoice(
    AccountUseChoice accountChoice,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingAccountChoiceKey,
      accountChoice.apiValue,
    );
  }

  Future<void> _clearPendingAccountChoice() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingAccountChoiceKey);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

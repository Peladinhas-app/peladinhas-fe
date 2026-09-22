import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/app_session_controller.dart';
import 'auth/peladinhas_auth_service.dart';
import 'config/development_config.dart';
import 'network/peladinhas_api_client.dart';
import 'screens/auth_integration_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hasSupabaseConfig = DevelopmentConfig.hasSupabaseConfig;
  if (hasSupabaseConfig) {
    await Supabase.initialize(
      url: DevelopmentConfig.supabaseUrl,
      publishableKey: DevelopmentConfig.supabaseAnonKey,
    );
  }

  runApp(PeladinhasApp(hasSupabaseConfig: hasSupabaseConfig));
}

class PeladinhasApp extends StatelessWidget {
  const PeladinhasApp({
    super.key,
    required this.hasSupabaseConfig,
    this.authService,
    this.apiClient,
  });

  final bool hasSupabaseConfig;
  final PeladinhasAuthService? authService;
  final PeladinhasApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF167A45);

    return MaterialApp(
      title: 'Peladinhas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
        scaffoldBackgroundColor: const Color(0xFFF6F8F4),
        useMaterial3: true,
      ),
      home: hasSupabaseConfig || authService != null
          ? AuthIntegrationBootstrap(
              authService: authService,
              apiClient: apiClient,
            )
          : const MissingConfigurationScreen(),
    );
  }
}

class AuthIntegrationBootstrap extends StatefulWidget {
  const AuthIntegrationBootstrap({
    super.key,
    this.authService,
    this.apiClient,
  });

  final PeladinhasAuthService? authService;
  final PeladinhasApiClient? apiClient;

  @override
  State<AuthIntegrationBootstrap> createState() =>
      _AuthIntegrationBootstrapState();
}

class _AuthIntegrationBootstrapState extends State<AuthIntegrationBootstrap> {
  late final PeladinhasAuthService _authService;
  late final PeladinhasApiClient _apiClient;
  late final AppSessionController _sessionController;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? SupabasePeladinhasAuthService();
    _apiClient = widget.apiClient ??
        PeladinhasApiClient(tokenProvider: _authService);
    _sessionController = AppSessionController(
      authService: _authService,
      apiClient: _apiClient,
    );
    _sessionController.start();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthIntegrationScreen(
      sessionController: _sessionController,
      apiClient: _apiClient,
    );
  }
}

class MissingConfigurationScreen extends StatelessWidget {
  const MissingConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peladinhas authentication configuration is missing',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Run Flutter with SUPABASE_URL, SUPABASE_ANON_KEY, and '
                  'BACKEND_API_BASE_URL using --dart-define. No secret values '
                  'should be committed to Git.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

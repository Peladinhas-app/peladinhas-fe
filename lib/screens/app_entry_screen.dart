import 'package:flutter/material.dart';

import '../auth/app_session_controller.dart';
import '../l10n/app_strings.dart';
import '../network/peladinhas_api_client.dart';
import 'app_shell_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({
    super.key,
    required this.sessionController,
    required this.apiClient,
  });

  final AppSessionController sessionController;
  final PeladinhasApiClient apiClient;

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  @override
  void initState() {
    super.initState();
    widget.sessionController.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.sessionController.state;
    final strings = AppStrings.forProfile(state.profile);

    return switch (state.stage) {
      AppSessionStage.loading => const _LoadingScreen(),
      AppSessionStage.unauthenticated => _AuthScreen(
        controller: widget.sessionController,
        message: state.message,
        strings: strings,
      ),
      AppSessionStage.profileMissing => _ProfileOnboardingScreen(
        controller: widget.sessionController,
        message: state.message,
        strings: strings,
      ),
      AppSessionStage.ready => AppShellScreen(
        sessionController: widget.sessionController,
        apiClient: widget.apiClient,
      ),
      AppSessionStage.error => _AuthScreen(
        controller: widget.sessionController,
        message: state.message,
        strings: strings,
      ),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen({
    required this.controller,
    required this.strings,
    this.message,
  });

  final AppSessionController controller;
  final AppStrings strings;
  final String? message;

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.strings.appName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  if (widget.message != null) ...[
                    _InfoText(widget.message!),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: widget.strings.email,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: widget.strings.password,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => widget.controller.signIn(
                      email: _emailController.text,
                      password: _passwordController.text,
                    ),
                    child: Text(widget.strings.logIn),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => widget.controller.signUp(
                      email: _emailController.text,
                      password: _passwordController.text,
                    ),
                    child: Text(widget.strings.signUp),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileOnboardingScreen extends StatefulWidget {
  const _ProfileOnboardingScreen({
    required this.controller,
    required this.strings,
    this.message,
  });

  final AppSessionController controller;
  final AppStrings strings;
  final String? message;

  @override
  State<_ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<_ProfileOnboardingScreen> {
  final _nameController = TextEditingController();
  String _preferredLanguage = 'en';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.strings.createProfile,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 12),
                    _InfoText(widget.message!),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: widget.strings.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _preferredLanguage,
                    decoration: InputDecoration(
                      labelText: widget.strings.preferredLanguage,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(widget.strings.english),
                      ),
                      DropdownMenuItem(
                        value: 'pt',
                        child: Text(widget.strings.portuguese),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _preferredLanguage = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => widget.controller.createProfile(
                      name: _nameController.text,
                      preferredLanguage: _preferredLanguage,
                    ),
                    child: Text(widget.strings.createProfile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    );
  }
}

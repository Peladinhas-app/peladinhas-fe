import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/app_session_controller.dart';
import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/match.dart';
import '../models/pitch.dart';
import '../network/peladinhas_api_client.dart';
import 'auth_integration_screen.dart';

enum _AppMode {
  player,
  owner;
}

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({
    super.key,
    required this.sessionController,
    required this.apiClient,
  });

  final AppSessionController sessionController;
  final PeladinhasApiClient apiClient;

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  static const _modeStorageKey = 'peladinhas.selectedMode';

  int _selectedIndex = 0;
  _AppMode _mode = _AppMode.player;
  Match? _match;
  Pitch? _pitch;
  PitchAvailability? _availability;
  Booking? _booking;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.sessionController.state.profile!;
    final strings = AppStrings.forProfile(profile);
    final ownerCapable = profile.capabilities.pitchOwner;
    final effectiveMode = ownerCapable ? _mode : _AppMode.player;
    final pages = effectiveMode == _AppMode.owner
        ? _ownerPages(strings)
        : _playerPages(strings, profile.name);

    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appName),
        actions: [
          if (ownerCapable)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SegmentedButton<_AppMode>(
                segments: [
                  ButtonSegment(
                    value: _AppMode.player,
                    icon: const Icon(Icons.sports_soccer_outlined),
                    label: Text(strings.playerMode),
                  ),
                  ButtonSegment(
                    value: _AppMode.owner,
                    icon: const Icon(Icons.stadium_outlined),
                    label: Text(strings.ownerMode),
                  ),
                ],
                selected: {effectiveMode},
                onSelectionChanged: (selection) => _setMode(selection.first),
                showSelectedIcon: false,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: pages[_selectedIndex].child,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: pages
            .map(
              (page) => NavigationDestination(
                icon: Icon(page.icon),
                selectedIcon: Icon(page.selectedIcon),
                label: page.label,
              ),
            )
            .toList(),
      ),
    );
  }

  List<_ShellPage> _playerPages(AppStrings strings, String name) {
    return [
      _ShellPage(
        label: strings.home,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        child: _HomePage(
          strings: strings,
          name: name,
          onCreateMatch: () => setState(() => _selectedIndex = 1),
        ),
      ),
      _ShellPage(
        label: strings.matches,
        icon: Icons.sports_soccer_outlined,
        selectedIcon: Icons.sports_soccer,
        child: _MatchesPage(
          strings: strings,
          apiClient: widget.apiClient,
          initialMatch: _match,
          onMatchChanged: (match) => setState(() => _match = match),
        ),
      ),
      _ShellPage(
        label: strings.groups,
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        child: _GroupsPage(strings: strings),
      ),
      _ShellPage(
        label: strings.pitches,
        icon: Icons.stadium_outlined,
        selectedIcon: Icons.stadium,
        child: _PlayerPitchesPage(
          strings: strings,
          match: _match,
          pitch: _pitch,
          availability: _availability,
          booking: _booking,
        ),
      ),
      _ShellPage(
        label: strings.profile,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        child: _ProfilePage(
          strings: strings,
          controller: widget.sessionController,
          onOpenDebugTool: _debugToolAction(),
        ),
      ),
    ];
  }

  List<_ShellPage> _ownerPages(AppStrings strings) {
    return [
      _ShellPage(
        label: strings.ownerDashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        child: _OwnerDashboardPage(
          strings: strings,
          apiClient: widget.apiClient,
          onCreatePitch: () => setState(() => _selectedIndex = 1),
          onViewBookings: () => setState(() => _selectedIndex = 2),
        ),
      ),
      _ShellPage(
        label: strings.myPitches,
        icon: Icons.stadium_outlined,
        selectedIcon: Icons.stadium,
        child: _OwnerPitchesPage(
          strings: strings,
          apiClient: widget.apiClient,
          onPitchChanged: (pitch) => setState(() => _pitch = pitch),
        ),
      ),
      _ShellPage(
        label: strings.bookings,
        icon: Icons.event_available_outlined,
        selectedIcon: Icons.event_available,
        child: _OwnerBookingsPage(
          strings: strings,
          apiClient: widget.apiClient,
        ),
      ),
      _ShellPage(
        label: strings.ownerSettings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        child: _OwnerSettingsPage(
          strings: strings,
          onPlayerMode: () => _setMode(_AppMode.player),
          onProfile: () => setState(() => _selectedIndex = 4),
        ),
      ),
      _ShellPage(
        label: strings.profile,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        child: _ProfilePage(
          strings: strings,
          controller: widget.sessionController,
          onOpenDebugTool: _debugToolAction(),
        ),
      ),
    ];
  }

  VoidCallback? _debugToolAction() {
    if (!kDebugMode) {
      return null;
    }
    return () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AuthIntegrationScreen(
            sessionController: widget.sessionController,
            apiClient: widget.apiClient,
          ),
        ),
      );
    };
  }

  Future<void> _loadMode() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_modeStorageKey);
    if (!mounted) {
      return;
    }
    final ownerCapable =
        widget.sessionController.state.profile?.capabilities.pitchOwner == true;
    setState(() {
      _mode = ownerCapable && stored == _AppMode.owner.name
          ? _AppMode.owner
          : _AppMode.player;
    });
  }

  Future<void> _setMode(_AppMode mode) async {
    final ownerCapable =
        widget.sessionController.state.profile?.capabilities.pitchOwner == true;
    final nextMode = ownerCapable ? mode : _AppMode.player;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modeStorageKey, nextMode.name);
    if (mounted) {
      setState(() {
        _mode = nextMode;
        _selectedIndex = 0;
      });
    }
  }
}

class _ShellPage {
  const _ShellPage({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget child;
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.strings,
    required this.name,
    required this.onCreateMatch,
  });

  final AppStrings strings;
  final String name;
  final VoidCallback onCreateMatch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: '${strings.welcomeBack}, $name',
          child: Text(strings.upcomingEmpty),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Quick actions',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onCreateMatch,
                icon: const Icon(Icons.add),
                label: const Text('Create match'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchesPage extends StatefulWidget {
  const _MatchesPage({
    required this.strings,
    required this.apiClient,
    required this.initialMatch,
    required this.onMatchChanged,
  });

  final AppStrings strings;
  final PeladinhasApiClient apiClient;
  final Match? initialMatch;
  final ValueChanged<Match> onMatchChanged;

  @override
  State<_MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<_MatchesPage> {
  final _groupNameController = TextEditingController(text: 'Peladinhas Match');
  late DateTime _startsAt;
  int _durationMinutes = 90;
  int _maxPlayers = 10;
  JoinMode _joinMode = JoinMode.openJoin;
  Match? _match;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 2);
    _match = widget.initialMatch;
  }

  @override
  void didUpdateWidget(covariant _MatchesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMatch != oldWidget.initialMatch) {
      _match = widget.initialMatch;
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createMatch() {
    return _run(() async {
      final match = await widget.apiClient.createDirectMatch(
        CreateDirectMatchRequest(
          groupName: _groupNameController.text.trim(),
          startsAt: _startsAt,
          durationMinutes: _durationMinutes,
          maxPlayers: _maxPlayers,
          joinMode: _joinMode,
          publicVacanciesEnabled: true,
        ),
      );
      widget.onMatchChanged(match);
      setState(() {
        _match = match;
        _message = 'Match created with status ${match.status}.';
      });
    });
  }

  Future<void> _openForPlayers() {
    final match = _match;
    if (match == null) {
      return Future.value();
    }
    return _run(() async {
      final updated = await widget.apiClient.transitionMatchStatus(
        matchId: match.id,
        nextStatus: 'recruiting',
      );
      widget.onMatchChanged(updated);
      setState(() {
        _match = updated;
        _message = 'Match opened for players.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: 'Create direct match',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_message != null) ...[
                _StatusText(_message!),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Starts ${_formatDateTime(_startsAt)}')),
                  OutlinedButton(
                    onPressed: _busy ? null : _pickStartDateTime,
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  border: OutlineInputBorder(),
                ),
                items: const [60, 90, 120, 150]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value minutes'),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _durationMinutes = value ?? _durationMinutes,
                        ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _maxPlayers,
                decoration: const InputDecoration(
                  labelText: 'Max players',
                  border: OutlineInputBorder(),
                ),
                items: const [8, 10, 12, 14, 16, 18, 20, 22]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value players'),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _maxPlayers = value ?? _maxPlayers),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<JoinMode>(
                initialValue: _joinMode,
                decoration: const InputDecoration(
                  labelText: 'Join mode',
                  border: OutlineInputBorder(),
                ),
                items: JoinMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(
                          widget.strings.joinModeLabel(mode.apiValue),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _joinMode = value ?? _joinMode),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _createMatch,
                    child: const Text('Create match'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _match == null || !_match!.isDraft
                        ? null
                        : _openForPlayers,
                    child: const Text('Open for players'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_match != null) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Current match',
            child: Text(
              'Status: ${_match!.status}\nJoin mode: ${widget.strings.joinModeLabel(_match!.joinMode.apiValue)}',
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(
      () => _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }
}

class _GroupsPage extends StatelessWidget {
  const _GroupsPage({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(title: strings.groups, child: Text(strings.groupsEmpty)),
      ],
    );
  }
}

class _PlayerPitchesPage extends StatelessWidget {
  const _PlayerPitchesPage({
    required this.strings,
    required this.match,
    required this.pitch,
    required this.availability,
    required this.booking,
  });

  final AppStrings strings;
  final Match? match;
  final Pitch? pitch;
  final PitchAvailability? availability;
  final Booking? booking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: strings.pitches,
          child: Text(
            match == null
                ? 'Create or select a match before requesting a pitch booking.'
                : 'Pitch booking is available to match admins when a pitch is selected.',
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Pitch and booking',
          child: Text(
            [
              if (pitch != null)
                'Pitch: ${pitch!.name}'
              else
                'No pitch selected yet.',
              if (availability != null) 'Available: ${availability!.isAvailable}',
              if (booking != null) 'Booking status: ${booking!.status}',
            ].join('\n'),
          ),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.strings,
    required this.controller,
    required this.onOpenDebugTool,
  });

  final AppStrings strings;
  final AppSessionController controller;
  final VoidCallback? onOpenDebugTool;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  final _invitationController = TextEditingController();
  bool _showActivation = false;

  @override
  void dispose() {
    _invitationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.state.profile!;
    final language = widget.strings.languageName(profile.preferredLanguage);
    final message = widget.controller.state.message;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: widget.strings.profile,
          child: Text(
            'Name: ${profile.name}\nEmail: ${profile.email}\nLanguage: $language',
          ),
        ),
        const SizedBox(height: 16),
        if (!profile.capabilities.pitchOwner)
          _SectionCard(
            title: widget.strings.becomePitchOwner,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.strings.pitchOwnerSignupNote),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  _StatusText(message),
                ],
                const SizedBox(height: 12),
                if (_showActivation)
                  TextField(
                    controller: _invitationController,
                    decoration: InputDecoration(
                      labelText: widget.strings.ownerInvitationCode,
                      helperText: widget.strings.ownerInvitationHelper,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _showActivation
                      ? _activateOwnerMode
                      : () => setState(() => _showActivation = true),
                  icon: const Icon(Icons.stadium_outlined),
                  label: Text(widget.strings.activateOwnerMode),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Account',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: widget.controller.signOut,
                child: Text(widget.strings.logOut),
              ),
              if (widget.onOpenDebugTool != null)
                OutlinedButton.icon(
                  onPressed: widget.onOpenDebugTool,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: Text(widget.strings.debugTool),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _activateOwnerMode() async {
    await widget.controller.activatePitchOwner(_invitationController.text);
    if (!mounted) {
      return;
    }
    final isOwner =
        widget.controller.state.profile?.capabilities.pitchOwner == true;
    if (isOwner) {
      _invitationController.clear();
      setState(() => _showActivation = false);
    }
  }
}

class _OwnerDashboardPage extends StatefulWidget {
  const _OwnerDashboardPage({
    required this.strings,
    required this.apiClient,
    required this.onCreatePitch,
    required this.onViewBookings,
  });

  final AppStrings strings;
  final PeladinhasApiClient apiClient;
  final VoidCallback onCreatePitch;
  final VoidCallback onViewBookings;

  @override
  State<_OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<_OwnerDashboardPage> {
  late Future<_OwnerSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FutureBuilder<_OwnerSummary>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _OwnerLoadError(
                title: widget.strings.ownerDashboard,
                message: widget.strings.ownerDataLoadError,
                retryLabel: widget.strings.retry,
                onRetry: _retry,
              );
            }
            final pitches = snapshot.data?.pitches.length ?? 0;
            final bookings = snapshot.data?.bookings.length ?? 0;
            return _SectionCard(
              title: widget.strings.ownerDashboard,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(label: widget.strings.myPitches, value: '$pitches'),
                  _MetricTile(label: widget.strings.bookings, value: '$bookings'),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Owner actions',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: widget.onCreatePitch,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Add pitch'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onViewBookings,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(widget.strings.bookings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<_OwnerSummary> _loadSummary() async {
    final pitches = await widget.apiClient.getMyPitches();
    final bookings = await widget.apiClient.getOwnerBookings();
    return _OwnerSummary(pitches: pitches, bookings: bookings);
  }

  void _retry() {
    setState(() {
      _summary = _loadSummary();
    });
  }
}

class _OwnerPitchesPage extends StatefulWidget {
  const _OwnerPitchesPage({
    required this.strings,
    required this.apiClient,
    required this.onPitchChanged,
  });

  final AppStrings strings;
  final PeladinhasApiClient apiClient;
  final ValueChanged<Pitch> onPitchChanged;

  @override
  State<_OwnerPitchesPage> createState() => _OwnerPitchesPageState();
}

class _OwnerPitchesPageState extends State<_OwnerPitchesPage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController(text: 'Lisbon');
  final _priceController = TextEditingController(text: '60');
  final _currencyController = TextEditingController(text: 'EUR');
  late Future<List<Pitch>> _pitches;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pitches = widget.apiClient.getMyPitches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: 'Add pitch',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_message != null) ...[
                _StatusText(_message!),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Pitch name',
                  hintText: 'e.g. Campo do Bairro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _currencyController,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _createPitch,
                child: const Text('Add pitch'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Pitch>>(
          future: _pitches,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _OwnerLoadError(
                title: widget.strings.myPitches,
                message: widget.strings.ownerDataLoadError,
                retryLabel: widget.strings.retry,
                onRetry: _retry,
              );
            }
            final pitches = snapshot.data ?? const <Pitch>[];
            if (pitches.isEmpty) {
              return _SectionCard(
                title: widget.strings.myPitches,
                child: Text(widget.strings.noOwnerPitches),
              );
            }
            return _SectionCard(
              title: widget.strings.myPitches,
              child: Column(
                children: pitches
                    .map(
                      (pitch) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(pitch.name),
                        subtitle: Text(
                          [
                            if (pitch.address != null) pitch.address!,
                            if (pitch.basePrice != null)
                              '${pitch.basePrice} ${pitch.currency ?? ''}',
                          ].join(' · '),
                        ),
                        trailing: _StatusChip(
                          label: pitch.active == false ? 'Inactive' : 'Active',
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _createPitch() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final pitch = await widget.apiClient.createPitch(
        CreatePitchRequest(
          name: _nameController.text,
          description: null,
          address: _addressController.text,
          timezone: 'Europe/Lisbon',
          basePrice: num.tryParse(_priceController.text) ?? 0,
          currency: _currencyController.text.trim().toUpperCase(),
          active: true,
        ),
      );
      widget.onPitchChanged(pitch);
      setState(() {
        _message = 'Pitch added.';
        _pitches = widget.apiClient.getMyPitches();
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _retry() {
    setState(() {
      _pitches = widget.apiClient.getMyPitches();
    });
  }
}

class _OwnerBookingsPage extends StatefulWidget {
  const _OwnerBookingsPage({
    required this.strings,
    required this.apiClient,
  });

  final AppStrings strings;
  final PeladinhasApiClient apiClient;

  @override
  State<_OwnerBookingsPage> createState() => _OwnerBookingsPageState();
}

class _OwnerBookingsPageState extends State<_OwnerBookingsPage> {
  late Future<List<Booking>> _bookings;

  @override
  void initState() {
    super.initState();
    _bookings = widget.apiClient.getOwnerBookings();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FutureBuilder<List<Booking>>(
          future: _bookings,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _OwnerLoadError(
                title: widget.strings.bookings,
                message: widget.strings.ownerDataLoadError,
                retryLabel: widget.strings.retry,
                onRetry: _retry,
              );
            }
            final bookings = snapshot.data ?? const <Booking>[];
            if (bookings.isEmpty) {
              return _SectionCard(
                title: widget.strings.bookings,
                child: Text(widget.strings.noOwnerBookings),
              );
            }
            return _SectionCard(
              title: widget.strings.bookings,
              child: Column(
                children: bookings
                    .map(
                      (booking) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Booking ${booking.status}'),
                        subtitle: Text(
                          [
                            if (booking.startsAt != null)
                              _formatDateTime(booking.startsAt!),
                            '${booking.totalPrice} ${booking.currency}',
                          ].join(' · '),
                        ),
                        trailing: _StatusChip(label: booking.status),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  void _retry() {
    setState(() {
      _bookings = widget.apiClient.getOwnerBookings();
    });
  }
}

class _OwnerSettingsPage extends StatelessWidget {
  const _OwnerSettingsPage({
    required this.strings,
    required this.onPlayerMode,
    required this.onProfile,
  });

  final AppStrings strings;
  final VoidCallback onPlayerMode;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: strings.ownerSettings,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onPlayerMode,
                icon: const Icon(Icons.sports_soccer_outlined),
                label: Text(strings.playerMode),
              ),
              OutlinedButton.icon(
                onPressed: onProfile,
                icon: const Icon(Icons.person_outline),
                label: Text(strings.profile),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerSummary {
  const _OwnerSummary({required this.pitches, required this.bookings});

  final List<Pitch> pitches;
  final List<Booking> bookings;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerLoadError extends StatelessWidget {
  const _OwnerLoadError({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

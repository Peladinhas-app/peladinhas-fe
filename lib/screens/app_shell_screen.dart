import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/app_session_controller.dart';
import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/match.dart';
import '../models/pitch.dart';
import '../network/peladinhas_api_client.dart';
import 'auth_integration_screen.dart';

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
  int _selectedIndex = 0;
  Match? _match;
  Pitch? _pitch;
  PitchAvailability? _availability;
  Booking? _booking;

  @override
  Widget build(BuildContext context) {
    final profile = widget.sessionController.state.profile!;
    final strings = AppStrings.forProfile(profile);
    final pages = [
      _HomePage(
        strings: strings,
        name: profile.name,
        onCreateMatch: () => setState(() => _selectedIndex = 1),
        onManagePitch: () => setState(() => _selectedIndex = 3),
      ),
      _MatchesPage(
        strings: strings,
        apiClient: widget.apiClient,
        initialMatch: _match,
        onMatchChanged: (match) => setState(() => _match = match),
      ),
      _GroupsPage(strings: strings),
      _PitchesPage(
        apiClient: widget.apiClient,
        match: _match,
        initialPitch: _pitch,
        initialAvailability: _availability,
        initialBooking: _booking,
        onPitchChanged: (pitch) => setState(() => _pitch = pitch),
        onAvailabilityChanged: (availability) =>
            setState(() => _availability = availability),
        onBookingChanged: (booking) => setState(() => _booking = booking),
      ),
      _ProfilePage(
        strings: strings,
        controller: widget.sessionController,
        onOpenDebugTool: kDebugMode
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AuthIntegrationScreen(
                      sessionController: widget.sessionController,
                      apiClient: widget.apiClient,
                    ),
                  ),
                );
              }
            : null,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(strings.appName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: const Icon(Icons.sports_soccer),
            label: strings.matches,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: strings.groups,
          ),
          NavigationDestination(
            icon: const Icon(Icons.stadium_outlined),
            selectedIcon: const Icon(Icons.stadium),
            label: strings.pitches,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.profile,
          ),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.strings,
    required this.name,
    required this.onCreateMatch,
    required this.onManagePitch,
  });

  final AppStrings strings;
  final String name;
  final VoidCallback onCreateMatch;
  final VoidCallback onManagePitch;

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
              OutlinedButton.icon(
                onPressed: onManagePitch,
                icon: const Icon(Icons.stadium),
                label: const Text('Add pitch'),
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
                Text(
                  _message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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
              'ID: ${_match!.id}\nStatus: ${_match!.status}\nJoin mode: ${widget.strings.joinModeLabel(_match!.joinMode.apiValue)}',
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

class _PitchesPage extends StatefulWidget {
  const _PitchesPage({
    required this.apiClient,
    required this.match,
    required this.initialPitch,
    required this.initialAvailability,
    required this.initialBooking,
    required this.onPitchChanged,
    required this.onAvailabilityChanged,
    required this.onBookingChanged,
  });

  final PeladinhasApiClient apiClient;
  final Match? match;
  final Pitch? initialPitch;
  final PitchAvailability? initialAvailability;
  final Booking? initialBooking;
  final ValueChanged<Pitch> onPitchChanged;
  final ValueChanged<PitchAvailability> onAvailabilityChanged;
  final ValueChanged<Booking> onBookingChanged;

  @override
  State<_PitchesPage> createState() => _PitchesPageState();
}

class _PitchesPageState extends State<_PitchesPage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController(text: 'Lisbon');
  final _priceController = TextEditingController(text: '60');
  final _currencyController = TextEditingController(text: 'EUR');
  Pitch? _pitch;
  PitchAvailability? _availability;
  Booking? _booking;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pitch = widget.initialPitch;
    _availability = widget.initialAvailability;
    _booking = widget.initialBooking;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
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

  Future<void> _createPitch() {
    return _run(() async {
      final pitch = await widget.apiClient.createPitch(
        CreatePitchRequest(
          name: _nameController.text,
          description: 'Technical app-shell pitch.',
          address: _addressController.text,
          timezone: 'Europe/Lisbon',
          basePrice: num.tryParse(_priceController.text) ?? 0,
          currency: _currencyController.text.trim().toUpperCase(),
          active: true,
        ),
      );
      widget.onPitchChanged(pitch);
      setState(() {
        _pitch = pitch;
        _message = 'Pitch created.';
      });
    });
  }

  Future<void> _createSchedule() {
    final pitch = _pitch;
    final match = widget.match;
    if (pitch == null || match == null) return Future.value();
    return _run(() async {
      await widget.apiClient.createPitchSchedule(
        pitchId: pitch.id,
        request: CreatePitchScheduleRequest(
          dayOfWeek: match.startsAt.weekday,
          startsAt: '00:00',
          endsAt: '23:59',
        ),
      );
      setState(() => _message = 'Recurring schedule created.');
    });
  }

  Future<void> _checkAvailability() {
    final pitch = _pitch;
    final match = widget.match;
    if (pitch == null || match == null) return Future.value();
    return _run(() async {
      final availability = await widget.apiClient.getPitchAvailability(
        pitchId: pitch.id,
        startsAt: match.startsAt,
        endsAt: match.endsAt,
      );
      widget.onAvailabilityChanged(availability);
      setState(() {
        _availability = availability;
        _message = 'Availability checked.';
      });
    });
  }

  Future<void> _createBooking() {
    final pitch = _pitch;
    final match = widget.match;
    if (pitch == null || match == null) return Future.value();
    return _run(() async {
      final booking = await widget.apiClient.createBooking(
        CreateBookingRequest(
          matchId: match.id,
          pitchId: pitch.id,
          totalPrice: num.tryParse(_priceController.text) ?? 0,
          currency: _currencyController.text.trim().toUpperCase(),
        ),
      );
      widget.onBookingChanged(booking);
      setState(() {
        _booking = booking;
        _message = 'Booking created with status ${booking.status}.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMatch = widget.match != null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: 'Pitches',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manage pitches for matches you organize.'),
              const SizedBox(height: 12),
              if (_message != null)
                Text(
                  _message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _createPitch,
                    child: const Text('Create pitch'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _pitch == null || !hasMatch
                        ? null
                        : _createSchedule,
                    child: const Text('Create schedule'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _pitch == null || !hasMatch
                        ? null
                        : _checkAvailability,
                    child: const Text('Check availability'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _pitch == null || !hasMatch
                        ? null
                        : _createBooking,
                    child: const Text('Request booking'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Pitch and booking',
          child: Text(
            [
              if (_pitch != null)
                'Pitch: ${_pitch!.name} (${_pitch!.id})'
              else
                'No pitch selected yet.',
              if (widget.match != null)
                'Match for booking: ${widget.match!.id}'
              else
                'Select a match and pitch to check availability or request a booking.',
              if (_availability != null)
                'Available: ${_availability!.isAvailable}',
              if (_booking != null)
                'Booking: ${_booking!.id} / ${_booking!.status}',
            ].join('\n'),
          ),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.strings,
    required this.controller,
    required this.onOpenDebugTool,
  });

  final AppStrings strings;
  final AppSessionController controller;
  final VoidCallback? onOpenDebugTool;

  @override
  Widget build(BuildContext context) {
    final profile = controller.state.profile!;
    final language = strings.languageName(profile.preferredLanguage);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: strings.profile,
          child: Text(
            'Name: ${profile.name}\nEmail: ${profile.email}\nLanguage: $language',
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
                onPressed: controller.signOut,
                child: Text(strings.logOut),
              ),
              if (onOpenDebugTool != null)
                OutlinedButton.icon(
                  onPressed: onOpenDebugTool,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: Text(strings.debugTool),
                ),
            ],
          ),
        ),
      ],
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

import 'package:flutter/material.dart';

import '../auth/app_session_controller.dart';
import '../config/development_config.dart';
import '../models/booking.dart';
import '../models/match.dart';
import '../models/participant.dart';
import '../models/pitch.dart';
import '../network/peladinhas_api_client.dart';

class AuthIntegrationScreen extends StatefulWidget {
  const AuthIntegrationScreen({
    super.key,
    required this.sessionController,
    required this.apiClient,
  });

  final AppSessionController sessionController;
  final PeladinhasApiClient apiClient;

  @override
  State<AuthIntegrationScreen> createState() => _AuthIntegrationScreenState();
}

class _AuthIntegrationScreenState extends State<AuthIntegrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(text: 'Peladinhas User');
  final _groupNameController = TextEditingController(text: 'Authenticated Match');
  final _pitchNameController = TextEditingController(text: 'Authenticated Test Pitch');
  final _pitchAddressController = TextEditingController(text: 'Lisbon');
  final _totalPriceController = TextEditingController(text: '60.00');
  final _currencyController = TextEditingController(text: 'EUR');

  late DateTime _startsAt;
  String _preferredLanguage = 'en';
  int _durationMinutes = 90;
  int _maxPlayers = 10;
  JoinMode _joinMode = JoinMode.openJoin;
  Match? _match;
  Participant? _participant;
  Pitch? _pitch;
  PitchAvailability? _availability;
  Booking? _booking;
  String? _notice;
  String? _error;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    widget.sessionController.addListener(_onSessionChanged);
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 2);
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onSessionChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _groupNameController.dispose();
    _pitchNameController.dispose();
    _pitchAddressController.dispose();
    _totalPriceController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  bool get _isBusy => _busyAction != null;

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _signUp() async {
    await widget.sessionController.signUp(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _signIn() async {
    await widget.sessionController.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _signOut() async {
    await widget.sessionController.signOut();
    setState(() {
      _match = null;
      _participant = null;
      _pitch = null;
      _availability = null;
      _booking = null;
      _notice = 'Signed out.';
      _error = null;
    });
  }

  Future<void> _createProfile() async {
    await widget.sessionController.createProfile(
      name: _nameController.text,
      preferredLanguage: _preferredLanguage,
    );
  }

  Future<void> _createMatch() async {
    await _runAction('Creating authenticated match', () async {
      final created = await widget.apiClient.createDirectMatch(
        CreateDirectMatchRequest(
          groupName: _groupNameController.text.trim(),
          startsAt: _startsAt,
          durationMinutes: _durationMinutes,
          maxPlayers: _maxPlayers,
          joinMode: _joinMode,
          publicVacanciesEnabled: true,
        ),
      );
      setState(() {
        _match = created;
        _participant = null;
        _booking = null;
        _notice = 'Authenticated match created.';
      });
    });
  }

  Future<void> _openForPlayers() async {
    final match = _match;
    if (match == null || !match.isDraft) {
      return;
    }
    await _runAction('Opening match for players', () async {
      final updated = await widget.apiClient.transitionMatchStatus(
        matchId: match.id,
        nextStatus: 'recruiting',
      );
      setState(() {
        _match = updated;
        _notice = 'Match moved to recruiting.';
      });
    });
  }

  Future<void> _reloadMatch() async {
    final match = _match;
    if (match == null) {
      return;
    }
    await _runAction('Reloading match', () async {
      final reloaded = await widget.apiClient.getMatch(match.id);
      setState(() {
        _match = reloaded;
        _notice = 'Match reloaded.';
      });
    });
  }

  Future<void> _joinMatch() async {
    final match = _match;
    if (match == null || !match.isRecruiting) {
      return;
    }
    await _runAction('Joining match as authenticated user', () async {
      final participant = switch (match.joinMode) {
        JoinMode.openJoin => await widget.apiClient.joinOpenMatch(match.id),
        JoinMode.requestToJoin => await widget.apiClient.requestToJoin(match.id),
      };
      setState(() {
        _participant = participant;
        _notice = 'Participant status: ${participant.status}.';
      });
    });
  }

  Future<void> _createPitch() async {
    await _runAction('Creating test pitch', () async {
      final pitch = await widget.apiClient.createPitch(CreatePitchRequest(
        name: _pitchNameController.text,
        description: 'Technical authenticated test pitch.',
        address: _pitchAddressController.text,
        timezone: 'Europe/Lisbon',
        basePrice: num.tryParse(_totalPriceController.text) ?? 0,
        currency: _currencyController.text.trim().toUpperCase(),
        active: true,
      ));
      setState(() {
        _pitch = pitch;
        _notice = 'Test pitch created.';
      });
    });
  }

  Future<void> _createSchedule() async {
    final pitch = _pitch;
    if (pitch == null) {
      return;
    }
    await _runAction('Creating pitch schedule', () async {
      await widget.apiClient.createPitchSchedule(
        pitchId: pitch.id,
        request: CreatePitchScheduleRequest(
          dayOfWeek: _startsAt.weekday,
          startsAt: '00:00',
          endsAt: '23:59',
        ),
      );
      setState(() {
        _notice = 'Schedule created for the match weekday.';
      });
    });
  }

  Future<void> _checkAvailability() async {
    final pitch = _pitch;
    if (pitch == null) {
      return;
    }
    await _runAction('Checking pitch availability', () async {
      final availability = await widget.apiClient.getPitchAvailability(
        pitchId: pitch.id,
        startsAt: _startsAt,
        endsAt: _startsAt.add(Duration(minutes: _durationMinutes)),
      );
      setState(() {
        _availability = availability;
        _notice = 'Availability response received.';
      });
    });
  }

  Future<void> _createBooking() async {
    final match = _match;
    final pitch = _pitch;
    if (match == null || pitch == null) {
      return;
    }
    await _runAction('Creating provisional booking', () async {
      final booking = await widget.apiClient.createBooking(CreateBookingRequest(
        matchId: match.id,
        pitchId: pitch.id,
        totalPrice: num.tryParse(_totalPriceController.text) ?? 0,
        currency: _currencyController.text.trim().toUpperCase(),
      ));
      setState(() {
        _booking = booking;
        _notice = 'Booking status: ${booking.status}.';
      });
    });
  }

  Future<void> _runAction(String label, Future<void> Function() action) async {
    setState(() {
      _busyAction = label;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on PeladinhasApiException catch (exception) {
      setState(() {
        _error = exception.error.displayMessage;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _pickStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.sessionController.state;
    final ready = state.stage == AppSessionStage.ready;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _SectionCard(
                  title: 'Peladinhas real authentication test',
                  child: Text(
                    'Backend: ${DevelopmentConfig.apiBaseUrl}\n'
                    'Supabase: ${DevelopmentConfig.supabaseUrl}',
                  ),
                ),
                const SizedBox(height: 16),
                if (_busyAction != null) _InfoBanner(text: _busyAction!),
                if (_notice != null) _SuccessBanner(text: _notice!),
                if (_error != null) _ErrorBanner(text: _error!),
                if (state.message != null) _InfoBanner(text: state.message!),
                const SizedBox(height: 16),
                _AuthCard(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  state: state,
                  onSignUp: _isBusy ? null : _signUp,
                  onSignIn: _isBusy ? null : _signIn,
                  onSignOut: _isBusy ? null : _signOut,
                ),
                const SizedBox(height: 16),
                if (state.stage == AppSessionStage.profileMissing)
                  _ProfileCard(
                    nameController: _nameController,
                    preferredLanguage: _preferredLanguage,
                    onPreferredLanguageChanged: (value) {
                      if (value != null) {
                        setState(() => _preferredLanguage = value);
                      }
                    },
                    onCreateProfile: _isBusy ? null : _createProfile,
                  ),
                if (ready) ...[
                  _ProfileSummaryCard(name: state.profile!.name),
                  const SizedBox(height: 16),
                  _MatchCard(
                    groupNameController: _groupNameController,
                    startsAt: _startsAt,
                    durationMinutes: _durationMinutes,
                    maxPlayers: _maxPlayers,
                    joinMode: _joinMode,
                    match: _match,
                    participant: _participant,
                    isBusy: _isBusy,
                    onPickStart: _pickStartDateTime,
                    onDurationChanged: (value) {
                      if (value != null) setState(() => _durationMinutes = value);
                    },
                    onMaxPlayersChanged: (value) {
                      if (value != null) setState(() => _maxPlayers = value);
                    },
                    onJoinModeChanged: (value) {
                      if (value != null) setState(() => _joinMode = value);
                    },
                    onCreateMatch: _createMatch,
                    onOpenForPlayers: _openForPlayers,
                    onReloadMatch: _reloadMatch,
                    onJoinMatch: _joinMatch,
                  ),
                  const SizedBox(height: 16),
                  _PitchBookingCard(
                    pitchNameController: _pitchNameController,
                    pitchAddressController: _pitchAddressController,
                    totalPriceController: _totalPriceController,
                    currencyController: _currencyController,
                    pitch: _pitch,
                    availability: _availability,
                    booking: _booking,
                    canCreateBooking: _match != null && _pitch != null,
                    isBusy: _isBusy,
                    onCreatePitch: _createPitch,
                    onCreateSchedule: _createSchedule,
                    onCheckAvailability: _checkAvailability,
                    onCreateBooking: _createBooking,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.emailController,
    required this.passwordController,
    required this.state,
    required this.onSignUp,
    required this.onSignIn,
    required this.onSignOut,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AppSessionState state;
  final VoidCallback? onSignUp;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final signedIn = state.session != null;
    return _SectionCard(
      title: 'Authentication',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('State: ${state.stage.name}'),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: signedIn ? null : onSignUp, child: const Text('Sign Up')),
              FilledButton.tonal(onPressed: signedIn ? null : onSignIn, child: const Text('Log In')),
              OutlinedButton(onPressed: signedIn ? onSignOut : null, child: const Text('Log Out')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nameController,
    required this.preferredLanguage,
    required this.onPreferredLanguageChanged,
    required this.onCreateProfile,
  });

  final TextEditingController nameController;
  final String preferredLanguage;
  final ValueChanged<String?> onPreferredLanguageChanged;
  final VoidCallback? onCreateProfile;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Peladinhas profile onboarding',
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: preferredLanguage,
            decoration: const InputDecoration(
              labelText: 'Preferred language',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
            ],
            onChanged: onPreferredLanguageChanged,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onCreateProfile,
              child: const Text('Create Peladinhas Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Profile ready',
      child: Text('Authenticated Peladinhas profile: $name'),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.groupNameController,
    required this.startsAt,
    required this.durationMinutes,
    required this.maxPlayers,
    required this.joinMode,
    required this.match,
    required this.participant,
    required this.isBusy,
    required this.onPickStart,
    required this.onDurationChanged,
    required this.onMaxPlayersChanged,
    required this.onJoinModeChanged,
    required this.onCreateMatch,
    required this.onOpenForPlayers,
    required this.onReloadMatch,
    required this.onJoinMatch,
  });

  final TextEditingController groupNameController;
  final DateTime startsAt;
  final int durationMinutes;
  final int maxPlayers;
  final JoinMode joinMode;
  final Match? match;
  final Participant? participant;
  final bool isBusy;
  final VoidCallback onPickStart;
  final ValueChanged<int?> onDurationChanged;
  final ValueChanged<int?> onMaxPlayersChanged;
  final ValueChanged<JoinMode?> onJoinModeChanged;
  final VoidCallback onCreateMatch;
  final VoidCallback onOpenForPlayers;
  final VoidCallback onReloadMatch;
  final VoidCallback onJoinMatch;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Authenticated direct match flow',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: groupNameController,
            decoration: const InputDecoration(
              labelText: 'Group name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onPickStart,
            icon: const Icon(Icons.event),
            label: Text('Starts ${_formatDateTime(startsAt)}'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: durationMinutes,
            decoration: const InputDecoration(
              labelText: 'Duration',
              border: OutlineInputBorder(),
            ),
            items: const [60, 90, 120, 150]
                .map((value) => DropdownMenuItem(value: value, child: Text('$value minutes')))
                .toList(),
            onChanged: isBusy ? null : onDurationChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: maxPlayers,
            decoration: const InputDecoration(
              labelText: 'Max players',
              border: OutlineInputBorder(),
            ),
            items: const [8, 10, 12, 14, 16, 18, 20, 22]
                .map((value) => DropdownMenuItem(value: value, child: Text('$value players')))
                .toList(),
            onChanged: isBusy ? null : onMaxPlayersChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<JoinMode>(
            initialValue: joinMode,
            decoration: const InputDecoration(
              labelText: 'Join mode',
              border: OutlineInputBorder(),
            ),
            items: JoinMode.values
                .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.apiValue)))
                .toList(),
            onChanged: isBusy ? null : onJoinModeChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: isBusy ? null : onCreateMatch, child: const Text('Create Match')),
              FilledButton.tonal(
                onPressed: !isBusy && match != null && match!.isDraft ? onOpenForPlayers : null,
                child: const Text('Open for players'),
              ),
              OutlinedButton(
                onPressed: !isBusy && match != null ? onReloadMatch : null,
                child: const Text('Reload Match'),
              ),
              OutlinedButton(
                onPressed: !isBusy && match != null && match!.isRecruiting ? onJoinMatch : null,
                child: Text(joinMode == JoinMode.openJoin ? 'Join Match' : 'Request to Join'),
              ),
            ],
          ),
          if (match != null) ...[
            const SizedBox(height: 16),
            Text('Match ${match!.id}'),
            Text('Status: ${match!.status}'),
            Text('Join mode: ${match!.joinMode.apiValue}'),
          ],
          if (participant != null) ...[
            const SizedBox(height: 16),
            Text('Participant user: ${participant!.userId}'),
            Text('Participant status: ${participant!.status}'),
          ],
        ],
      ),
    );
  }
}

class _PitchBookingCard extends StatelessWidget {
  const _PitchBookingCard({
    required this.pitchNameController,
    required this.pitchAddressController,
    required this.totalPriceController,
    required this.currencyController,
    required this.pitch,
    required this.availability,
    required this.booking,
    required this.canCreateBooking,
    required this.isBusy,
    required this.onCreatePitch,
    required this.onCreateSchedule,
    required this.onCheckAvailability,
    required this.onCreateBooking,
  });

  final TextEditingController pitchNameController;
  final TextEditingController pitchAddressController;
  final TextEditingController totalPriceController;
  final TextEditingController currencyController;
  final Pitch? pitch;
  final PitchAvailability? availability;
  final Booking? booking;
  final bool canCreateBooking;
  final bool isBusy;
  final VoidCallback onCreatePitch;
  final VoidCallback onCreateSchedule;
  final VoidCallback onCheckAvailability;
  final VoidCallback onCreateBooking;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Authenticated pitch and provisional booking flow',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: pitchNameController,
            decoration: const InputDecoration(
              labelText: 'Pitch name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pitchAddressController,
            decoration: const InputDecoration(
              labelText: 'Pitch address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: totalPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Temporary total price',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: currencyController,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Price fields are temporary non-authoritative test inputs.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: isBusy ? null : onCreatePitch, child: const Text('Create Test Pitch')),
              FilledButton.tonal(
                onPressed: !isBusy && pitch != null ? onCreateSchedule : null,
                child: const Text('Create Schedule'),
              ),
              OutlinedButton(
                onPressed: !isBusy && pitch != null ? onCheckAvailability : null,
                child: const Text('Check Availability'),
              ),
              OutlinedButton(
                onPressed: !isBusy && canCreateBooking ? onCreateBooking : null,
                child: const Text('Create Provisional Booking'),
              ),
            ],
          ),
          if (pitch != null) ...[
            const SizedBox(height: 16),
            Text('Pitch ${pitch!.id}: ${pitch!.name}'),
          ],
          if (availability != null) Text('Available: ${availability!.isAvailable}'),
          if (booking != null) ...[
            const SizedBox(height: 16),
            Text('Booking ${booking!.id}'),
            Text('Status: ${booking!.status}'),
          ],
        ],
      ),
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
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Banner(text: text, color: const Color(0xFF2563EB));
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Banner(text: text, color: const Color(0xFF167A45));
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Banner(text: text, color: const Color(0xFFB91C1C));
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        border: Border.all(color: color.withAlpha(95)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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

import 'package:flutter/material.dart';

import '../config/development_config.dart';
import '../models/match.dart';
import '../models/participant.dart';
import '../network/peladinhas_api_client.dart';

class MatchDemoScreen extends StatefulWidget {
  const MatchDemoScreen({super.key, this.apiClient});

  final PeladinhasApiClient? apiClient;

  @override
  State<MatchDemoScreen> createState() => _MatchDemoScreenState();
}

class _MatchDemoScreenState extends State<MatchDemoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController(text: 'Peladinhas Demo');
  final _groupDescriptionController = TextEditingController(
    text: 'Friendly local match created from the Flutter demo.',
  );

  late final PeladinhasApiClient _apiClient;
  late DateTime _startsAt;
  int _durationMinutes = 90;
  int _maxPlayers = 10;
  JoinMode _joinMode = JoinMode.openJoin;
  bool _publicVacanciesEnabled = true;
  Match? _match;
  Participant? _participant;
  String? _notice;
  String? _error;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? PeladinhasApiClient();
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 2);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  bool get _isBusy => _busyAction != null;

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _runAction('Creating match', () async {
      final created = await _apiClient.createDirectMatch(
        CreateDirectMatchRequest(
          groupName: _groupNameController.text.trim(),
          groupDescription: _groupDescriptionController.text.trim(),
          startsAt: _startsAt,
          durationMinutes: _durationMinutes,
          maxPlayers: _maxPlayers,
          joinMode: _joinMode,
          publicVacanciesEnabled: _publicVacanciesEnabled,
        ),
      );

      setState(() {
        _match = created;
        _participant = null;
        _notice = 'Match created by the backend.';
      });
    });
  }

  Future<void> _openForPlayers() async {
    final match = _match;
    if (match == null || !match.isDraft) {
      return;
    }

    await _runAction('Opening match', () async {
      final updated = await _apiClient.transitionMatchStatus(
        matchId: match.id,
        nextStatus: 'recruiting',
      );

      setState(() {
        _match = updated;
        _notice = 'Match opened for players.';
      });
    });
  }

  Future<void> _reloadMatch() async {
    final match = _match;
    if (match == null) {
      return;
    }

    await _runAction('Reloading match', () async {
      final reloaded = await _apiClient.getMatch(match.id);

      setState(() {
        _match = reloaded;
        _notice = 'Match reloaded from the backend.';
      });
    });
  }

  Future<void> _joinAsDemoPlayer() async {
    final match = _match;
    if (match == null || !match.isRecruiting) {
      return;
    }

    await _runAction('Sending player action', () async {
      final participant = switch (match.joinMode) {
        JoinMode.openJoin => await _apiClient.joinOpenMatch(match.id),
        JoinMode.requestToJoin => await _apiClient.requestToJoin(match.id),
      };

      setState(() {
        _participant = participant;
        _notice = 'Backend returned participant status ${participant.status}.';
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
      debugPrint('Peladinhas API error: ${exception.error.displayMessage}');
      setState(() {
        _error = exception.error.displayMessage;
      });
    } catch (error) {
      debugPrint('Peladinhas connection error: $error');
      setState(() {
        _error =
            'Could not reach the local backend. Confirm Spring Boot is running on ${DevelopmentConfig.apiBaseUrl}.';
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
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _HeaderCard(apiBaseUrl: DevelopmentConfig.apiBaseUrl),
                const SizedBox(height: 20),
                if (_busyAction != null) _InfoBanner(text: _busyAction!),
                if (_notice != null) _SuccessBanner(text: _notice!),
                if (_error != null) _ErrorBanner(text: _error!),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 860;
                    final createCard = _CreateMatchCard(
                      formKey: _formKey,
                      groupNameController: _groupNameController,
                      groupDescriptionController: _groupDescriptionController,
                      startsAt: _startsAt,
                      durationMinutes: _durationMinutes,
                      maxPlayers: _maxPlayers,
                      joinMode: _joinMode,
                      publicVacanciesEnabled: _publicVacanciesEnabled,
                      isBusy: _isBusy,
                      onPickStart: _pickStartDateTime,
                      onDurationChanged: (value) {
                        setState(() => _durationMinutes = value);
                      },
                      onMaxPlayersChanged: (value) {
                        setState(() => _maxPlayers = value);
                      },
                      onJoinModeChanged: (value) {
                        setState(() => _joinMode = value);
                      },
                      onPublicVacanciesChanged: (value) {
                        setState(() => _publicVacanciesEnabled = value);
                      },
                      onCreate: _createMatch,
                    );
                    final detailsCard = _MatchDetailsCard(
                      match: _match,
                      participant: _participant,
                      isBusy: _isBusy,
                      onOpenForPlayers: _openForPlayers,
                      onReload: _reloadMatch,
                      onJoin: _joinAsDemoPlayer,
                    );

                    if (!wide) {
                      return Column(
                        children: [
                          createCard,
                          const SizedBox(height: 16),
                          detailsCard,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: createCard),
                        const SizedBox(width: 16),
                        Expanded(child: detailsCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Demo organizer: ${DevelopmentConfig.organizerUserId}\n'
                  'Demo player: ${DevelopmentConfig.playerUserId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peladinhas',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF145C38),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Core match demo connected to $apiBaseUrl',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _CreateMatchCard extends StatelessWidget {
  const _CreateMatchCard({
    required this.formKey,
    required this.groupNameController,
    required this.groupDescriptionController,
    required this.startsAt,
    required this.durationMinutes,
    required this.maxPlayers,
    required this.joinMode,
    required this.publicVacanciesEnabled,
    required this.isBusy,
    required this.onPickStart,
    required this.onDurationChanged,
    required this.onMaxPlayersChanged,
    required this.onJoinModeChanged,
    required this.onPublicVacanciesChanged,
    required this.onCreate,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController groupNameController;
  final TextEditingController groupDescriptionController;
  final DateTime startsAt;
  final int durationMinutes;
  final int maxPlayers;
  final JoinMode joinMode;
  final bool publicVacanciesEnabled;
  final bool isBusy;
  final VoidCallback onPickStart;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onMaxPlayersChanged;
  final ValueChanged<JoinMode> onJoinModeChanged;
  final ValueChanged<bool> onPublicVacanciesChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Create match'),
            const SizedBox(height: 16),
            TextFormField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a group name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: groupDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Group description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
                  .map(
                    (duration) => DropdownMenuItem(
                      value: duration,
                      child: Text('$duration minutes'),
                    ),
                  )
                  .toList(),
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value != null) {
                        onDurationChanged(value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: maxPlayers,
              decoration: const InputDecoration(
                labelText: 'Max players',
                border: OutlineInputBorder(),
              ),
              items: [8, 10, 12, 14, 16, 18, 20, 22]
                  .map(
                    (count) => DropdownMenuItem(
                      value: count,
                      child: Text('$count players'),
                    ),
                  )
                  .toList(),
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value != null) {
                        onMaxPlayersChanged(value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<JoinMode>(
              initialValue: joinMode,
              decoration: const InputDecoration(
                labelText: 'Join mode',
                border: OutlineInputBorder(),
              ),
              items: JoinMode.values
                  .map(
                    (mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(_joinModeLabel(mode)),
                    ),
                  )
                  .toList(),
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value != null) {
                        onJoinModeChanged(value);
                      }
                    },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Public vacancies'),
              value: publicVacanciesEnabled,
              onChanged: isBusy ? null : onPublicVacanciesChanged,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isBusy ? null : onCreate,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create Match'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchDetailsCard extends StatelessWidget {
  const _MatchDetailsCard({
    required this.match,
    required this.participant,
    required this.isBusy,
    required this.onOpenForPlayers,
    required this.onReload,
    required this.onJoin,
  });

  final Match? match;
  final Participant? participant;
  final bool isBusy;
  final VoidCallback onOpenForPlayers;
  final VoidCallback onReload;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final currentMatch = match;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Match details'),
          const SizedBox(height: 16),
          if (currentMatch == null)
            const Text('Create a match to load backend details here.')
          else ...[
            _StatusChip(label: currentMatch.status),
            const SizedBox(height: 12),
            _DetailRow('Group', currentMatch.groupName),
            _DetailRow('Match ID', currentMatch.id),
            _DetailRow('Starts', _formatDateTime(currentMatch.startsAt)),
            _DetailRow('Ends', _formatDateTime(currentMatch.endsAt)),
            _DetailRow('Duration', '${currentMatch.durationMinutes} minutes'),
            _DetailRow('Max players', '${currentMatch.maxPlayers}'),
            _DetailRow('Join mode', _joinModeLabel(currentMatch.joinMode)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed:
                      !isBusy && currentMatch.isDraft ? onOpenForPlayers : null,
                  child: const Text('Open for players'),
                ),
                OutlinedButton(
                  onPressed: !isBusy ? onReload : null,
                  child: const Text('Reload Match'),
                ),
                FilledButton.tonal(
                  onPressed: !isBusy && currentMatch.isRecruiting ? onJoin : null,
                  child: Text(
                    currentMatch.joinMode == JoinMode.openJoin
                        ? 'Join Match'
                        : 'Request to Join',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Player result'),
          const SizedBox(height: 12),
          if (participant == null)
            const Text('The demo player has not acted yet.')
          else ...[
            _StatusChip(label: participant!.status),
            const SizedBox(height: 12),
            _DetailRow('User', participant!.userId),
            if (participant!.joinedAt != null)
              _DetailRow('Joined', _formatDateTime(participant!.joinedAt!)),
            if (participant!.confirmedAt != null)
              _DetailRow('Confirmed', _formatDateTime(participant!.confirmedAt!)),
            if (participant!.cancelledAt != null)
              _DetailRow('Cancelled', _formatDateTime(participant!.cancelledAt!)),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF145C38),
          ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
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
    final color = _statusColor(label);
    return Chip(
      label: Text(label),
      backgroundColor: color.withAlpha(36),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      side: BorderSide(color: color.withAlpha(61)),
    );
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'draft' => const Color(0xFF6B7280),
      'recruiting' => const Color(0xFF167A45),
      'awaiting_payment' => const Color(0xFFB45309),
      'requested' => const Color(0xFF2563EB),
      _ => const Color(0xFF374151),
    };
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      text: text,
      icon: Icons.hourglass_top,
      color: const Color(0xFF2563EB),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      text: text,
      icon: Icons.check_circle,
      color: const Color(0xFF167A45),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      text: text,
      icon: Icons.error_outline,
      color: const Color(0xFFB42318),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(61)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}

String _joinModeLabel(JoinMode mode) {
  return switch (mode) {
    JoinMode.openJoin => 'Open join',
    JoinMode.requestToJoin => 'Request to join',
  };
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

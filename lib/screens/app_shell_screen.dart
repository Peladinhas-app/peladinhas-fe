import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/app_session_controller.dart';
import '../design/peladinhas_components.dart';
import '../design/peladinhas_tokens.dart';
import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/match.dart';
import '../models/match_discovery.dart';
import '../models/pitch.dart';
import '../models/participant.dart';
import '../network/peladinhas_api_client.dart';
import 'auth_integration_screen.dart';

enum _AppMode { player, owner }

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (PeladinhasBreakpoints.isDesktop(width)) {
          return _DesktopShell(
            strings: strings,
            pages: pages,
            profileName: profile.name,
            selectedIndex: _selectedIndex,
            mode: effectiveMode,
            ownerCapable: ownerCapable,
            onHome: () => setState(() => _selectedIndex = 0),
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            onModeSelected: _setMode,
          );
        }
        if (PeladinhasBreakpoints.isTablet(width)) {
          return _TabletShell(
            strings: strings,
            pages: pages,
            selectedIndex: _selectedIndex,
            mode: effectiveMode,
            ownerCapable: ownerCapable,
            onHome: () => setState(() => _selectedIndex = 0),
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            onModeSelected: _setMode,
          );
        }
        return _MobileShell(
          strings: strings,
          pages: pages,
          selectedIndex: _selectedIndex,
          mode: effectiveMode,
          ownerCapable: ownerCapable,
          onHome: () => setState(() => _selectedIndex = 0),
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          onModeSelected: _setMode,
        );
      },
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

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.strings,
    required this.pages,
    required this.profileName,
    required this.selectedIndex,
    required this.mode,
    required this.ownerCapable,
    required this.onHome,
    required this.onDestinationSelected,
    required this.onModeSelected,
  });

  final AppStrings strings;
  final List<_ShellPage> pages;
  final String profileName;
  final int selectedIndex;
  final _AppMode mode;
  final bool ownerCapable;
  final VoidCallback onHome;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<_AppMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeladinhasColors.background,
      body: Row(
        children: [
          _SidebarNavigation(
            key: const Key('desktop-sidebar'),
            strings: strings,
            pages: pages,
            profileName: profileName,
            selectedIndex: selectedIndex,
            mode: mode,
            ownerCapable: ownerCapable,
            compact: false,
            onHome: onHome,
            onDestinationSelected: onDestinationSelected,
            onModeSelected: onModeSelected,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  strings: strings,
                  mode: mode,
                  ownerCapable: ownerCapable,
                ),
                Expanded(child: pages[selectedIndex].child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletShell extends StatelessWidget {
  const _TabletShell({
    required this.strings,
    required this.pages,
    required this.selectedIndex,
    required this.mode,
    required this.ownerCapable,
    required this.onHome,
    required this.onDestinationSelected,
    required this.onModeSelected,
  });

  final AppStrings strings;
  final List<_ShellPage> pages;
  final int selectedIndex;
  final _AppMode mode;
  final bool ownerCapable;
  final VoidCallback onHome;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<_AppMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeladinhasColors.background,
      body: Row(
        children: [
          _SidebarNavigation(
            key: const Key('tablet-sidebar'),
            strings: strings,
            pages: pages,
            profileName: 'Peladinhas',
            selectedIndex: selectedIndex,
            mode: mode,
            ownerCapable: ownerCapable,
            compact: true,
            onHome: onHome,
            onDestinationSelected: onDestinationSelected,
            onModeSelected: onModeSelected,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  strings: strings,
                  mode: mode,
                  ownerCapable: ownerCapable,
                ),
                Expanded(child: pages[selectedIndex].child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.strings,
    required this.pages,
    required this.selectedIndex,
    required this.mode,
    required this.ownerCapable,
    required this.onHome,
    required this.onDestinationSelected,
    required this.onModeSelected,
  });

  final AppStrings strings;
  final List<_ShellPage> pages;
  final int selectedIndex;
  final _AppMode mode;
  final bool ownerCapable;
  final VoidCallback onHome;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<_AppMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeladinhasColors.background,
      appBar: AppBar(
        backgroundColor: PeladinhasColors.surface,
        title: InkWell(onTap: onHome, child: const _BrandMark(showName: true)),
        actions: [
          if (ownerCapable)
            Padding(
              padding: const EdgeInsets.only(right: PeladinhasSpacing.sm),
              child: _WorkspaceChip(mode: mode, onModeSelected: onModeSelected),
            ),
        ],
      ),
      body: SafeArea(child: pages[selectedIndex].child),
      bottomNavigationBar: NavigationBar(
        key: const Key('mobile-navigation'),
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: pages
            .map(
              (page) => NavigationDestination(
                key: Key(_navKey(page.label)),
                icon: Icon(page.icon),
                selectedIcon: Icon(page.selectedIcon),
                label: page.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    super.key,
    required this.strings,
    required this.pages,
    required this.profileName,
    required this.selectedIndex,
    required this.mode,
    required this.ownerCapable,
    required this.compact,
    required this.onHome,
    required this.onDestinationSelected,
    required this.onModeSelected,
  });

  final AppStrings strings;
  final List<_ShellPage> pages;
  final String profileName;
  final int selectedIndex;
  final _AppMode mode;
  final bool ownerCapable;
  final bool compact;
  final VoidCallback onHome;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<_AppMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 88.0 : 248.0;
    return Container(
      width: width,
      color: PeladinhasColors.brandDark,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : PeladinhasSpacing.xxl,
        vertical: 28,
      ),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onHome,
            child: _BrandMark(showName: !compact),
          ),
          const SizedBox(height: 30),
          _SidebarSectionLabel(
            mode == _AppMode.owner ? 'PITCH ADMIN' : 'PLAYER',
          ),
          const SizedBox(height: 7),
          for (var index = 0; index < pages.length; index += 1)
            _SidebarItem(
              key: Key(_navKey(pages[index].label)),
              page: pages[index],
              selected: selectedIndex == index,
              compact: compact,
              nested: index > 0,
              onTap: () => onDestinationSelected(index),
            ),
          if (ownerCapable) ...[
            const SizedBox(height: 24),
            const _SidebarSectionLabel('SWITCH WORKSPACE'),
            const SizedBox(height: 7),
            _WorkspaceSwitch(
              mode: mode,
              compact: compact,
              onModeSelected: onModeSelected,
            ),
          ],
          const Spacer(),
          if (!compact) ...[
            const Divider(color: Color(0x66F7F8F5)),
            const SizedBox(height: 10),
            _SidebarProfile(name: profileName, mode: mode),
          ],
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.showName});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: PeladinhasColors.highlight,
            borderRadius: BorderRadius.circular(PeladinhasRadii.xs),
          ),
          child: const SizedBox.square(
            dimension: 36,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PeladinhasColors.brandDark,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(width: PeladinhasSpacing.md),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'PELADINHAS',
                style: PeladinhasTypography.sectionTitle.copyWith(
                  color: PeladinhasColors.onDark,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: PeladinhasTypography.eyebrow.copyWith(
        color: PeladinhasColors.highlight,
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.page,
    required this.selected,
    required this.compact,
    required this.nested,
    required this.onTap,
  });

  final _ShellPage page;
  final bool selected;
  final bool compact;
  final bool nested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PeladinhasColors.brand : Colors.transparent;
    final leftPadding = compact ? 0.0 : (nested ? 30.0 : 14.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(PeladinhasRadii.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PeladinhasRadii.xs),
          child: SizedBox(
            height: 40,
            width: compact ? 52 : 184,
            child: Padding(
              padding: EdgeInsets.only(left: leftPadding, right: 12),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  SquareNavIcon(
                    color: selected
                        ? PeladinhasColors.onDark
                        : PeladinhasColors.mutedIcon,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        page.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PeladinhasTypography.label.copyWith(
                          color: PeladinhasColors.onDark.withValues(
                            alpha: selected ? 1 : 0.72,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _navKey(String label) {
  return 'nav-${label.toLowerCase().replaceAll(' ', '-')}';
}

class _WorkspaceSwitch extends StatelessWidget {
  const _WorkspaceSwitch({
    required this.mode,
    required this.compact,
    required this.onModeSelected,
  });

  final _AppMode mode;
  final bool compact;
  final ValueChanged<_AppMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final target = mode == _AppMode.owner ? _AppMode.player : _AppMode.owner;
    final label = target == _AppMode.owner ? 'Pitch admin' : 'Player';
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PeladinhasRadii.xs),
        side: mode == _AppMode.owner
            ? const BorderSide(color: Color(0xFF6D8D7E))
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => onModeSelected(target),
        borderRadius: BorderRadius.circular(PeladinhasRadii.xs),
        child: SizedBox(
          height: compact ? 44 : 40,
          width: compact ? 52 : 184,
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              SizedBox(width: compact ? 0 : 14),
              const SquareNavIcon(color: PeladinhasColors.highlight),
              if (!compact) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: PeladinhasTypography.label.copyWith(
                      color: PeladinhasColors.onDark.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.mode, required this.onModeSelected});

  final _AppMode mode;
  final ValueChanged<_AppMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AppMode>(
      onSelected: onModeSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: _AppMode.player, child: Text('Player mode')),
        PopupMenuItem(value: _AppMode.owner, child: Text('Pitch admin')),
      ],
      child: PeladinhasInputShell(
        active: true,
        child: Text(
          mode == _AppMode.owner ? 'OWNER' : 'PLAYER',
          style: PeladinhasTypography.eyebrow.copyWith(
            color: PeladinhasColors.brand,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.strings,
    required this.mode,
    required this.ownerCapable,
  });

  final AppStrings strings;
  final _AppMode mode;
  final bool ownerCapable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: PeladinhasColors.surface,
            border: Border(bottom: BorderSide(color: PeladinhasColors.border)),
          ),
          child: SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PeladinhasSpacing.page,
              ),
              child: Row(
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: PeladinhasInputShell(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 16,
                              color: PeladinhasColors.brand,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Search matches, groups or pitches',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PeladinhasTypography.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!compact) ...[
                    Text(
                      'Lisbon',
                      style: PeladinhasTypography.label.copyWith(
                        color: PeladinhasColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Text(
                      '●',
                      style: PeladinhasTypography.eyebrow.copyWith(
                        color: PeladinhasColors.brand,
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                  Text(
                    mode == _AppMode.owner ? 'OWNER' : 'PLAYER',
                    style: PeladinhasTypography.eyebrow.copyWith(
                      color: PeladinhasColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarProfile extends StatelessWidget {
  const _SidebarProfile({required this.name, required this.mode});

  final String name;
  final _AppMode mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: PeladinhasColors.highlight,
          child: Text(
            name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase(),
            style: PeladinhasTypography.label.copyWith(
              color: PeladinhasColors.brandDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PeladinhasTypography.label.copyWith(
                  color: PeladinhasColors.onDark,
                ),
              ),
              Text(
                mode == _AppMode.owner ? 'Owner mode' : 'Player mode',
                style: PeladinhasTypography.eyebrow.copyWith(
                  color: PeladinhasColors.onDark.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
  static const _discoveryPageSize = 10;

  final _areaController = TextEditingController();
  final _groupNameController = TextEditingController(text: 'Peladinhas Match');
  late DateTime _startsAt;
  int _durationMinutes = 90;
  int _maxPlayers = 10;
  int _selectedTab = 0;
  JoinMode _joinMode = JoinMode.openJoin;
  JoinMode? _discoveryJoinMode;
  DateTime? _filterStartsFrom;
  DateTime? _filterStartsTo;
  TimeOfDay? _filterTimeFrom;
  TimeOfDay? _filterTimeTo;
  bool _availableOnly = false;
  bool _discoveryLoading = true;
  bool _discoveryLoadingMore = false;
  String? _discoveryError;
  String? _discoveryPageError;
  String? _discoveryValidationError;
  String? _discoveryActionMessage;
  int _discoveryPage = 0;
  int _discoveryTotalPages = 0;
  int _discoveryTotalElements = 0;
  int _discoveryGeneration = 0;
  final List<MatchDiscoveryItem> _discoveredMatches = [];
  final Set<String> _submittedDiscoveryMatches = {};
  Match? _match;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 2);
    _match = widget.initialMatch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDiscovery(reset: true);
      }
    });
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
    _areaController.dispose();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = PeladinhasBreakpoints.isMobile(constraints.maxWidth);
        final horizontalPadding = isMobile ? 20.0 : PeladinhasSpacing.page;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isMobile ? 24 : 38,
            horizontalPadding,
            48,
          ),
          children: [
            _MatchesHeader(
              isMobile: isMobile,
              onCreate: () => setState(() => _selectedTab = 1),
            ),
            const SizedBox(height: PeladinhasSpacing.xl),
            PeladinhasTabs(
              tabs: const [
                'Find a match',
                'Create a match',
                'My upcoming matches',
              ],
              selectedIndex: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
            const SizedBox(height: PeladinhasSpacing.xl),
            if (_selectedTab == 0)
              _FindMatchTab(
                isMobile: isMobile,
                areaController: _areaController,
                startsFrom: _filterStartsFrom,
                startsTo: _filterStartsTo,
                timeFrom: _filterTimeFrom,
                timeTo: _filterTimeTo,
                joinMode: _discoveryJoinMode,
                availableOnly: _availableOnly,
                loading: _discoveryLoading,
                loadingMore: _discoveryLoadingMore,
                error: _discoveryError,
                pageError: _discoveryPageError,
                validationError: _discoveryValidationError,
                actionMessage: _discoveryActionMessage,
                matches: _discoveredMatches,
                totalElements: _discoveryTotalElements,
                hasMore: _discoveryPage + 1 < _discoveryTotalPages,
                submittedMatchIds: _submittedDiscoveryMatches,
                strings: widget.strings,
                onStartsFrom: () => _pickFilterDate(isStart: true),
                onStartsTo: () => _pickFilterDate(isStart: false),
                onTimeFrom: () => _pickFilterTime(isStart: true),
                onTimeTo: () => _pickFilterTime(isStart: false),
                onJoinModeChanged: (value) =>
                    setState(() => _discoveryJoinMode = value),
                onAvailableOnlyChanged: (value) =>
                    setState(() => _availableOnly = value),
                onApplyFilters: _applyDiscoveryFilters,
                onResetFilters: _resetDiscoveryFilters,
                onRetry: () => _loadDiscovery(reset: true),
                onLoadMore: _discoveryLoadingMore ? null : _loadMoreDiscovery,
                onJoin: _joinDiscoveredMatch,
              )
            else if (_selectedTab == 1)
              _CreateMatchTab(
                busy: _busy,
                message: _message,
                groupNameController: _groupNameController,
                startsAt: _startsAt,
                durationMinutes: _durationMinutes,
                maxPlayers: _maxPlayers,
                joinMode: _joinMode,
                currentMatch: _match,
                strings: widget.strings,
                onPickStartDateTime: _pickStartDateTime,
                onDurationChanged: (value) => setState(
                  () => _durationMinutes = value ?? _durationMinutes,
                ),
                onMaxPlayersChanged: (value) =>
                    setState(() => _maxPlayers = value ?? _maxPlayers),
                onJoinModeChanged: (value) =>
                    setState(() => _joinMode = value ?? _joinMode),
                onCreateMatch: _busy ? null : _createMatch,
                onOpenForPlayers: _busy || _match == null || !_match!.isDraft
                    ? null
                    : _openForPlayers,
              )
            else
              _UpcomingMatchesTab(match: _match, strings: widget.strings),
          ],
        );
      },
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

  MatchDiscoveryFilters _discoveryFilters() {
    return MatchDiscoveryFilters(
      area: _areaController.text,
      startsFrom: _filterStartsFrom,
      startsTo: _filterStartsTo,
      timeFrom: _formatQueryTime(_filterTimeFrom),
      timeTo: _formatQueryTime(_filterTimeTo),
      joinMode: _discoveryJoinMode,
      availableOnly: _availableOnly,
    );
  }

  String? _validateDiscoveryFilters() {
    if (_filterStartsFrom != null &&
        _filterStartsTo != null &&
        _filterStartsFrom!.isAfter(_filterStartsTo!)) {
      return 'Choose an end date after the start date.';
    }
    if (_filterTimeFrom != null &&
        _filterTimeTo != null &&
        _minutesOfDay(_filterTimeFrom!) > _minutesOfDay(_filterTimeTo!)) {
      return 'Choose an end time after the start time.';
    }
    return null;
  }

  Future<void> _loadDiscovery({required bool reset}) async {
    final validation = _validateDiscoveryFilters();
    if (validation != null) {
      setState(() => _discoveryValidationError = validation);
      return;
    }
    if (!reset && (_discoveryLoading || _discoveryLoadingMore)) {
      return;
    }

    final generation = reset ? _discoveryGeneration + 1 : _discoveryGeneration;
    final nextPage = reset ? 0 : _discoveryPage + 1;
    setState(() {
      if (reset) {
        _discoveryGeneration = generation;
      }
      _discoveryValidationError = null;
      if (reset) {
        _discoveryError = null;
      }
      _discoveryPageError = null;
      if (reset) {
        _discoveryLoading = true;
        _discoveryLoadingMore = false;
        _discoveryActionMessage = null;
      } else {
        _discoveryLoadingMore = true;
      }
    });

    try {
      final page = await widget.apiClient.discoverMatches(
        filters: _discoveryFilters(),
        page: nextPage,
        size: _discoveryPageSize,
      );
      if (!mounted || generation != _discoveryGeneration) {
        return;
      }
      setState(() {
        if (reset) {
          _discoveredMatches
            ..clear()
            ..addAll(page.matches);
        } else {
          _discoveredMatches.addAll(page.matches);
        }
        _discoveryPage = page.page;
        _discoveryTotalPages = page.totalPages;
        _discoveryTotalElements = page.totalElements;
        _discoveryPageError = null;
      });
    } catch (error) {
      if (!mounted || generation != _discoveryGeneration) {
        return;
      }
      setState(() {
        final message = "We couldn't load matches. Please try again.";
        if (reset) {
          _discoveryError = message;
        } else {
          _discoveryPageError = message;
        }
      });
    } finally {
      if (mounted && generation == _discoveryGeneration) {
        setState(() {
          if (reset) {
            _discoveryLoading = false;
          } else {
            _discoveryLoadingMore = false;
          }
        });
      }
    }
  }

  Future<void> _applyDiscoveryFilters() async {
    await _loadDiscovery(reset: true);
  }

  Future<void> _loadMoreDiscovery() async {
    await _loadDiscovery(reset: false);
  }

  Future<void> _resetDiscoveryFilters() async {
    _areaController.clear();
    setState(() {
      _filterStartsFrom = null;
      _filterStartsTo = null;
      _filterTimeFrom = null;
      _filterTimeTo = null;
      _discoveryJoinMode = null;
      _availableOnly = false;
      _discoveryValidationError = null;
      _discoveryPageError = null;
      _discoveryActionMessage = null;
    });
    await _loadDiscovery(reset: true);
  }

  Future<void> _joinDiscoveredMatch(MatchDiscoveryItem match) async {
    if (_submittedDiscoveryMatches.contains(match.matchId)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm participation'),
        content: Text(
          match.joinMode == JoinMode.openJoin
              ? 'Join ${match.displayName}?'
              : 'Request to join ${match.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              match.joinMode == JoinMode.openJoin ? 'Join' : 'Request',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _discoveryActionMessage = null;
      _submittedDiscoveryMatches.add(match.matchId);
    });
    try {
      final Participant participant = match.joinMode == JoinMode.openJoin
          ? await widget.apiClient.joinOpenMatch(match.matchId)
          : await widget.apiClient.requestToJoin(match.matchId);
      if (!mounted) {
        return;
      }
      setState(() {
        final status = _participantStatusLabel(participant.status);
        _discoveryActionMessage = match.joinMode == JoinMode.openJoin
            ? 'Joined. Participant status: $status.'
            : 'Request sent. Participant status: $status.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submittedDiscoveryMatches.remove(match.matchId);
        _discoveryActionMessage =
            "We couldn't update your participation. Please try again.";
      });
    }
  }

  Future<void> _pickFilterDate({required bool isStart}) async {
    final current = isStart ? _filterStartsFrom : _filterStartsTo;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null) {
      return;
    }
    setState(() {
      final normalized = DateTime(date.year, date.month, date.day);
      if (isStart) {
        _filterStartsFrom = normalized;
      } else {
        _filterStartsTo = DateTime(date.year, date.month, date.day, 23, 59);
      }
    });
  }

  Future<void> _pickFilterTime({required bool isStart}) async {
    final current = isStart ? _filterTimeFrom : _filterTimeTo;
    final time = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _filterTimeFrom = time;
      } else {
        _filterTimeTo = time;
      }
    });
  }
}

class _MatchesHeader extends StatelessWidget {
  const _MatchesHeader({required this.isMobile, required this.onCreate});

  final bool isMobile;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Matches', style: PeladinhasTypography.display),
        const SizedBox(height: 7),
        Text(
          'Find the right game or organise one for your community.',
          style: PeladinhasTypography.body,
        ),
      ],
    );
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: PeladinhasSpacing.lg),
          PeladinhasButton(label: 'Create a match', onPressed: onCreate),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        PeladinhasButton(label: 'Create a match', onPressed: onCreate),
      ],
    );
  }
}

class _FindMatchTab extends StatelessWidget {
  const _FindMatchTab({
    required this.isMobile,
    required this.areaController,
    required this.startsFrom,
    required this.startsTo,
    required this.timeFrom,
    required this.timeTo,
    required this.joinMode,
    required this.availableOnly,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.pageError,
    required this.validationError,
    required this.actionMessage,
    required this.matches,
    required this.totalElements,
    required this.hasMore,
    required this.submittedMatchIds,
    required this.strings,
    required this.onStartsFrom,
    required this.onStartsTo,
    required this.onTimeFrom,
    required this.onTimeTo,
    required this.onJoinModeChanged,
    required this.onAvailableOnlyChanged,
    required this.onApplyFilters,
    required this.onResetFilters,
    required this.onRetry,
    required this.onLoadMore,
    required this.onJoin,
  });

  final bool isMobile;
  final TextEditingController areaController;
  final DateTime? startsFrom;
  final DateTime? startsTo;
  final TimeOfDay? timeFrom;
  final TimeOfDay? timeTo;
  final JoinMode? joinMode;
  final bool availableOnly;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final String? pageError;
  final String? validationError;
  final String? actionMessage;
  final List<MatchDiscoveryItem> matches;
  final int totalElements;
  final bool hasMore;
  final Set<String> submittedMatchIds;
  final AppStrings strings;
  final VoidCallback onStartsFrom;
  final VoidCallback onStartsTo;
  final VoidCallback onTimeFrom;
  final VoidCallback onTimeTo;
  final ValueChanged<JoinMode?> onJoinModeChanged;
  final ValueChanged<bool> onAvailableOnlyChanged;
  final VoidCallback onApplyFilters;
  final VoidCallback onResetFilters;
  final VoidCallback onRetry;
  final VoidCallback? onLoadMore;
  final ValueChanged<MatchDiscoveryItem> onJoin;

  @override
  Widget build(BuildContext context) {
    final resultSummary = totalElements == 1
        ? '1 match available'
        : '$totalElements matches available';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MatchFilters(
          areaController: areaController,
          startsFrom: startsFrom,
          startsTo: startsTo,
          timeFrom: timeFrom,
          timeTo: timeTo,
          joinMode: joinMode,
          availableOnly: availableOnly,
          strings: strings,
          onStartsFrom: onStartsFrom,
          onStartsTo: onStartsTo,
          onTimeFrom: onTimeFrom,
          onTimeTo: onTimeTo,
          onJoinModeChanged: onJoinModeChanged,
          onAvailableOnlyChanged: onAvailableOnlyChanged,
          onApplyFilters: onApplyFilters,
          onResetFilters: onResetFilters,
        ),
        const SizedBox(height: PeladinhasSpacing.xl),
        if (validationError != null)
          _DiscoveryNotice(message: validationError!, isError: true)
        else if (actionMessage != null)
          _DiscoveryNotice(message: actionMessage!, isError: false),
        if (validationError != null || actionMessage != null)
          const SizedBox(height: PeladinhasSpacing.lg),
        PeladinhasStatusLabel(label: resultSummary),
        const SizedBox(height: PeladinhasSpacing.lg),
        if (loading)
          const _DiscoveryLoadingCard()
        else if (error != null)
          _DiscoveryErrorCard(message: error!, onRetry: onRetry)
        else if (matches.isEmpty)
          const _MatchesStateCard(
            title: 'No open matches found',
            message: 'Try changing your filters or checking again later.',
          )
        else
          Column(
            children: [
              for (final match in matches) ...[
                _DiscoveryMatchCard(
                  match: match,
                  strings: strings,
                  isSubmitted: submittedMatchIds.contains(match.matchId),
                  onJoin: () => onJoin(match),
                ),
                const SizedBox(height: PeladinhasSpacing.lg),
              ],
              if (hasMore)
                PeladinhasButton(
                  label: loadingMore ? 'Loading...' : 'Load more matches',
                  tone: PeladinhasButtonTone.secondary,
                  onPressed: onLoadMore,
                ),
              if (pageError != null) ...[
                const SizedBox(height: PeladinhasSpacing.lg),
                _DiscoveryInlineError(message: pageError!, onRetry: onLoadMore),
              ],
            ],
          ),
      ],
    );
  }
}

class _CreateMatchTab extends StatelessWidget {
  const _CreateMatchTab({
    required this.busy,
    required this.message,
    required this.groupNameController,
    required this.startsAt,
    required this.durationMinutes,
    required this.maxPlayers,
    required this.joinMode,
    required this.currentMatch,
    required this.strings,
    required this.onPickStartDateTime,
    required this.onDurationChanged,
    required this.onMaxPlayersChanged,
    required this.onJoinModeChanged,
    required this.onCreateMatch,
    required this.onOpenForPlayers,
  });

  final bool busy;
  final String? message;
  final TextEditingController groupNameController;
  final DateTime startsAt;
  final int durationMinutes;
  final int maxPlayers;
  final JoinMode joinMode;
  final Match? currentMatch;
  final AppStrings strings;
  final VoidCallback onPickStartDateTime;
  final ValueChanged<int?> onDurationChanged;
  final ValueChanged<int?> onMaxPlayersChanged;
  final ValueChanged<JoinMode?> onJoinModeChanged;
  final VoidCallback? onCreateMatch;
  final VoidCallback? onOpenForPlayers;

  @override
  Widget build(BuildContext context) {
    return PeladinhasCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create a match', style: PeladinhasTypography.title),
          const SizedBox(height: PeladinhasSpacing.sm),
          Text(
            'Organise a real match through the authenticated backend.',
            style: PeladinhasTypography.body,
          ),
          if (message != null) ...[
            const SizedBox(height: PeladinhasSpacing.lg),
            _StatusText(message!),
          ],
          const SizedBox(height: PeladinhasSpacing.xl),
          TextField(
            controller: groupNameController,
            decoration: const InputDecoration(
              labelText: 'Group name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PeladinhasSpacing.lg),
          Wrap(
            spacing: PeladinhasSpacing.lg,
            runSpacing: PeladinhasSpacing.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: PeladinhasInputShell(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Starts ${_formatDateTime(startsAt)}'),
                      ),
                      TextButton(
                        onPressed: busy ? null : onPickStartDateTime,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  items: const [60, 90, 120, 150]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : onDurationChanged,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int>(
                  initialValue: maxPlayers,
                  decoration: const InputDecoration(labelText: 'Max players'),
                  items: const [8, 10, 12, 14, 16, 18, 20, 22]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value players'),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : onMaxPlayersChanged,
                ),
              ),
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<JoinMode>(
                  initialValue: joinMode,
                  decoration: const InputDecoration(labelText: 'Join mode'),
                  items: JoinMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(strings.joinModeLabel(mode.apiValue)),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : onJoinModeChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: PeladinhasSpacing.xl),
          Wrap(
            spacing: PeladinhasSpacing.sm,
            runSpacing: PeladinhasSpacing.sm,
            children: [
              PeladinhasButton(label: 'Create match', onPressed: onCreateMatch),
              PeladinhasButton(
                label: 'Open for players',
                tone: PeladinhasButtonTone.secondary,
                onPressed: onOpenForPlayers,
              ),
            ],
          ),
          if (currentMatch != null) ...[
            const SizedBox(height: PeladinhasSpacing.xl),
            _MatchesStateCard(
              title: 'Current match',
              message:
                  'Status: ${currentMatch!.status}\nJoin mode: ${strings.joinModeLabel(currentMatch!.joinMode.apiValue)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingMatchesTab extends StatelessWidget {
  const _UpcomingMatchesTab({required this.match, required this.strings});

  final Match? match;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (match == null) {
      return const _MatchesStateCard(
        title: 'You have no upcoming matches.',
        message: 'Created or joined matches will appear here.',
      );
    }
    return _MatchesStateCard(
      title: match!.groupName,
      message:
          'Status: ${match!.status}\nStarts: ${_formatDateTime(match!.startsAt)}\nJoin mode: ${strings.joinModeLabel(match!.joinMode.apiValue)}',
    );
  }
}

class _MatchFilters extends StatelessWidget {
  const _MatchFilters({
    required this.areaController,
    required this.startsFrom,
    required this.startsTo,
    required this.timeFrom,
    required this.timeTo,
    required this.joinMode,
    required this.availableOnly,
    required this.strings,
    required this.onStartsFrom,
    required this.onStartsTo,
    required this.onTimeFrom,
    required this.onTimeTo,
    required this.onJoinModeChanged,
    required this.onAvailableOnlyChanged,
    required this.onApplyFilters,
    required this.onResetFilters,
  });

  final TextEditingController areaController;
  final DateTime? startsFrom;
  final DateTime? startsTo;
  final TimeOfDay? timeFrom;
  final TimeOfDay? timeTo;
  final JoinMode? joinMode;
  final bool availableOnly;
  final AppStrings strings;
  final VoidCallback onStartsFrom;
  final VoidCallback onStartsTo;
  final VoidCallback onTimeFrom;
  final VoidCallback onTimeTo;
  final ValueChanged<JoinMode?> onJoinModeChanged;
  final ValueChanged<bool> onAvailableOnlyChanged;
  final VoidCallback onApplyFilters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return PeladinhasCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find a match', style: PeladinhasTypography.title),
          const SizedBox(height: PeladinhasSpacing.lg),
          Wrap(
            spacing: PeladinhasSpacing.lg,
            runSpacing: PeladinhasSpacing.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area',
                    hintText: 'City or neighbourhood',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              _FilterAction(
                label: 'From date',
                value: _formatShortDate(startsFrom),
                onPressed: onStartsFrom,
              ),
              _FilterAction(
                label: 'To date',
                value: _formatShortDate(startsTo),
                onPressed: onStartsTo,
              ),
              _FilterAction(
                label: 'From time',
                value: _formatTimeOfDay(timeFrom),
                onPressed: onTimeFrom,
              ),
              _FilterAction(
                label: 'To time',
                value: _formatTimeOfDay(timeTo),
                onPressed: onTimeTo,
              ),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<JoinMode?>(
                  isExpanded: true,
                  initialValue: joinMode,
                  decoration: const InputDecoration(labelText: 'Join mode'),
                  items: [
                    const DropdownMenuItem<JoinMode?>(
                      value: null,
                      child: Text('Any join mode'),
                    ),
                    ...JoinMode.values.map(
                      (mode) => DropdownMenuItem<JoinMode?>(
                        value: mode,
                        child: Text(strings.joinModeLabel(mode.apiValue)),
                      ),
                    ),
                  ],
                  onChanged: onJoinModeChanged,
                ),
              ),
              SizedBox(
                width: 210,
                child: Row(
                  children: [
                    Checkbox(
                      value: availableOnly,
                      onChanged: (value) =>
                          onAvailableOnlyChanged(value ?? false),
                    ),
                    const Expanded(child: Text('Available places only')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PeladinhasSpacing.lg),
          Wrap(
            spacing: PeladinhasSpacing.sm,
            runSpacing: PeladinhasSpacing.sm,
            children: [
              PeladinhasButton(
                label: 'Apply filters',
                onPressed: onApplyFilters,
              ),
              PeladinhasButton(
                label: 'Reset',
                tone: PeladinhasButtonTone.secondary,
                onPressed: onResetFilters,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterAction extends StatelessWidget {
  const _FilterAction({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: PeladinhasTypography.eyebrow),
            Text(value, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryLoadingCard extends StatelessWidget {
  const _DiscoveryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PeladinhasCard(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DiscoveryErrorCard extends StatelessWidget {
  const _DiscoveryErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PeladinhasCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matches could not be loaded',
            style: PeladinhasTypography.sectionTitle,
          ),
          const SizedBox(height: PeladinhasSpacing.sm),
          Text(message, style: PeladinhasTypography.body),
          const SizedBox(height: PeladinhasSpacing.lg),
          PeladinhasButton(
            label: 'Retry',
            tone: PeladinhasButtonTone.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _DiscoveryInlineError extends StatelessWidget {
  const _DiscoveryInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PeladinhasCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(child: Text(message, style: PeladinhasTypography.body)),
          const SizedBox(width: PeladinhasSpacing.md),
          PeladinhasButton(
            label: 'Retry',
            tone: PeladinhasButtonTone.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _DiscoveryNotice extends StatelessWidget {
  const _DiscoveryNotice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Text(message, style: TextStyle(color: color));
  }
}

class _DiscoveryMatchCard extends StatelessWidget {
  const _DiscoveryMatchCard({
    required this.match,
    required this.strings,
    required this.isSubmitted,
    required this.onJoin,
  });

  final MatchDiscoveryItem match;
  final AppStrings strings;
  final bool isSubmitted;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final players = '${match.occupiedPlaces}/${match.maxPlayers} players';
    final available = match.availablePlaces == 1
        ? '1 place available'
        : '${match.availablePlaces} places available';
    final pitchLines = [
      if (match.pitchName != null && match.pitchName!.isNotEmpty)
        match.pitchName!,
      if (match.pitchAddress != null && match.pitchAddress!.isNotEmpty)
        match.pitchAddress!,
    ];
    final price = _formatPrice(match.pitchBasePrice, match.pitchCurrency);
    return PeladinhasCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PeladinhasSpacing.sm,
            runSpacing: PeladinhasSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PeladinhasStatusLabel(
                label: strings.joinModeLabel(match.joinMode.apiValue),
              ),
              PeladinhasStatusLabel(label: available),
              if (isSubmitted)
                const PeladinhasStatusLabel(label: 'Participation sent'),
            ],
          ),
          const SizedBox(height: PeladinhasSpacing.lg),
          Text(match.displayName, style: PeladinhasTypography.title),
          const SizedBox(height: PeladinhasSpacing.md),
          Wrap(
            spacing: PeladinhasSpacing.lg,
            runSpacing: PeladinhasSpacing.sm,
            children: [
              _MatchFact(
                icon: Icons.schedule_outlined,
                label:
                    '${_formatDateTime(match.startsAt)} - '
                    '${_formatLocalTime(match.endsAt)}',
              ),
              _MatchFact(icon: Icons.groups_outlined, label: players),
              _MatchFact(
                icon: Icons.timer_outlined,
                label: '${match.durationMinutes} minutes',
              ),
              if (price != null)
                _MatchFact(icon: Icons.payments_outlined, label: price),
            ],
          ),
          if (pitchLines.isNotEmpty) ...[
            const SizedBox(height: PeladinhasSpacing.md),
            Text(pitchLines.join(' · '), style: PeladinhasTypography.body),
          ],
          const SizedBox(height: PeladinhasSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: PeladinhasButton(
              label: isSubmitted ? 'Request sent' : _joinButtonLabel(match),
              onPressed: isSubmitted ? null : onJoin,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchFact extends StatelessWidget {
  const _MatchFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: PeladinhasColors.inkSecondary),
        const SizedBox(width: PeladinhasSpacing.xs),
        Text(label, style: PeladinhasTypography.body),
      ],
    );
  }
}

class _MatchesStateCard extends StatelessWidget {
  const _MatchesStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PeladinhasCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PeladinhasTypography.sectionTitle),
          const SizedBox(height: PeladinhasSpacing.sm),
          Text(message, style: PeladinhasTypography.body),
        ],
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
              if (availability != null)
                'Available: ${availability!.isAvailable}',
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
                  _MetricTile(
                    label: widget.strings.myPitches,
                    value: '$pitches',
                  ),
                  _MetricTile(
                    label: widget.strings.bookings,
                    value: '$bookings',
                  ),
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
  const _OwnerBookingsPage({required this.strings, required this.apiClient});

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

String _joinButtonLabel(MatchDiscoveryItem match) {
  return match.joinMode == JoinMode.openJoin ? 'Join match' : 'Request to join';
}

String _participantStatusLabel(String status) {
  return switch (status) {
    'awaiting_payment' => 'Awaiting payment',
    'requested' => 'Requested',
    'confirmed' => 'Confirmed',
    'cancelled' => 'Cancelled',
    _ => 'Updated',
  };
}

String _formatQueryTime(TimeOfDay? value) {
  if (value == null) {
    return '';
  }
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int _minutesOfDay(TimeOfDay value) {
  return (value.hour * 60) + value.minute;
}

String _formatShortDate(DateTime? value) {
  if (value == null) {
    return 'Any';
  }
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _formatTimeOfDay(TimeOfDay? value) {
  if (value == null) {
    return 'Any';
  }
  return _formatQueryTime(value);
}

String _formatLocalTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String? _formatPrice(num? price, String? currency) {
  if (price == null || currency == null || currency.trim().isEmpty) {
    return null;
  }
  final formatted = price % 1 == 0 ? price.toInt().toString() : '$price';
  return '$formatted ${currency.trim().toUpperCase()}';
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

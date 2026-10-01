import '../models/user_profile.dart';

class AppStrings {
  const AppStrings._(this.languageCode);

  final String languageCode;

  static AppStrings forProfile(UserProfile? profile) {
    return AppStrings._(profile?.preferredLanguage == 'pt' ? 'pt' : 'en');
  }

  String get appName => 'Peladinhas';
  String get email => _choose('Email', 'Email');
  String get password => _choose('Password', 'Palavra-passe');
  String get signUp => _choose('Sign Up', 'Criar conta');
  String get logIn => _choose('Log In', 'Entrar');
  String get logOut => _choose('Log Out', 'Sair');
  String get name => _choose('Name', 'Nome');
  String get preferredLanguage =>
      _choose('Preferred language', 'Idioma preferido');
  String get english => _choose('English', 'Inglês');
  String get portuguese => _choose('Portuguese', 'Português');
  String get createProfile =>
      _choose('Create Peladinhas Profile', 'Criar perfil Peladinhas');
  String get playerAccount => _choose('Player', 'Jogador');
  String get pitchOwnerAccount =>
      _choose('Pitch owner', 'Dono de campo');
  String get pitchOwnerSignupNote => _choose(
    'Pitch owners can also use all Player features.',
    'Donos de campo também podem usar todas as funcionalidades de jogador.',
  );
  String get ownerInvitationCode =>
      _choose('Invitation code', 'Código de convite');
  String get ownerInvitationHelper => _choose(
    'The code is checked after authentication and is never stored here.',
    'O código é validado após autenticação e nunca é guardado aqui.',
  );
  String get home => _choose('Home', 'Início');
  String get matches => _choose('Matches', 'Jogos');
  String get groups => _choose('Groups', 'Grupos');
  String get pitches => _choose('Pitches', 'Campos');
  String get profile => _choose('Profile', 'Perfil');
  String get welcomeBack => _choose('Welcome back', 'Bem-vindo de volta');
  String get upcomingEmpty =>
      _choose('You have no upcoming matches.', 'Não tem jogos futuros.');
  String get groupsEmpty => _choose(
    'You don’t have any groups yet. Create or join a group to organize matches with your regular players.',
    'Ainda não tem grupos. Crie ou entre num grupo para organizar jogos com os seus jogadores habituais.',
  );
  String get debugTool => _choose('Debug E2E tool', 'Ferramenta técnica E2E');
  String get playerMode => _choose('Player mode', 'Modo jogador');
  String get ownerMode => _choose('Owner mode', 'Modo dono');
  String get ownerDashboard =>
      _choose('Owner dashboard', 'Painel de dono');
  String get myPitches => _choose('My pitches', 'Os meus campos');
  String get bookings => _choose('Bookings', 'Reservas');
  String get ownerSettings =>
      _choose('Owner settings', 'Definições de dono');
  String get becomePitchOwner =>
      _choose('Become a pitch owner', 'Tornar-me dono de campo');
  String get activateOwnerMode =>
      _choose('Activate owner mode', 'Ativar modo dono');
  String get noOwnerPitches => _choose(
    'No pitches yet. Add a pitch to start receiving booking requests.',
    'Ainda não tem campos. Adicione um campo para começar a receber pedidos de reserva.',
  );
  String get noOwnerBookings => _choose(
    'No bookings yet. Bookings for your pitches will appear here.',
    'Ainda não há reservas. As reservas dos seus campos aparecem aqui.',
  );
  String get ownerDataLoadError => _choose(
    "We couldn't load this owner information. Please try again.",
    'Não foi possível carregar esta informação de dono. Tente novamente.',
  );
  String get retry => _choose('Retry', 'Tentar novamente');

  String joinModeLabel(String code) {
    return switch (code) {
      'open_join' => _choose('Open join', 'Entrada aberta'),
      'request_to_join' => _choose('Request to join', 'Pedido de entrada'),
      _ => code,
    };
  }

  String languageName(String code) {
    return switch (code) {
      'en' => _choose('English', 'Inglês'),
      'pt' => _choose('Portuguese', 'Português'),
      _ => code,
    };
  }

  String _choose(String en, String pt) {
    return languageCode == 'pt' ? pt : en;
  }
}

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

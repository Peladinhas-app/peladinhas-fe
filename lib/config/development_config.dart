class DevelopmentConfig {
  const DevelopmentConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'PELADINHAS_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const organizerUserId = '00000000-0000-4000-8000-000000000001';
  static const playerUserId = '00000000-0000-4000-8000-000000000002';
}

class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.ventourkids.io.vn/api',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '356287825696-rjcnj6dam3n0r4sk5sor670hufg7n1cl.apps.googleusercontent.com',
  );

  static const String map4dAccessKey = String.fromEnvironment(
    'MAP4D_ACCESS_KEY',
    defaultValue: '28a1b483b5489fa57f38459d36a358db',
  );
}

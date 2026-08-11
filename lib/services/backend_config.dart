/// Backend endpoint configuration.
///
/// Defaults to the existing Express.js + WebSocket server on port 3456.
/// Override at build time with:
/// `flutter build apk --dart-define=MUSIC_SYNC_HOST=192.168.1.10`
class BackendConfig {
  BackendConfig._();

  static const String host = String.fromEnvironment(
    'MUSIC_SYNC_HOST',
    defaultValue: 'localhost',
  );

  static const int port = int.fromEnvironment(
    'MUSIC_SYNC_PORT',
    defaultValue: 3456,
  );

  static String get wsUrl => 'ws://$host:$port';

  static String get httpBase => 'http://$host:$port';

  static Uri searchUri(String query) =>
      Uri.parse('$httpBase/api/search?q=${Uri.encodeQueryComponent(query)}');

  static Uri streamUrlUri(String videoId) =>
      Uri.parse('$httpBase/api/stream-url?id=${Uri.encodeQueryComponent(videoId)}');
}

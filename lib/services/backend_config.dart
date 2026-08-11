/// Backend endpoint configuration.
///
/// Defaults to the public production endpoint served behind Cloudflare at
/// `musync.invitee.app` (HTTPS/WSS on standard port 443). Verified working:
/// `https://musync.invitee.app/api/search` → 200, `wss://musync.invitee.app/`
/// → 101 Switching Protocols.
///
/// Override at build time for local/dev backends, e.g. the Express server on
/// `localhost:3456` (plain HTTP/WS, no TLS):
/// ```
/// flutter build apk --debug \
///   --dart-define=MUSIC_SYNC_HOST=localhost \
///   --dart-define=MUSIC_SYNC_PORT=3456 \
///   --dart-define=MUSIC_SYNC_SECURE=false
/// ```
class BackendConfig {
  BackendConfig._();

  static const String host = String.fromEnvironment(
    'MUSIC_SYNC_HOST',
    defaultValue: 'musync.invitee.app',
  );

  static const int port = int.fromEnvironment(
    'MUSIC_SYNC_PORT',
    defaultValue: 443,
  );

  /// When true, use `https` / `wss`; when false, `http` / `ws`.
  static const bool secure = bool.fromEnvironment(
    'MUSIC_SYNC_SECURE',
    defaultValue: true,
  );

  /// Authority with port omitted on the well-known HTTP(S) ports.
  static String get _authority =>
      (port == 80 || port == 443) ? host : '$host:$port';

  static String get wsUrl => '${secure ? 'wss' : 'ws'}://$_authority';

  static String get httpBase => '${secure ? 'https' : 'http'}://$_authority';

  static Uri searchUri(String query) =>
      Uri.parse('$httpBase/api/search?q=${Uri.encodeQueryComponent(query)}');

  static Uri streamUrlUri(String videoId) =>
      Uri.parse('$httpBase/api/stream-url?id=${Uri.encodeQueryComponent(videoId)}');
}

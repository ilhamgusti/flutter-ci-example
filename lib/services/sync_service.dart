import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/video.dart';

/// A parsed incoming server message.
typedef ServerMessage = Map<String, dynamic>;

/// Thin client for the backend WebSocket protocol.
///
/// Wire protocol (must match `music-sync/server.js` exactly):
/// ```text
/// client → server: {type:hello|action|loadVideo|queue|next|ended}
/// server → client: {type:state|action|loadVideo|queue|users}
/// ```
///
/// The channel is injected so tests can drive the client with a
/// [WebSocketChannel] fake; production uses
/// `WebSocketChannel.connect(Uri.parse(BackendConfig.wsUrl))`.
class SyncService {
  SyncService({required WebSocketChannel channel}) : _channel = channel;

  final WebSocketChannel _channel;
  final StreamController<ServerMessage> _messages =
      StreamController<ServerMessage>.broadcast();
  bool _listening = false;

  /// Parsed server messages, one per inbound frame.
  Stream<ServerMessage> get messages => _messages.stream;

  bool get isClosed => _channel.closeCode != null;

  /// Waits for the socket to be ready, starts listening, and announces
  /// [name] to the server (`{type:hello}`).
  Future<void> connect(String name) async {
    await _channel.ready;
    _listen();
    send({'type': 'hello', 'name': name});
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.stream.listen(
      (raw) {
        if (raw is! String) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _messages.add(decoded);
          }
        } on FormatException {
          // Ignore malformed frames, same as the web client.
        }
      },
      onError: (_) {},
    );
  }

  /// Sends any protocol message as JSON.
  void send(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }

  /// `{type:action, action: play|pause|seek, time}` — time in seconds.
  void sendAction(String action, double time) {
    send({'type': 'action', 'action': action, 'time': time});
  }

  /// `{type:loadVideo, video: {id, title, channel, thumbnail, duration}}`.
  void loadVideo(Video video) {
    send({'type': 'loadVideo', 'video': video.toJson()});
  }

  /// `{type:next}` — play next queue item.
  void next() => send({'type': 'next'});

  /// `{type:ended}` — current video finished.
  void ended() => send({'type': 'ended'});

  /// `{type:queue, op:add, video}`.
  void queueAdd(Video video) {
    send({'type': 'queue', 'op': 'add', 'video': video.toJson()});
  }

  /// `{type:queue, op:remove, index}`.
  void queueRemove(int index) {
    send({'type': 'queue', 'op': 'remove', 'index': index});
  }

  /// `{type:queue, op:clear}`.
  void queueClear() => send({'type': 'queue', 'op': 'clear'});

  Future<void> close() => _channel.sink.close();
}

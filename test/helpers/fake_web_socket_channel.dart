import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory [WebSocketChannel] for driving [SyncService] in tests.
///
/// Records every frame the client sends (`sentFrames` as decoded JSON) and
/// lets the test push server frames with [serverSend].
class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();

  /// Frames sent by the client, decoded from JSON.
  final List<Map<String, dynamic>> sentFrames = [];

  int? _closeCode;
  String? _closeReason;
  bool _closed = false;

  bool get isClosed => _closed;

  /// Emits a server → client frame.
  void serverSend(Map<String, dynamic> message) {
    _incoming.add(jsonEncode(message));
  }

  /// Emits a raw (possibly malformed) server frame.
  void serverSendRaw(String raw) => _incoming.add(raw);

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(this);

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  void _record(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) sentFrames.add(decoded);
    } on FormatException {
      // Keep raw frames out; the client only ever sends JSON maps.
    }
  }

  void _close(int? code, String? reason) {
    _closed = true;
    _closeCode = code;
    _closeReason = reason;
    _incoming.close();
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._channel);

  final FakeWebSocketChannel _channel;

  @override
  void add(dynamic data) => _channel._record(data as String);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    _channel._close(closeCode, closeReason);
  }

  @override
  Future get done => Future.value();
}

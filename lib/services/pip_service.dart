import 'dart:async';

import 'package:flutter/services.dart';

/// Bridge to the Android Picture-in-Picture native side
/// (`MainActivity`, channels `music_sync/pip` and `music_sync/pip_events`).
///
/// PiP requires Android 8.0 (API 26); [isSupported] reports the device's
/// capability. All methods are safe to call on unsupported devices (they
/// no-op / return false).
class PipService {
  PipService({MethodChannel? methodChannel, EventChannel? eventChannel})
      : _method = methodChannel ?? const MethodChannel('music_sync/pip'),
        _event = eventChannel ?? const EventChannel('music_sync/pip_events');

  final MethodChannel _method;
  final EventChannel _event;

  Stream<bool>? _pipModeStream;
  StreamSubscription<bool>? _pipSub;

  Future<bool> get isSupported async {
    try {
      return await _method.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Requests the system to enter PiP now. Returns false if unsupported or
  /// the system rejects the request.
  Future<bool> enter() async {
    try {
      return await _method.invokeMethod<bool>('enter') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Tells the native side whether to auto-enter PiP when the user leaves the
  /// app (e.g. presses Home) — set true while a video is playing, false
  /// otherwise.
  Future<void> setAutoEnter(bool enabled) =>
      _method.invokeMethod('setAutoEnter', {'enabled': enabled});

  /// Emits the current PiP mode, starting with the value at subscription time.
  Stream<bool> get inPipMode {
    _pipModeStream ??= _event.receiveBroadcastStream().map(
          (event) => (event is Map && event['inPip'] == true) ||
              event == true,
        );
    return _pipModeStream!;
  }

  /// Convenience: subscribes to PiP mode changes for the lifetime of the app.
  StreamSubscription<bool> listen(void Function(bool inPip) onChanged) {
    _pipSub?.cancel();
    _pipSub = inPipMode.listen(onChanged);
    return _pipSub!;
  }

  Future<void> dispose() async {
    await _pipSub?.cancel();
  }
}

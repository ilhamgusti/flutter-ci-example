import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player_command.dart';
import '../models/sync_state.dart';
import '../models/video.dart';
import '../services/sync_service.dart';

/// Client-side state for the music sync room, wired to the backend
/// WebSocket protocol.
///
/// Mirrors the web client's `handleState` / `handleRemoteAction` /
/// `handleLoadVideo` logic: server timestamps are millisecond epoch values
/// used to compute the playhead offset (`elapsed = (now - timestamp) / 1000`).
class MusicSyncProvider extends ChangeNotifier {
  MusicSyncProvider({
    required SyncService service,
    this.echoSuppressDuration = const Duration(milliseconds: 800),
    this.reconnectDelay = const Duration(seconds: 2),
    DateTime Function()? clock,
  })  : _service = service,
        _clock = clock ?? DateTime.now;

  final SyncService _service;
  final DateTime Function() _clock;
  final Duration echoSuppressDuration;
  final Duration reconnectDelay;

  final StreamController<PlayerCommand> _commandController =
      StreamController<PlayerCommand>.broadcast(sync: true);

  /// Commands for the UI to apply to the YouTube player.
  Stream<PlayerCommand> get playerCommands => _commandController.stream;

  String? _myName;
  bool _connected = false;
  bool _isPlaying = false;
  double _currentTime = 0;
  int _lastSyncTime = 0;
  Video? _currentVideo;
  List<Video> _queue = const [];
  List<String> _users = const [];
  String? _errorMessage;
  bool _echoSuppressed = false;
  Timer? _suppressTimer;
  Timer? _reconnectTimer;
  StreamSubscription<ServerMessage>? _subscription;

  String? get myName => _myName;
  bool get connected => _connected;
  bool get isPlaying => _isPlaying;
  double get currentTime => _currentTime;
  int get lastSyncTime => _lastSyncTime;
  Video? get currentVideo => _currentVideo;
  List<Video> get queue => _queue;
  List<String> get users => _users;
  String? get errorMessage => _errorMessage;

  /// Connects to the server and announces [name] (`{type:hello}`).
  Future<void> join(String name) async {
    if (name.trim().isEmpty) return;
    _myName = name.trim();
    _errorMessage = null;
    _resetState();
    try {
      await _service.connect(_myName!);
      _connected = true;
      _subscription = _service.messages.listen(_handleMessage);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Tidak dapat terhubung ke server: $e';
      notifyListeners();
    }
  }

  void _resetState() {
    _currentVideo = null;
    _isPlaying = false;
    _currentTime = 0;
    _lastSyncTime = 0;
    _queue = const [];
    _users = const [];
  }

  void _handleMessage(ServerMessage msg) {
    switch (msg['type']) {
      case 'state':
        _applyState(SyncState.fromJson(msg['state'] as Map<String, dynamic>));
      case 'action':
        _handleRemoteAction(msg);
      case 'loadVideo':
        _handleRemoteLoadVideo(msg);
      case 'queue':
        _applyQueue(msg['queue']);
      case 'users':
        _users = (msg['users'] as List? ?? const [])
            .map((u) => u.toString())
            .toList();
        notifyListeners();
    }
  }

  void _applyState(SyncState state) {
    _currentVideo = state.currentVideo;
    _isPlaying = state.isPlaying;
    _currentTime = state.currentTime;
    _lastSyncTime = state.lastSyncTime;
    _queue = state.queue;

    if (state.isPlaying && state.currentVideo != null) {
      final elapsed = _elapsedSince(state.lastSyncTime);
      final target = state.currentTime + elapsed;
      _currentTime = target;
      _emit(RemoteSeekCommand(seconds: target, play: true));
    }
    notifyListeners();
  }

  void _handleRemoteAction(ServerMessage msg) {
    final action = msg['action'] as String?;
    final time = (msg['time'] as num?)?.toDouble() ?? 0;
    final elapsed = _elapsedSince((msg['timestamp'] as num?)?.toInt() ?? 0);

    switch (action) {
      case 'play':
        final target = time + elapsed;
        _currentTime = target;
        _isPlaying = true;
        _emit(RemoteSeekCommand(seconds: target, play: true));
      case 'pause':
        _currentTime = time + elapsed;
        _isPlaying = false;
        _emit(const RemotePauseCommand());
      case 'seek':
        _currentTime = time + elapsed;
        if (msg['isPlaying'] == true) _isPlaying = true;
        _emit(RemoteSeekCommand(seconds: time + elapsed, play: msg['isPlaying'] == true));
    }
    notifyListeners();
  }

  void _handleRemoteLoadVideo(ServerMessage msg) {
    final rawVideo = msg['video'];
    if (rawVideo is! Map<String, dynamic>) return;
    final video = Video.fromJson(rawVideo);
    final elapsed = _elapsedSince((msg['timestamp'] as num?)?.toInt() ?? 0);

    _currentVideo = video;
    _isPlaying = true;
    _currentTime = elapsed < 600 ? elapsed : 0;
    _emit(RemoteLoadCommand(
      videoId: video.id,
      startSeconds: elapsed < 600 ? elapsed : 0,
      autoplay: true,
    ));
    notifyListeners();
  }

  void _applyQueue(dynamic raw) {
    if (raw is! List) return;
    _queue = raw.whereType<Map<String, dynamic>>().map(Video.fromJson).toList();
    notifyListeners();
  }

  double _elapsedSince(int timestampMs) {
    if (timestampMs <= 0) return 0;
    return (_clock().millisecondsSinceEpoch - timestampMs) / 1000;
  }

  void _emit(PlayerCommand command) {
    _suppressEcho();
    _commandController.add(command);
  }

  /// Suppresses echoing local player callbacks back to the server after a
  /// remote command (the web client's `isRemoteAction` flag).
  void _suppressEcho() {
    _echoSuppressed = true;
    _suppressTimer?.cancel();
    _suppressTimer = Timer(echoSuppressDuration, () {
      _echoSuppressed = false;
    });
  }

  // --- Local user actions -------------------------------------------------

  void play() {
    if (!_connected) return;
    _isPlaying = true;
    _currentTime = _currentTime;
    _service.sendAction('play', _currentTime);
    notifyListeners();
  }

  void pause() {
    if (!_connected) return;
    _isPlaying = false;
    _service.sendAction('pause', _currentTime);
    notifyListeners();
  }

  void seekTo(double seconds) {
    if (!_connected) return;
    _currentTime = seconds;
    _service.sendAction('seek', seconds);
    notifyListeners();
  }

  /// Loads a video and tells the server everyone should play it.
  void playNow(Video video) {
    if (!_connected) return;
    _currentVideo = video;
    _isPlaying = true;
    _currentTime = 0;
    _service.loadVideo(video);
    _emit(RemoteLoadCommand(videoId: video.id, startSeconds: 0, autoplay: true));
    notifyListeners();
  }

  void next() {
    if (!_connected) return;
    _service.next();
  }

  void addToQueue(Video video) {
    if (!_connected) return;
    _service.queueAdd(video);
  }

  void removeFromQueue(int index) {
    if (!_connected) return;
    _service.queueRemove(index);
  }

  void clearQueue() {
    if (!_connected) return;
    _service.queueClear();
  }

  /// Called by the UI when the local player's playback state changes
  /// (user pressed play/pause or the video ended). Echoes to the server
  /// unless the change was caused by a remote command.
  void onLocalPlaybackStateChanged(bool isPlaying, double position) {
    _currentTime = position;
    if (_echoSuppressed || !_connected) {
      notifyListeners();
      return;
    }
    if (_isPlaying == isPlaying) {
      notifyListeners();
      return;
    }
    _isPlaying = isPlaying;
    _service.sendAction(isPlaying ? 'play' : 'pause', position);
    notifyListeners();
  }

  void onVideoEnded() {
    if (!_connected) return;
    _service.ended();
  }

  void leave() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _connected = false;
    _service.close();
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _suppressTimer?.cancel();
    _subscription?.cancel();
    _commandController.close();
    super.dispose();
  }
}

import 'video.dart';

/// Server-side shared state as broadcast by the backend.
///
/// Mirrors `server.js`:
/// ```js
/// const state = { currentVideo, isPlaying, currentTime, lastSyncTime, queue };
/// ```
/// `lastSyncTime` is a millisecond epoch timestamp (server `Date.now()`),
/// used by clients to compute the playhead offset for sync.
class SyncState {
  const SyncState({
    this.currentVideo,
    this.isPlaying = false,
    this.currentTime = 0.0,
    this.lastSyncTime = 0,
    this.queue = const [],
  });

  final Video? currentVideo;
  final bool isPlaying;
  final double currentTime;
  final int lastSyncTime;
  final List<Video> queue;

  factory SyncState.fromJson(Map<String, dynamic> json) {
    final video = json['currentVideo'];
    final rawQueue = json['queue'];
    return SyncState(
      currentVideo: video is Map<String, dynamic> ? Video.fromJson(video) : null,
      isPlaying: json['isPlaying'] == true,
      currentTime: (json['currentTime'] as num?)?.toDouble() ?? 0.0,
      lastSyncTime: (json['lastSyncTime'] as num?)?.toInt() ?? 0,
      queue: rawQueue is List
          ? rawQueue
              .whereType<Map<String, dynamic>>()
              .map(Video.fromJson)
              .toList()
          : const [],
    );
  }
}

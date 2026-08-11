/// Commands emitted by [MusicSyncProvider] for the UI to apply to the
/// YouTube player. These encode remote (server-broadcast) playback changes.
sealed class PlayerCommand {
  const PlayerCommand();
}

/// Load a video into the player, optionally seeking to [startSeconds].
class RemoteLoadCommand extends PlayerCommand {
  const RemoteLoadCommand({
    required this.videoId,
    required this.startSeconds,
    required this.autoplay,
  });

  final String videoId;
  final double startSeconds;
  final bool autoplay;
}

/// Seek the player to [seconds]; if [play] is true, resume playback after.
class RemoteSeekCommand extends PlayerCommand {
  const RemoteSeekCommand({required this.seconds, required this.play});

  final double seconds;
  final bool play;
}

/// Pause playback (remote).
class RemotePauseCommand extends PlayerCommand {
  const RemotePauseCommand();
}

/// Resume playback (remote).
class RemotePlayCommand extends PlayerCommand {
  const RemotePlayCommand();
}

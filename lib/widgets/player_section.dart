import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/player_command.dart';
import '../models/video.dart';
import '../providers/music_sync_provider.dart';

/// Renders the YouTube player plus now-playing info and transport controls.
///
/// [playerBuilder] is injectable so widget tests can substitute a plain
/// widget for the real (webview-backed) player.
class PlayerSection extends StatefulWidget {
  const PlayerSection({
    super.key,
    required this.provider,
    this.playerBuilder,
    this.compact = false,
  });

  final MusicSyncProvider provider;

  /// Replaces the real YouTube player surface (used by tests).
  final Widget Function(BuildContext context, Video video)? playerBuilder;

  /// Picture-in-Picture mode: render only the player surface, edge-to-edge.
  final bool compact;


  @override
  State<PlayerSection> createState() => _PlayerSectionState();
}

class _PlayerSectionState extends State<PlayerSection> {
  YoutubePlayerController? _controller;
  StreamSubscription<PlayerCommand>? _commandSub;
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _positionSub;
  double _lastPositionSeconds = 0;
  bool _echoBlocked = false;

  @override
  void initState() {
    super.initState();
    _commandSub = widget.provider.playerCommands.listen(_applyCommand);
  }

  void _applyCommand(PlayerCommand command) {
    // Test mode: the injected surface renders instead; never touch a real
    // (webview-backed) controller or schedule player timers.
    if (widget.playerBuilder != null) return;

    switch (command) {
      case RemoteLoadCommand():
        _loadVideo(command);
      case RemoteSeekCommand():
        _echoBlocked = true;
        _controller?.seekTo(seconds: command.seconds, allowSeekAhead: true);
        if (command.play) _controller?.playVideo();
        _releaseEcho();
      case RemotePauseCommand():
        _echoBlocked = true;
        _controller?.pauseVideo();
        _releaseEcho();
      case RemotePlayCommand():
        _echoBlocked = true;
        _controller?.playVideo();
        _releaseEcho();
    }
  }

  void _loadVideo(RemoteLoadCommand command) {
    _echoBlocked = true;
    final old = _controller;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: command.videoId,
      startSeconds: command.startSeconds,
      autoPlay: command.autoplay,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
    _valueSub?.cancel();
    _positionSub?.cancel();
    _valueSub = _controller!.stream.listen(_onPlayerValue);
    _positionSub = _controller!.videoStateStream.listen((state) {
      _lastPositionSeconds = state.position.inMilliseconds / 1000;
    });
    setState(() {});
    // Player events fire immediately after load; keep them local-only for a
    // beat so the initial autoplay isn't echoed back to the server.
    _releaseEcho(after: const Duration(milliseconds: 1500));
    old?.close();
  }

  void _onPlayerValue(YoutubePlayerValue value) {
    if (value.playerState == PlayerState.ended) {
      if (!_echoBlocked) widget.provider.onVideoEnded();
      return;
    }
    if (_echoBlocked) return;
    widget.provider.onLocalPlaybackStateChanged(
      value.playerState == PlayerState.playing,
      _lastPositionSeconds,
    );
  }

  void _releaseEcho({Duration after = const Duration(milliseconds: 600)}) {
    Future.delayed(after, () {
      if (mounted) _echoBlocked = false;
    });
  }

  @override
  void dispose() {
    _commandSub?.cancel();
    _valueSub?.cancel();
    _positionSub?.cancel();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.provider.currentVideo;
    if (widget.compact) {
      // PiP: only the player surface, edge-to-edge, no chrome.
      return video == null
          ? const ColoredBox(color: Colors.black, child: SizedBox.expand())
          : SizedBox.expand(child: _buildPlayer(video));
    }
    if (video == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EmptyPlayer(),
          SizedBox(height: 12),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPlayer(video),
        const SizedBox(height: 12),
        _NowPlayingInfo(video: video, provider: widget.provider),
        _TransportControls(provider: widget.provider),
      ],
    );
  }

  Widget _buildPlayer(Video video) {
    final builder = widget.playerBuilder;
    if (builder != null) return builder(context, video);
    final controller = _controller;
    if (controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: YoutubePlayer(controller: controller),
      ),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline, size: 64),
              SizedBox(height: 8),
              Text('Belum ada lagu — cari atau play dari queue'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingInfo extends StatelessWidget {
  const _NowPlayingInfo({required this.video, required this.provider});

  final Video video;
  final MusicSyncProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                video.channel.isEmpty ? 'YouTube' : video.channel,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (provider.isPlaying)
          Icon(Icons.graphic_eq, color: theme.colorScheme.primary)
        else
          const Icon(Icons.pause_circle_outline),
      ],
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.provider});

  final MusicSyncProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Play',
          icon: const Icon(Icons.play_arrow),
          onPressed: provider.connected ? provider.play : null,
        ),
        IconButton(
          tooltip: 'Pause',
          icon: const Icon(Icons.pause),
          onPressed: provider.connected ? provider.pause : null,
        ),
        IconButton(
          tooltip: 'Next',
          icon: const Icon(Icons.skip_next),
          onPressed: provider.connected ? provider.next : null,
        ),
        if (provider.pipSupported &&
            provider.currentVideo != null &&
            !provider.inPipMode)
          IconButton(
            tooltip: 'Picture-in-Picture',
            icon: const Icon(Icons.picture_in_picture_alt),
            onPressed: provider.enterPip,
          ),
      ],
    );
  }
}

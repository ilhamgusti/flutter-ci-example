import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_ci_example/models/player_command.dart';
import 'package:flutter_ci_example/models/video.dart';
import 'package:flutter_ci_example/providers/music_sync_provider.dart';
import 'package:flutter_ci_example/services/sync_service.dart';

import '../helpers/fake_web_socket_channel.dart';

void main() {
  const video = Video(
    id: 'dQw4w9WgXcQ',
    title: 'Rick Astley - Never Gonna Give You Up',
    duration: 213,
    thumbnail: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
    channel: 'Rick Astley',
  );

  late FakeWebSocketChannel channel;
  late MusicSyncProvider provider;
  final commands = <PlayerCommand>[];

  Future<void> setUpProvider({Duration echoSuppress = Duration.zero}) async {
    channel = FakeWebSocketChannel();
    provider = MusicSyncProvider(
      service: SyncService(channel: channel),
      echoSuppressDuration: echoSuppress,
    );
    commands.clear();
    provider.playerCommands.listen(commands.add);
    await provider.join('Ilham');
  }

  tearDown(() {
    provider.dispose();
  });

  group('join', () {
    test('announces hello and exposes the name', () async {
      await setUpProvider();

      expect(provider.myName, 'Ilham');
      expect(provider.connected, isTrue);
      expect(channel.sentFrames.first, {'type': 'hello', 'name': 'Ilham'});
    });

    test('blank names are rejected', () async {
      channel = FakeWebSocketChannel();
      provider = MusicSyncProvider(service: SyncService(channel: channel));
      await provider.join('   ');

      expect(provider.myName, isNull);
      expect(channel.sentFrames, isEmpty);
    });
  });

  group('server state', () {
    test('state message applies video, queue and playhead', () async {
      await setUpProvider();

      channel.serverSend({
        'type': 'state',
        'state': {
          'currentVideo': video.toJson(),
          'isPlaying': true,
          'currentTime': 30,
          'lastSyncTime': DateTime.now().millisecondsSinceEpoch - 2000,
          'queue': [video.toJson()],
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentVideo, video);
      expect(provider.isPlaying, isTrue);
      expect(provider.queue, [video]);
      // Playhead advanced ~2s past the reported time.
      expect(provider.currentTime, closeTo(32, 1.5));
      expect(commands.single, isA<RemoteSeekCommand>());
      final seek = commands.single as RemoteSeekCommand;
      expect(seek.seconds, closeTo(32, 1.5));
      expect(seek.play, isTrue);
    });

    test('users message replaces the user list', () async {
      await setUpProvider();

      channel.serverSend({'type': 'users', 'users': ['Ilham', 'Budi']});
      await Future<void>.delayed(Duration.zero);

      expect(provider.users, ['Ilham', 'Budi']);
    });
  });

  group('remote actions', () {
    test('remote play seeks to the target and plays', () async {
      await setUpProvider(echoSuppress: const Duration(milliseconds: 50));

      channel.serverSend({
        'type': 'action',
        'action': 'play',
        'time': 10,
        'timestamp': DateTime.now().millisecondsSinceEpoch - 1000,
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPlaying, isTrue);
      expect(provider.currentTime, closeTo(11, 1.0));
      final seek = commands.single as RemoteSeekCommand;
      expect(seek.seconds, closeTo(11, 1.0));
      expect(seek.play, isTrue);
    });

    test('remote pause stops playback', () async {
      await setUpProvider();

      channel.serverSend({
        'type': 'action',
        'action': 'pause',
        'time': 15,
        'timestamp': DateTime.now().millisecondsSinceEpoch - 500,
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPlaying, isFalse);
      expect(commands.single, isA<RemotePauseCommand>());
    });

    test('remote seek repositions and resumes when isPlaying', () async {
      await setUpProvider();

      channel.serverSend({
        'type': 'action',
        'action': 'seek',
        'time': 77,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isPlaying': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPlaying, isTrue);
      final seek = commands.single as RemoteSeekCommand;
      expect(seek.seconds, closeTo(77, 1.0));
      expect(seek.play, isTrue);
    });
  });

  group('remote loadVideo', () {
    test('loads the video and starts playback from the offset', () async {
      await setUpProvider();

      channel.serverSend({
        'type': 'loadVideo',
        'video': video.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch - 4000,
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentVideo, video);
      expect(provider.isPlaying, isTrue);
      final load = commands.single as RemoteLoadCommand;
      expect(load.videoId, video.id);
      expect(load.startSeconds, closeTo(4, 1.0));
      expect(load.autoplay, isTrue);
    });

    test('old loadVideo timestamps (>600s) start from zero', () async {
      await setUpProvider();

      channel.serverSend({
        'type': 'loadVideo',
        'video': video.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch - 601000,
      });
      await Future<void>.delayed(Duration.zero);

      final load = commands.single as RemoteLoadCommand;
      expect(load.startSeconds, 0);
    });
  });

  group('queue updates', () {
    test('queue message replaces the queue', () async {
      await setUpProvider();

      channel.serverSend({
        'type': 'queue',
        'queue': [video.toJson()],
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.queue, [video]);
    });
  });

  group('local actions', () {
    test('playNow sends loadVideo and emits a load command', () async {
      await setUpProvider();

      provider.playNow(video);

      expect(channel.sentFrames.last, {
        'type': 'loadVideo',
        'video': video.toJson(),
      });
      expect(provider.currentVideo, video);
      expect(provider.isPlaying, isTrue);
      final load = commands.single as RemoteLoadCommand;
      expect(load.videoId, video.id);
      expect(load.autoplay, isTrue);
    });

    test('play/pause/seek send action messages with current time', () async {
      await setUpProvider();
      provider.seekTo(30);
      provider.play();
      provider.pause();

      final actions = channel.sentFrames
          .where((f) => f['type'] == 'action')
          .toList();
      expect(actions, [
        {'type': 'action', 'action': 'seek', 'time': 30},
        {'type': 'action', 'action': 'play', 'time': 30},
        {'type': 'action', 'action': 'pause', 'time': 30},
      ]);
    });

    test('queue ops forward to the server', () async {
      await setUpProvider();

      provider.addToQueue(video);
      provider.removeFromQueue(0);
      provider.clearQueue();

      expect(
        channel.sentFrames
            .where((f) => f['type'] == 'queue')
            .toList(),
        [
          {'type': 'queue', 'op': 'add', 'video': video.toJson()},
          {'type': 'queue', 'op': 'remove', 'index': 0},
          {'type': 'queue', 'op': 'clear'},
        ],
      );
    });

    test('next sends the next message', () async {
      await setUpProvider();

      provider.next();

      expect(channel.sentFrames.last, {'type': 'next'});
    });

    test('local playback state transitions echo to the server', () async {
      await setUpProvider();

      provider.onLocalPlaybackStateChanged(true, 12);
      provider.onLocalPlaybackStateChanged(false, 14);

      expect(
        channel.sentFrames.where((f) => f['type'] == 'action').toList(),
        [
          {'type': 'action', 'action': 'play', 'time': 12},
          {'type': 'action', 'action': 'pause', 'time': 14},
        ],
      );
      expect(provider.currentTime, 14);
    });

    test('echo is suppressed right after a remote command', () async {
      await setUpProvider(echoSuppress: const Duration(milliseconds: 200));

      channel.serverSend({
        'type': 'action',
        'action': 'play',
        'time': 10,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await Future<void>.delayed(Duration.zero);

      // Player state change following the remote command must not be echoed.
      provider.onLocalPlaybackStateChanged(true, 10);
      expect(channel.sentFrames.where((f) => f['type'] == 'action'), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      provider.onLocalPlaybackStateChanged(false, 12);
      expect(
        channel.sentFrames.last,
        {'type': 'action', 'action': 'pause', 'time': 12},
      );
    });

    test('onVideoEnded sends the ended message', () async {
      await setUpProvider();

      provider.onVideoEnded();

      expect(channel.sentFrames.last, {'type': 'ended'});
    });
  });

  test('local actions are no-ops while disconnected', () async {
    channel = FakeWebSocketChannel();
    provider = MusicSyncProvider(service: SyncService(channel: channel));

    provider.play();
    provider.pause();
    provider.playNow(video);
    provider.next();

    expect(channel.sentFrames, isEmpty);
  });
}

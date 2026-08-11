import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_ci_example/models/video.dart';
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
  late SyncService service;

  setUp(() {
    channel = FakeWebSocketChannel();
    service = SyncService(channel: channel);
  });

  test('connect sends hello with the user name', () async {
    await service.connect('Ilham');

    expect(channel.sentFrames, [
      {'type': 'hello', 'name': 'Ilham'},
    ]);
  });

  test('incoming server frames are parsed and streamed', () async {
    final received = <Map<String, dynamic>>[];
    final sub = service.messages.listen(received.add);
    await service.connect('Ilham');

    channel.serverSend({
      'type': 'state',
      'state': {'currentVideo': null, 'isPlaying': false, 'currentTime': 0},
    });
    channel.serverSend({'type': 'users', 'users': ['Ilham', 'Budi']});

    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(2));
    expect(received[0]['type'], 'state');
    expect(received[1]['users'], ['Ilham', 'Budi']);
    await sub.cancel();
  });

  test('malformed server frames are ignored', () async {
    final received = <Map<String, dynamic>>[];
    final sub = service.messages.listen(received.add);
    await service.connect('Ilham');

    channel.serverSendRaw('{not json');
    await Future<void>.delayed(Duration.zero);

    expect(received, isEmpty);
    await sub.cancel();
  });

  test('sendAction emits {type:action, action, time} with seconds', () {
    service.sendAction('play', 12.5);
    service.sendAction('pause', 12.5);
    service.sendAction('seek', 42);

    expect(channel.sentFrames, [
      {'type': 'action', 'action': 'play', 'time': 12.5},
      {'type': 'action', 'action': 'pause', 'time': 12.5},
      {'type': 'action', 'action': 'seek', 'time': 42},
    ]);
  });

  test('loadVideo emits the full video object', () {
    service.loadVideo(video);

    expect(channel.sentFrames, [
      {
        'type': 'loadVideo',
        'video': {
          'id': 'dQw4w9WgXcQ',
          'title': 'Rick Astley - Never Gonna Give You Up',
          'duration': 213,
          'thumbnail': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
          'channel': 'Rick Astley',
        },
      },
    ]);
  });

  test('queue ops emit add/remove/clear shapes', () {
    service.queueAdd(video);
    service.queueRemove(2);
    service.queueClear();

    expect(channel.sentFrames, [
      {'type': 'queue', 'op': 'add', 'video': jsonDecode(video.encode())},
      {'type': 'queue', 'op': 'remove', 'index': 2},
      {'type': 'queue', 'op': 'clear'},
    ]);
  });

  test('next and ended emit their one-word messages', () {
    service.next();
    service.ended();

    expect(channel.sentFrames, [
      {'type': 'next'},
      {'type': 'ended'},
    ]);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:flutter_ci_example/models/video.dart';
import 'package:flutter_ci_example/providers/music_sync_provider.dart';
import 'package:flutter_ci_example/screens/main_screen.dart';
import 'package:flutter_ci_example/services/search_service.dart';
import 'package:flutter_ci_example/services/sync_service.dart';

import '../helpers/fake_web_socket_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pipMethod = MethodChannel('music_sync/pip');
  const pipEvent = MethodChannel('music_sync/pip_events');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pipMethod, (MethodCall call) async {
      switch (call.method) {
        case 'isSupported':
          return true;
        case 'enter':
          return true;
        case 'setAutoEnter':
          return null;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pipEvent, (MethodCall call) async => null);
  });

  const video = Video(
    id: 'dQw4w9WgXcQ',
    title: 'Rick Astley - Never Gonna Give You Up',
    duration: 213,
    thumbnail: '',
    channel: 'Rick Astley',
  );

  late FakeWebSocketChannel channel;
  late MusicSyncProvider provider;

  /// Pump MainScreen with a live provider over a fake socket. The YouTube
  /// player is replaced by a plain placeholder via [playerBuilder].
  Future<MusicSyncProvider> pumpMainScreen(
    WidgetTester tester, {
    SearchService? searchService,
  }) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    channel = FakeWebSocketChannel();
    provider = MusicSyncProvider(service: SyncService(channel: channel));
    await provider.join('Ilham');

    await tester.pumpWidget(
      ChangeNotifierProvider<MusicSyncProvider>.value(
        value: provider,
        child: MaterialApp(
          home: MainScreen(
            searchService: searchService ?? SearchService(client: MockClient((_) async => http.Response('[]', 200))),
            playerBuilder: (context, v) => const SizedBox(
              height: 180,
              child: Center(child: Text('PLAYER')),
            ),
          ),
        ),
      ),
    );
    return provider;
  }

  tearDown(() {
    provider.dispose();
  });

  testWidgets('shows now playing, queue, users and controls', (tester) async {
    await pumpMainScreen(tester);
    await tester.pump();

    channel.serverSend({
      'type': 'state',
      'state': {
        'currentVideo': video.toJson(),
        'isPlaying': true,
        'currentTime': 10,
        'lastSyncTime': DateTime.now().millisecondsSinceEpoch,
        'queue': [video.toJson()],
      },
    });
    channel.serverSend({'type': 'users', 'users': ['Ilham', 'Budi']});
    await tester.pump();
    await tester.pump();

    expect(find.text('Rick Astley - Never Gonna Give You Up'), findsWidgets);
    expect(find.text('2 online · Ilham, Budi'), findsOneWidget);
    expect(find.text('(1)'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Next'), findsOneWidget);

    // Flush the provider's echo-suppression timer before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search renders results and play triggers loadVideo',
      (tester) async {
    final searchService = SearchService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/search');
        return http.Response(
          jsonEncode([
            video.toJson(),
            {
              'id': '9bZkp7q19f0',
              'title': 'PSY - GANGNAM STYLE',
              'duration': 253,
              'thumbnail': '',
              'channel': 'officialpsy',
            },
          ]),
          200,
        );
      }),
    );
    await pumpMainScreen(tester, searchService: searchService);

    await tester.enterText(find.byType(TextField), 'rick astley');
    await tester.ensureVisible(find.text('Cari'));
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();

    expect(find.text('Rick Astley - Never Gonna Give You Up'), findsOneWidget);
    expect(find.text('PSY - GANGNAM STYLE'), findsOneWidget);

    final resultPlay = find.descendant(
      of: find.byType(ListTile),
      matching: find.byTooltip('Play'),
    );
    await tester.ensureVisible(resultPlay.first);
    await tester.tap(resultPlay.first);
    await tester.pump();

    final loadVideo = channel.sentFrames
        .where((f) => f['type'] == 'loadVideo')
        .last;
    expect(loadVideo['video'], video.toJson());
    expect(provider.currentVideo, video);

    // Flush the provider's echo-suppression timer before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('add to queue sends queue add op', (tester) async {
    final searchService = SearchService(
      client: MockClient(
        (_) async => http.Response(jsonEncode([video.toJson()]), 200),
      ),
    );
    await pumpMainScreen(tester, searchService: searchService);

    await tester.enterText(find.byType(TextField), 'rick astley');
    await tester.ensureVisible(find.text('Cari'));
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Tambah ke queue'));
    await tester.tap(find.byTooltip('Tambah ke queue'));
    await tester.pump();

    expect(
      channel.sentFrames.where((f) => f['type'] == 'queue').last,
      {'type': 'queue', 'op': 'add', 'video': video.toJson()},
    );
  });

  testWidgets('queue remove and clear send their ops', (tester) async {
    await pumpMainScreen(tester);

    channel.serverSend({
      'type': 'queue',
      'queue': [video.toJson()],
    });
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.byTooltip('Hapus dari queue'));
    await tester.tap(find.byTooltip('Hapus dari queue'));
    await tester.pump();
    expect(
      channel.sentFrames.last,
      {'type': 'queue', 'op': 'remove', 'index': 0},
    );

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(
      channel.sentFrames.last,
      {'type': 'queue', 'op': 'clear'},
    );
  });

  testWidgets('transport controls forward to the provider', (tester) async {
    await pumpMainScreen(tester);

    channel.serverSend({
      'type': 'state',
      'state': {
        'currentVideo': video.toJson(),
        'isPlaying': false,
        'currentTime': 0,
        'lastSyncTime': DateTime.now().millisecondsSinceEpoch,
        'queue': [],
      },
    });
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.byTooltip('Next'));
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    expect(channel.sentFrames.last, {'type': 'next'});

    await tester.ensureVisible(find.byTooltip('Play'));
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(
      channel.sentFrames.last,
      {'type': 'action', 'action': 'play', 'time': 0},
    );

    await tester.ensureVisible(find.byTooltip('Pause'));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(
      channel.sentFrames.last,
      {'type': 'action', 'action': 'pause', 'time': 0},
    );
  });

  testWidgets('search error surfaces a message', (tester) async {
    final searchService = SearchService(
      client: MockClient((_) async => http.Response('{"error":"Search timeout"}', 500)),
    );
    await pumpMainScreen(tester, searchService: searchService);

    await tester.enterText(find.byType(TextField), 'rick astley');
    await tester.ensureVisible(find.text('Cari'));
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal mencari'), findsOneWidget);
  });
}

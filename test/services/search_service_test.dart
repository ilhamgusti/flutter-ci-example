import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_ci_example/models/video.dart';
import 'package:flutter_ci_example/services/backend_config.dart';
import 'package:flutter_ci_example/services/search_service.dart';

void main() {
  group('SearchService', () {
    test('search parses the backend result list', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode([
            {
              'id': 'dQw4w9WgXcQ',
              'title': 'Rick Astley - Never Gonna Give You Up',
              'duration': 213,
              'thumbnail': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
              'channel': 'Rick Astley',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = SearchService(client: client);

      final results = await service.search('never gonna give');

      expect(requested.path, '/api/search');
      expect(requested.queryParameters['q'], 'never gonna give');
      expect(requested.host, BackendConfig.host);
      expect(results, [
        const Video(
          id: 'dQw4w9WgXcQ',
          title: 'Rick Astley - Never Gonna Give You Up',
          duration: 213,
          thumbnail: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
          channel: 'Rick Astley',
        ),
      ]);
    });

    test('search returns empty list for an empty result set', () async {
      final client = MockClient((_) async => http.Response('[]', 200));
      final service = SearchService(client: client);

      expect(await service.search('nothing'), isEmpty);
    });

    test('search throws SearchException on non-200', () async {
      final client = MockClient((_) async => http.Response('{"error":"Search timeout"}', 500));
      final service = SearchService(client: client);

      expect(
        () => service.search('x'),
        throwsA(isA<SearchException>()),
      );
    });

    test('search throws SearchException on non-list payload', () async {
      final client = MockClient((_) async => http.Response('{"error":"nope"}', 200));
      final service = SearchService(client: client);

      expect(
        () => service.search('x'),
        throwsA(isA<SearchException>()),
      );
    });
  });
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/video.dart';
import 'backend_config.dart';

/// Client for the backend search API.
///
/// `GET /api/search?q=…` returns a JSON array of videos:
/// `[{id, title, duration, thumbnail, channel}]` (8 results via yt-dlp).
class SearchService {
  SearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Searches YouTube through the backend. Returns an empty list when the
  /// backend returns no results; throws on transport/parse errors.
  Future<List<Video>> search(String query) async {
    final uri = BackendConfig.searchUri(query);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw SearchException('Search failed (HTTP ${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw SearchException('Unexpected search response');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Video.fromJson)
        .toList();
  }
}

class SearchException implements Exception {
  SearchException(this.message);

  final String message;

  @override
  String toString() => 'SearchException: $message';
}

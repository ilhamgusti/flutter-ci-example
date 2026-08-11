import 'dart:convert';

/// A YouTube video as represented in the backend protocol.
///
/// Wire shape (backend `server.js` `/api/search` and shared state):
/// ```json
/// { "id": "dQw4w9WgXcQ", "title": "...", "duration": 213,
///   "thumbnail": "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg",
///   "channel": "..." }
/// ```
class Video {
  const Video({
    required this.id,
    required this.title,
    this.duration = 0,
    this.thumbnail = '',
    this.channel = '',
  });

  final String id;
  final String title;
  final int duration;
  final String thumbnail;
  final String channel;

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Unknown').toString(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      thumbnail: (json['thumbnail'] ?? '').toString(),
      channel: (json['channel'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'duration': duration,
        'thumbnail': thumbnail,
        'channel': channel,
      };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is Video &&
      other.id == id &&
      other.title == title &&
      other.duration == duration &&
      other.thumbnail == thumbnail &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(id, title, duration, thumbnail, channel);

  @override
  String toString() => 'Video($id, $title)';
}

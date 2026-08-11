import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video.dart';
import '../providers/music_sync_provider.dart';
import '../services/search_service.dart';
import '../widgets/player_section.dart';

/// Main room screen: player, search, shared queue, user presence.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.playerBuilder, SearchService? searchService})
      : _searchService = searchService;

  final SearchService? _searchService;
  final Widget Function(BuildContext context, Video video)? playerBuilder;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SearchService _searchService;
  List<Video> _results = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _searchService = widget._searchService ?? SearchService();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _results = const [];
    });
    try {
      final results = await _searchService.search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Gagal mencari: $e';
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicSyncProvider>();
    // Picture-in-Picture: show only the player surface, no app chrome.
    if (provider.inPipMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: PlayerSection(
            provider: provider,
            playerBuilder: widget.playerBuilder,
            compact: true,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Sync'),
        actions: [_UsersIndicator(users: provider.users, connected: provider.connected)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.errorMessage != null)
            _ErrorBanner(message: provider.errorMessage!),
          PlayerSection(provider: provider, playerBuilder: widget.playerBuilder),
          const SizedBox(height: 16),
          _SearchBar(
            controller: _searchController,
            onSearch: _search,
            enabled: !_searching,
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_searchError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            )
          else if (_results.isNotEmpty)
            _SearchResults(
              results: _results,
              provider: provider,
              onPlay: (v) => provider.playNow(v),
            ),
          const SizedBox(height: 24),
          _QueueSection(provider: provider),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            decoration: const InputDecoration(
              hintText: 'Cari lagu…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: enabled ? onSearch : null,
          icon: const Icon(Icons.search),
          label: const Text('Cari'),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.provider,
    required this.onPlay,
  });

  final List<Video> results;
  final MusicSyncProvider provider;
  final ValueChanged<Video> onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Hasil', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...results.map(
          (video) => ListTile(
            dense: true,
            leading: video.thumbnail.isEmpty
                ? const Icon(Icons.music_video)
                : Image.network(video.thumbnail, width: 64, height: 36, fit: BoxFit.cover),
            title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(video.channel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Play',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: provider.connected ? () => onPlay(video) : null,
                ),
                IconButton(
                  tooltip: 'Tambah ke queue',
                  icon: const Icon(Icons.add),
                  onPressed: provider.connected ? () => provider.addToQueue(video) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QueueSection extends StatelessWidget {
  const _QueueSection({required this.provider});

  final MusicSyncProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = provider.queue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Queue', style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text('(${queue.length})', style: theme.textTheme.bodySmall),
            const Spacer(),
            if (queue.isNotEmpty)
              TextButton(
                onPressed: provider.connected ? provider.clearQueue : null,
                child: const Text('Clear'),
              ),
          ],
        ),
        if (queue.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Queue masih kosong 😴', style: theme.textTheme.bodyMedium)),
          )
        else
          ...queue.asMap().entries.map(
                (entry) => ListTile(
                  dense: true,
                  leading: entry.value.thumbnail.isEmpty
                      ? const Icon(Icons.music_video)
                      : Image.network(entry.value.thumbnail, width: 64, height: 36, fit: BoxFit.cover),
                  title: Text(entry.value.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(entry.value.channel),
                  trailing: IconButton(
                    tooltip: 'Hapus dari queue',
                    icon: const Icon(Icons.close),
                    onPressed:
                        provider.connected ? () => provider.removeFromQueue(entry.key) : null,
                  ),
                ),
              ),
      ],
    );
  }
}

class _UsersIndicator extends StatelessWidget {
  const _UsersIndicator({required this.users, required this.connected});

  final List<String> users;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!connected) {
      return const Padding(
        padding: EdgeInsets.only(right: 16),
        child: Icon(Icons.cloud_off),
      );
    }
    final names = users.isEmpty ? 'Sendirian' : users.join(', ');
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text('${users.length} online · $names', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

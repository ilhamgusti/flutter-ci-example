import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-launch screen: user enters their name (persisted locally, same key
/// as the web client's `musicSyncName`).
class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key, required this.onJoin});

  /// Called with the trimmed name once the user confirms.
  final ValueChanged<String> onJoin;

  static const String storageKey = 'musicSyncName';

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreSavedName();
  }

  Future<void> _restoreSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(NameEntryScreen.storageKey);
    if (saved != null && saved.isNotEmpty) {
      _controller.text = saved;
    }
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(NameEntryScreen.storageKey, name);
    if (!mounted) return;
    widget.onJoin(name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, size: 96, color: Colors.deepPurple),
              const SizedBox(height: 16),
              Text('Music Sync', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Dengarkan bareng, sinkron real-time',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Nama kamu',
                  hintText: 'cth: Ilham',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Gabung'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

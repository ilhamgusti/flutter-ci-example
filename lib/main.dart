import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'providers/music_sync_provider.dart';
import 'screens/main_screen.dart';
import 'screens/name_entry_screen.dart';
import 'services/backend_config.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedName = prefs.getString(NameEntryScreen.storageKey) ?? '';
  runApp(MusicSyncApp(savedName: savedName));
}

class MusicSyncApp extends StatelessWidget {
  const MusicSyncApp({super.key, required this.savedName});

  final String savedName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MusicSyncProvider(
        service: SyncService(
          channel: WebSocketChannel.connect(Uri.parse(BackendConfig.wsUrl)),
        ),
      ),
      child: MaterialApp(
        title: 'Music Sync',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: _Root(savedName: savedName),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({required this.savedName});

  final String savedName;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late String _name = widget.savedName;

  @override
  void initState() {
    super.initState();
    if (_name.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<MusicSyncProvider>().join(_name);
      });
    }
  }

  void _join(String name) {
    _name = name;
    setState(() {});
    context.read<MusicSyncProvider>().join(name);
  }

  @override
  Widget build(BuildContext context) {
    if (_name.isEmpty) {
      return NameEntryScreen(
        onJoin: (name) {
          _join(name);
        },
      );
    }
    return const MainScreen();
  }
}

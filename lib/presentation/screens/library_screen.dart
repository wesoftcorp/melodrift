import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/entities/playlist.dart';
import '../widgets/downloads_list.dart';
import '../widgets/playlists_list.dart';
import '../widgets/history_list.dart';

@RoutePage()
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Create Playlist',
            onPressed: _showCreatePlaylistDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Downloads'),
            Tab(text: 'Playlists'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DownloadsList(),
          PlaylistsList(),
          HistoryList(),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final titleController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'Enter playlist title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                final playlist = Playlist(
                  id: id,
                  title: title,
                  description: 'Custom local playlist',
                  artworkUrl: '',
                  trackCount: 0,
                  songs: const [],
                  isYouTube: false,
                  isLocal: true,
                );
                await ref.read(playlistRepositoryProvider).createPlaylist(playlist);
                setState(() {});
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

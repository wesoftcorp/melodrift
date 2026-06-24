import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/download_task.dart';
import '../../data/repositories/download_repository_impl.dart';

class SongDownloadButton extends ConsumerWidget {
  final Song song;
  final double size;

  const SongDownloadButton({
    required this.song,
    this.size = 24.0,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadTasks = ref.watch(downloadTasksProvider).value ?? [];
    
    DownloadTask? task;
    for (final t in downloadTasks) {
      if (t.songId == song.id) {
        task = t;
        break;
      }
    }

    if (task == null) {
      return IconButton(
        icon: Icon(Icons.download_outlined, size: size),
        tooltip: 'Download song',
        onPressed: () {
          ref.read(downloadRepositoryProvider).downloadSong(song);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Starting download for "${song.title}"'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
    }

    switch (task.status) {
      case DownloadStatus.pending:
      case DownloadStatus.downloading:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size + 8,
              height: size + 8,
              child: CircularProgressIndicator(
                value: task.progress > 0.0 ? task.progress : null,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: size - 4),
              tooltip: 'Cancel download',
              onPressed: () {
                ref.read(downloadRepositoryProvider).cancelDownload(song.id);
              },
            ),
          ],
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: Icon(Icons.download_done, color: Colors.green, size: size),
          tooltip: 'Downloaded (Tap to delete)',
          onPressed: () => _showDeleteConfirmDialog(context, ref),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: Icon(Icons.error_outline, color: theme.colorScheme.error, size: size),
          tooltip: 'Download failed. Tap to retry.',
          onPressed: () {
            ref.read(downloadRepositoryProvider).downloadSong(song);
          },
        );
      case DownloadStatus.paused:
        return IconButton(
          icon: Icon(Icons.play_arrow, size: size),
          tooltip: 'Resume download',
          onPressed: () {
            ref.read(downloadRepositoryProvider).resumeDownload(song.id);
          },
        );
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${song.title}" from your offline downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(downloadRepositoryProvider).deleteDownload(song.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/download_task.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/services/share_service_impl.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../providers/player_notifier.dart';

/// Shows the redesigned, modern pill-shape grid box song options modal bottom sheet.
void showSongOptionsMenu(BuildContext context, WidgetRef ref, Song song, {VoidCallback? onPlay}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SongOptionsSheet(
      song: song,
      onPlay: onPlay,
    ),
  );
}

class SongOptionsSheet extends ConsumerWidget {
  final Song song;
  final VoidCallback? onPlay;

  const SongOptionsSheet({
    required this.song,
    this.onPlay,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final downloadTasks = ref.watch(downloadTasksProvider).value ?? [];
    DownloadTask? task;
    for (final t in downloadTasks) {
      if (t.songId == song.id) {
        task = t;
        break;
      }
    }

    final sheetBg = isDark
        ? const Color(0xFF141923).withOpacity(0.96)
        : theme.colorScheme.surface.withOpacity(0.96);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag Handle ──────────────────────────────────────────
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // ── Header: Artwork + Metadata ───────────────────────────
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: song.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.artworkUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 56,
                                  height: 56,
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.music_note),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Source Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: getSongSourceColor(song.source).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: getSongSourceColor(song.source).withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: getSongSourceColor(song.source),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        song.source,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: getSongSourceColor(song.source),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (song.duration > Duration.zero) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '•  ${_formatDuration(song.duration)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                  const SizedBox(height: 20),

                  // ── Pill-Shaped Grid Box for All Options ─────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.6,
                        children: [
                          // 1. Play Now
                          _buildPillOption(
                            context: context,
                            icon: Icons.play_arrow_rounded,
                            iconColor: theme.colorScheme.primary,
                            title: 'Play Now',
                            subtitle: 'Listen immediately',
                            onTap: () {
                              Navigator.pop(context);
                              if (onPlay != null) {
                                onPlay!();
                              } else {
                                ref.read(playerStateProvider.notifier).playSong(song);
                              }
                            },
                          ),

                          // 2. Download (Dynamic Pill)
                          _buildDownloadPill(context, ref, task),

                          // 3. Add to Playlist
                          _buildPillOption(
                            context: context,
                            icon: Icons.playlist_add_rounded,
                            iconColor: const Color(0xFFFF9F0A),
                            title: 'Add to Playlist',
                            subtitle: 'Save to library',
                            onTap: () {
                              Navigator.pop(context);
                              showAddToPlaylistDialog(context, ref, song);
                            },
                          ),

                          // 4. Song Info
                          _buildPillOption(
                            context: context,
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF64D2FF),
                            title: 'Song Info',
                            subtitle: 'Audio & metadata',
                            onTap: () {
                              Navigator.pop(context);
                              showSongInfoDialog(context, song);
                            },
                          ),

                          // 5. Start Radio
                          _buildPillOption(
                            context: context,
                            icon: Icons.radio_rounded,
                            iconColor: const Color(0xFFBF5AF2),
                            title: 'Start Radio',
                            subtitle: 'Related tracks mix',
                            onTap: () async {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Starting radio for "${song.title}"...'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              try {
                                final related = await ref.read(musicRepositoryProvider).getRelatedSongs(song.id);
                                if (related.isNotEmpty) {
                                  await ref.read(playerStateProvider.notifier).playQueue([song, ...related]);
                                } else {
                                  await ref.read(playerStateProvider.notifier).playSong(song);
                                }
                              } catch (_) {
                                await ref.read(playerStateProvider.notifier).playSong(song);
                              }
                            },
                          ),

                          // 6. Play Next
                          _buildPillOption(
                            context: context,
                            icon: Icons.queue_music_rounded,
                            iconColor: const Color(0xFF30D158),
                            title: 'Play Next',
                            subtitle: 'Next in queue',
                            onTap: () {
                              Navigator.pop(context);
                              ref.read(playerStateProvider.notifier).playNext(song);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Playing "${song.title}" next'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),

                          // 7. Add to Queue
                          _buildPillOption(
                            context: context,
                            icon: Icons.playlist_add_check_rounded,
                            iconColor: const Color(0xFFFF9F0A),
                            title: 'Add to Queue',
                            subtitle: 'Append to end',
                            onTap: () {
                              Navigator.pop(context);
                              ref.read(playerStateProvider.notifier).addToQueue(song);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "${song.title}" to queue'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),

                          // 8. Playback Speed
                          _buildPillOption(
                            context: context,
                            icon: Icons.speed_rounded,
                            iconColor: const Color(0xFFFF453A),
                            title: 'Playback Speed',
                            subtitle: 'Tempo & Pitch',
                            onTap: () {
                              Navigator.pop(context);
                              showSpeedSelectorDialog(context, ref);
                            },
                          ),

                          // 9. Share Song
                          _buildPillOption(
                            context: context,
                            icon: Icons.share_rounded,
                            iconColor: const Color(0xFF5E5CE6),
                            title: 'Share Song',
                            subtitle: 'Send link to friends',
                            onTap: () {
                              Navigator.pop(context);
                              ref.read(shareServiceProvider).shareSong(
                                title: song.title,
                                artist: song.artist,
                                songId: song.id,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? customIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pillBg = isDark
        ? const Color(0xFF1E2638).withOpacity(0.7)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : theme.colorScheme.outlineVariant.withOpacity(0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: customIcon ?? Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadPill(BuildContext context, WidgetRef ref, DownloadTask? task) {
    if (task == null) {
      return _buildPillOption(
        context: context,
        icon: Icons.download_rounded,
        iconColor: const Color(0xFF0A84FF),
        title: 'Download',
        subtitle: 'Listen offline',
        onTap: () async {
          Navigator.pop(context);
          try {
            await ref.read(downloadRepositoryProvider).downloadSong(song);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Starting download for "${song.title}"'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', '')),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        },
      );
    }

    switch (task.status) {
      case DownloadStatus.pending:
      case DownloadStatus.downloading:
        final progressPct = (task.progress * 100).toInt();
        return _buildPillOption(
          context: context,
          icon: Icons.downloading_rounded,
          iconColor: const Color(0xFF0A84FF),
          title: progressPct > 0 ? '$progressPct% Done' : 'Downloading...',
          subtitle: 'Tap to cancel',
          customIcon: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: task.progress > 0.0 ? task.progress : null,
              strokeWidth: 2.2,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
            ),
          ),
          onTap: () {
            ref.read(downloadRepositoryProvider).cancelDownload(song.id);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download cancelled')),
            );
          },
        );

      case DownloadStatus.completed:
        return _buildPillOption(
          context: context,
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF30D158),
          title: 'Downloaded',
          subtitle: 'Tap to remove',
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmDialog(context, ref);
          },
        );

      case DownloadStatus.failed:
        return _buildPillOption(
          context: context,
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          title: 'Download Failed',
          subtitle: 'Tap to retry',
          onTap: () async {
            Navigator.pop(context);
            try {
              await ref.read(downloadRepositoryProvider).downloadSong(song);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Retrying download for "${song.title}"')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        );

      case DownloadStatus.paused:
        return _buildPillOption(
          context: context,
          icon: Icons.pause_circle_outline_rounded,
          iconColor: Colors.amberAccent,
          title: 'Paused',
          subtitle: 'Tap to resume',
          onTap: () {
            ref.read(downloadRepositoryProvider).resumeDownload(song.id);
            Navigator.pop(context);
          },
        );
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${song.title}" from your offline downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(downloadRepositoryProvider).deleteDownload(song.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

Color getSongSourceColor(String source) {
  switch (source.toLowerCase()) {
    case 'jiosaavn':
      return const Color(0xFF8B5CF6); // JioSaavn Violet
    case 'spotify':
      return const Color(0xFF1DB954); // Spotify Green
    case 'soundcloud':
      return const Color(0xFFFF5500); // SoundCloud Orange
    default:
      return const Color(0xFF8B5CF6);
  }
}



void showAddToPlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
  final playlistRepo = ref.read(playlistRepositoryProvider);
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add to Playlist'),
        content: FutureBuilder<List<Playlist>>(
          future: playlistRepo.getPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            final playlists = snapshot.data ?? [];
            if (playlists.isEmpty) {
              return const Text('No playlists found. Create one in the Library tab.');
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final pl = playlists[index];
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.playlist_play, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${pl.trackCount} tracks'),
                    onTap: () async {
                      await playlistRepo.addSongToPlaylist(pl.id, song);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to ${pl.title}')),
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

void showSongInfoDialog(BuildContext context, Song song) {
  final theme = Theme.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Song Details', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Title', song.title, theme),
            const SizedBox(height: 10),
            _buildInfoRow('Artist', song.artist, theme),
            const SizedBox(height: 10),
            _buildInfoRow('Album', song.album.isNotEmpty ? song.album : 'Single / Independent Track', theme),
            const SizedBox(height: 10),
            _buildInfoRow('Source Provider', song.source, theme),
            if (song.duration > Duration.zero) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                'Duration',
                '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')} min',
                theme,
              ),
            ],
            const SizedBox(height: 10),
            _buildInfoRow('Track ID', song.id, theme),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

Widget _buildInfoRow(String label, String value, ThemeData theme) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    ],
  );
}

/// Modal bottom sheet to quickly toggle playback speed presets (0.5x to 2.0x).
void showSpeedSelectorDialog(BuildContext context, WidgetRef ref) {
  final currentSpeed = ref.read(playerStateProvider).speed;
  final theme = Theme.of(context);
  final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Playback Speed',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: speeds.map((s) {
                    final isSelected = (currentSpeed - s).abs() < 0.05;
                    return ChoiceChip(
                      label: Text(s == 1.0 ? '1.0x (Normal)' : '${s}x'),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(playerStateProvider.notifier).setSpeed(s);
                          Navigator.pop(ctx);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ),
  );
}

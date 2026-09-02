import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/mood_category.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../providers/player_notifier.dart';
import 'song_card.dart';


/// A single mood/genre pill tile with a gradient background.
class MoodCard extends ConsumerWidget {
  final MoodCategory mood;
 
  const MoodCard({
    required this.mood,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Curated vibrant contrast colors (excluding warm ambers/reds/oranges)
    final List<Color> accentColors = [
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.indigo,
      Colors.cyan,
      Colors.green,
    ];
    final accentColor = accentColors[mood.title.hashCode.abs() % accentColors.length];

    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (context) => _MoodSongsDialog(mood: mood),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark 
              ? theme.colorScheme.surfaceContainerHigh 
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark 
                ? accentColor.withOpacity(0.3) 
                : accentColor.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.3) 
                  : Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              mood.title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFFFF5F1F),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single horizontally scrollable row of mood/genre tiles.
class HorizontalMoodRow extends StatefulWidget {
  final List<MoodCategory> moods;

  const HorizontalMoodRow({required this.moods, super.key});

  @override
  State<HorizontalMoodRow> createState() => _HorizontalMoodRowState();
}

class _HorizontalMoodRowState extends State<HorizontalMoodRow> {
  late List<MoodCategory> _moods;

  @override
  void initState() {
    super.initState();
    _moods = List<MoodCategory>.from(widget.moods);
  }

  @override
  void didUpdateWidget(HorizontalMoodRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if parent feed reloads with a completely different list
    if (oldWidget.moods != widget.moods) {
      _moods = List<MoodCategory>.from(widget.moods);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _moods.removeAt(oldIndex);
      _moods.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        proxyDecorator: (child, index, animation) => ScaleTransition(
          scale: Tween<double>(begin: 1, end: 1.06).animate(animation),
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: child,
          ),
        ),
        onReorder: _onReorder,
        itemCount: _moods.length,
        itemBuilder: (context, index) {
          final mood = _moods[index];
          return Padding(
            key: ValueKey(mood.id),
            padding: const EdgeInsets.only(right: 8),
            child: ReorderableDelayedDragStartListener(
              index: index,
              child: SizedBox(
                width: 110,
                height: 48,
                child: MoodCard(mood: mood),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoodSongsDialog extends ConsumerStatefulWidget {
  final MoodCategory mood;

  const _MoodSongsDialog({required this.mood});

  @override
  ConsumerState<_MoodSongsDialog> createState() => _MoodSongsDialogState();
}

class _MoodSongsDialogState extends ConsumerState<_MoodSongsDialog> {
  late Future<List<Song>> _futureSongs;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(musicRepositoryProvider);
    _futureSongs = repo.getMoodCategorySongs(widget.mood.id, widget.mood.title, limit: 100);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentSongId = ref.watch(playerStateProvider.select((s) => s.currentSong?.id));
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      backgroundColor: isDark 
          ? const Color(0xFF16161E) 
          : theme.colorScheme.surfaceContainerLowest,
      elevation: 24,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 480,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5F1F).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFFFF5F1F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mood.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF5F1F),
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Curated Songs & Hits',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07),
            ),
            const SizedBox(height: 12),
            
            // Songs list / Loading
            Expanded(
              child: FutureBuilder<List<Song>>(
                future: _futureSongs,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F1F)),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load songs: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final songs = snapshot.data ?? [];
                  if (songs.isEmpty) {
                    return const Center(child: Text('No songs found for this mood'));
                  }

                  return Column(
                    children: [
                      // Play All Header Button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ref.read(playerStateProvider.notifier).playQueue(songs);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5F1F),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: Text(
                              'Play All (${songs.length} Tracks)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      
                      // Aesthetic Songs List
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            final isCurrent = currentSongId == song.id ||
                                (currentSongId != null &&
                                    (currentSongId.endsWith(song.id) || song.id.endsWith(currentSongId)));
                            final isCurrentlyPlaying = isCurrent && isPlaying;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFFF5F1F).withOpacity(0.12)
                                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFFFF5F1F).withOpacity(0.4)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    ref.read(playerStateProvider.notifier).playQueue(songs, initialIndex: index);
                                    Navigator.of(context).pop();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        // Artwork with active play indicator
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: song.artworkUrl.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: song.artworkUrl,
                                                      width: 46,
                                                      height: 46,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) => Container(
                                                        width: 46,
                                                        height: 46,
                                                        color: theme.colorScheme.surfaceContainerHighest,
                                                        child: const Icon(Icons.music_note, size: 20),
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 46,
                                                      height: 46,
                                                      color: theme.colorScheme.surfaceContainerHighest,
                                                      child: const Icon(Icons.music_note, size: 20),
                                                    ),
                                            ),
                                            if (isCurrentlyPlaying)
                                              Container(
                                                width: 46,
                                                height: 46,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.4),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.equalizer_rounded,
                                                  color: Color(0xFFFF5F1F),
                                                  size: 24,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        // Title & Artist
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                song.title,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                                  color: isCurrent ? const Color(0xFFFF5F1F) : theme.colorScheme.onSurface,
                                                  fontSize: 13.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                song.artist,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                  fontSize: 11.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Duration
                                        if (song.duration > Duration.zero) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDuration(song.duration),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurface.withOpacity(0.45),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        // Three dots menu (Play option inside)
                                        IconButton(
                                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                          splashRadius: 20,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => showSongOptionsMenu(context, ref, song),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    _futureSongs = repo.searchSongs('${widget.mood.title} music');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark 
          ? theme.colorScheme.surfaceContainerHigh 
          : theme.colorScheme.surfaceContainerLowest,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 450,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.mood.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF5F1F),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: theme.colorScheme.onSurface,
                ),
              ],
            ),
            const Divider(),
            
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
                      // Play All button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ref.read(playerStateProvider.notifier).playQueue(songs);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5F1F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play All'),
                          ),
                        ),
                      ),
                      
                      // List
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: song.artworkUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: song.artworkUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        child: const Icon(Icons.music_note),
                                      ),
                              ),
                              title: Text(
                                song.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_circle_outline,
                                      color: Color(0xFFFF5F1F),
                                    ),
                                    onPressed: () {
                                      ref.read(playerStateProvider.notifier).playSong(song);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () => showSongOptionsMenu(context, ref, song),
                                  ),
                                ],
                              ),
                              onTap: () {
                                ref.read(playerStateProvider.notifier).playSong(song);
                                Navigator.of(context).pop();
                              },
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

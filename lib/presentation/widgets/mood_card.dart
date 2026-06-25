import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '../../domain/entities/mood_category.dart';
import '../../app/router/app_router.gr.dart';

/// A single mood/genre pill tile with a gradient background.
class MoodCard extends StatelessWidget {
  final MoodCategory mood;

  const MoodCard({
    required this.mood,
    super.key,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Indigo/Violet
    [Color(0xFFf12711), Color(0xFFf5af19)], // Sunset orange
    [Color(0xFF11998e), Color(0xFF38ef7d)], // Emerald
    [Color(0xFFFF007F), Color(0xFF7F00FF)], // Neon Pink/Purple
    [Color(0xFF00c6ff), Color(0xFF0072ff)], // Sky Blue
    [Color(0xFFfc4a1a), Color(0xFFf7b733)], // Sunrise
    [Color(0xFF1a1a2e), Color(0xFF16213e)], // Midnight
    [Color(0xFF134E5E), Color(0xFF71B280)], // Forest teal
    [Color(0xFFe96c1e), Color(0xFFFFCE54)], // Mango
    [Color(0xFF833ab4), Color(0xFFfd1d1d)], // Neon sunset
    [Color(0xFF005C97), Color(0xFF363795)], // Deep ocean
    [Color(0xFF56ab2f), Color(0xFFa8e063)], // Lime green
  ];

  @override
  Widget build(BuildContext context) {
    final gradientIndex = mood.title.hashCode.abs() % _gradients.length;
    final gradientColors = _gradients[gradientIndex];
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        context.router.push(
          DetailsRoute(
            id: mood.id,
            title: mood.title,
            artworkUrl: '',
            type: 'mood',
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              mood.title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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

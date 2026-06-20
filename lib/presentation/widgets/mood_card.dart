import 'package:flutter/material.dart';
import '../../domain/entities/mood_category.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    // Select gradient based on the hash of the mood title
    final gradientIndex = mood.title.hashCode.abs() % _gradients.length;
    final gradientColors = _gradients[gradientIndex];
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            mood.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

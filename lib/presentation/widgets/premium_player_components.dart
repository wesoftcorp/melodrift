import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom-drawn squiggly progress bar that oscillates when playing
/// and flattens into a straight line when paused or scrubbed.
class SquigglySeeker extends StatefulWidget {
  final double progress; // Between 0.0 and 1.0
  final bool isPlaying;
  final ValueChanged<double> onChangeEnd;

  const SquigglySeeker({
    required this.progress,
    required this.isPlaying,
    required this.onChangeEnd,
    super.key,
  });

  @override
  State<SquigglySeeker> createState() => _SquigglySeekerState();
}

class _SquigglySeekerState extends State<SquigglySeeker>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _flattenController;
  double? _dragProgress;

  @override
  void initState() {
    super.initState();
    // Animates the phase of the wave to make it look alive/oscillating
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Controls wave amplitude flattening (0 = flat line, 1 = full wave)
    _flattenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(SquigglySeeker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && _dragProgress == null) {
      _flattenController.animateTo(1.0);
    } else if (!widget.isPlaying) {
      _flattenController.animateTo(0.0);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _flattenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.surfaceVariant;

    final displayProgress = _dragProgress ?? widget.progress;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        _flattenController.animateTo(0.0); // Flatten during drag
        _updateDrag(details.localPosition.dx, context.size?.width ?? 1.0);
      },
      onHorizontalDragUpdate: (details) {
        _updateDrag(details.localPosition.dx, context.size?.width ?? 1.0);
      },
      onHorizontalDragEnd: (details) {
        if (_dragProgress != null) {
          widget.onChangeEnd(_dragProgress!);
          _dragProgress = null;
        }
        if (widget.isPlaying) {
          _flattenController.animateTo(1.0); // Restore wave if playing
        }
      },
      onTapDown: (details) {
        _flattenController.animateTo(0.0);
        _updateDrag(details.localPosition.dx, context.size?.width ?? 1.0);
      },
      onTapUp: (details) {
        if (_dragProgress != null) {
          widget.onChangeEnd(_dragProgress!);
          _dragProgress = null;
        }
        if (widget.isPlaying) {
          _flattenController.animateTo(1.0);
        }
      },
      child: Container(
        height: 32,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: Listenable.merge([_waveController, _flattenController]),
          builder: (context, child) {
            return CustomPaint(
              size: const Size(double.infinity, 32),
              painter: _SquigglyPainter(
                progress: displayProgress,
                phase: _waveController.value * 2 * math.pi,
                flattenFactor: _flattenController.value,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            );
          },
        ),
      ),
    );
  }

  void _updateDrag(double localX, double width) {
    setState(() {
      _dragProgress = (localX / width).clamp(0.0, 1.0);
    });
  }
}

class _SquigglyPainter extends CustomPainter {
  final double progress;
  final double phase;
  final double flattenFactor;
  final Color activeColor;
  final Color inactiveColor;

  _SquigglyPainter({
    required this.progress,
    required this.phase,
    required this.flattenFactor,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final width = size.width;
    final progressX = width * progress;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Draw Active (left) squiggly wave
    if (progressX > 0) {
      final activePath = _buildSquigglyPath(0, progressX, centerY, true);
      canvas.drawPath(activePath, activePaint);
    }

    // Draw Inactive (right) squiggly wave (or flat/lower amplitude wave)
    if (progressX < width) {
      final inactivePath = _buildSquigglyPath(progressX, width, centerY, false);
      canvas.drawPath(inactivePath, inactivePaint);
    }

    // Draw Playhead handle
    final handlePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(progressX, centerY), 6.0, handlePaint);
  }

  Path _buildSquigglyPath(double startX, double endX, double centerY, bool isActive) {
    final path = Path();
    if (startX >= endX) return path;

    path.moveTo(startX, centerY);

    // Wave config
    const wavelength = 40.0;
    final amplitude = isActive ? (6.0 * flattenFactor) : (3.0 * flattenFactor);

    if (flattenFactor < 0.05) {
      // Just draw a simple straight line if completely flat
      path.lineTo(endX, centerY);
      return path;
    }

    double x = startX;
    while (x < endX) {
      double nextX = x + 5.0;
      if (nextX > endX) nextX = endX;

      // Calculate y based on sine wave with moving phase
      final currentPhase = phase + (x / wavelength) * 2 * math.pi;
      final y = centerY + math.sin(currentPhase) * amplitude;

      path.lineTo(nextX, y);
      x = nextX;
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _SquigglyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.flattenFactor != flattenFactor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

/// A 72dp Circular button that morphs into a star shape when active (playing),
/// and spins infinitely (360° every 8 seconds) while playing.
class MorphingPlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  const MorphingPlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    super.key,
  });

  @override
  State<MorphingPlayButton> createState() => _MorphingPlayButtonState();
}

class _MorphingPlayButtonState extends State<MorphingPlayButton>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _morphController;

  @override
  void initState() {
    super.initState();
    // Spins infinitely when playing
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // Morphs shape between circle (0) and star (1)
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _syncStates();
  }

  @override
  void didUpdateWidget(MorphingPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncStates();
  }

  void _syncStates() {
    if (widget.isPlaying) {
      _rotationController.repeat();
      _morphController.forward();
    } else {
      _rotationController.stop();
      _morphController.reverse();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final onActiveColor = theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: widget.onTap,
      child: RotationTransition(
        turns: _rotationController,
        child: AnimatedBuilder(
          animation: _morphController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(72, 72),
              painter: _StarMorphPainter(
                morphFactor: _morphController.value,
                color: activeColor,
              ),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(onActiveColor),
                          ),
                        )
                      : Icon(
                          widget.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 36,
                          color: onActiveColor,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StarMorphPainter extends CustomPainter {
  final double morphFactor;
  final Color color;

  _StarMorphPainter({required this.morphFactor, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Define star polygon points relative to center (8 main outer tips, 8 inner indentations)
    // Same as the CSS clip-path: polygon(50% 0%, 65% 15%, 85% 15%, 85% 35%, 100% 50%, ...)
    final path = Path();
    final List<Offset> starPoints = [];

    // The CSS polygon has 16 points. Let's map them to polar coordinates.
    // 50% 0% is top-center.
    final pointsPercentage = [
      const Offset(0.5, 0.0),   // 1
      const Offset(0.65, 0.15), // 2
      const Offset(0.85, 0.15), // 3
      const Offset(0.85, 0.35), // 4
      const Offset(1.0, 0.5),   // 5
      const Offset(0.85, 0.65), // 6
      const Offset(0.85, 0.85), // 7
      const Offset(0.65, 0.85), // 8
      const Offset(0.5, 1.0),   // 9
      const Offset(0.35, 0.85), // 10
      const Offset(0.15, 0.85), // 11
      const Offset(0.15, 0.65), // 12
      const Offset(0.0, 0.5),   // 13
      const Offset(0.15, 0.35), // 14
      const Offset(0.15, 0.15), // 15
      const Offset(0.35, 0.15), // 16
    ];

    for (final pct in pointsPercentage) {
      // Map percentage to actual pixel coordinates
      final targetX = pct.dx * size.width;
      final targetY = pct.dy * size.height;
      final targetPoint = Offset(targetX, targetY);

      // Map equivalent circular point (projecting to outer boundary)
      final vector = targetPoint - center;
      final angle = math.atan2(vector.dy, vector.dx);
      final circlePoint = center + Offset(math.cos(angle) * maxRadius, math.sin(angle) * maxRadius);

      // Interpolate based on morphFactor (0 = circle, 1 = star)
      final lerpPoint = Offset.lerp(circlePoint, targetPoint, morphFactor)!;
      starPoints.add(lerpPoint);
    }

    path.moveTo(starPoints[0].dx, starPoints[0].dy);
    for (int i = 1; i < starPoints.length; i++) {
      path.lineTo(starPoints[i].dx, starPoints[i].dy);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarMorphPainter oldDelegate) {
    return oldDelegate.morphFactor != morphFactor || oldDelegate.color != color;
  }
}

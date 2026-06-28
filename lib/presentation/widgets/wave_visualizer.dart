import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final Color? color;

  const WaveVisualizer({
    required this.isPlaying,
    super.key,
    this.height = 100,
    this.color,
  });

  @override
  State<WaveVisualizer> createState() => _WaveVisualizerState();
}

class _WaveVisualizerState extends State<WaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(WaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.duration = const Duration(seconds: 2);
        _controller.repeat();
      } else {
        _controller.duration = const Duration(seconds: 8);
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waveColor = widget.color ?? theme.colorScheme.primary;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(
              animationValue: _controller.value,
              isPlaying: widget.isPlaying,
              color: waveColor,
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final Color color;

  _WavePainter({
    required this.animationValue,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final midY = height / 2;
    
    // Target amplitude is higher when playing, lower when paused
    final targetAmplitude = isPlaying ? height * 0.4 : height * 0.1;

    void drawWave(double phaseOffset, double amplitudeMult, double opacity, double freqMult) {
      final path = Path();
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      path.moveTo(0, midY);

      for (double x = 0; x <= width; x++) {
        // Normalize x from 0 to 2*PI
        final normalizedX = (x / width) * 2 * math.pi * freqMult;
        // Calculate Y using sine with animation and phase offset
        final y = midY + math.sin(normalizedX + (animationValue * 2 * math.pi) + phaseOffset) * (targetAmplitude * amplitudeMult);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }

    // Draw 4 layers of waves
    drawWave(0, 1.0, 0.8, 1.0); // Front wave
    drawWave(math.pi * 0.5, 0.7, 0.5, 1.2); // Mid wave 1
    drawWave(math.pi * 1.0, 0.5, 0.3, 1.5); // Mid wave 2
    drawWave(math.pi * 1.5, 0.3, 0.1, 0.8); // Back wave
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color;
  }
}

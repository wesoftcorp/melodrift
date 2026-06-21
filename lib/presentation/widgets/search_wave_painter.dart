import 'dart:math';
import 'package:flutter/material.dart';

class SearchWavePainter extends CustomPainter {
  final double amplitude;
  SearchWavePainter(this.amplitude);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurpleAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final mid = size.height / 2;
    path.moveTo(0, mid);
    for (double x = 0; x <= size.width; x++) {
      final y = mid + sin(x * 0.05) * amplitude * 40 * sin(x * 0.01);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SearchWavePainter oldDelegate) =>
      oldDelegate.amplitude != amplitude;
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A wrapper widget that translates vertical mouse-wheel scroll inputs
/// into horizontal scrolling for its child scrollable.
class HorizontalMouseScroll extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;

  const HorizontalMouseScroll({
    required this.builder,
    super.key,
  });

  @override
  State<HorizontalMouseScroll> createState() => _HorizontalMouseScrollState();
}

class _HorizontalMouseScrollState extends State<HorizontalMouseScroll> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final double delta = pointerSignal.scrollDelta.dy != 0
              ? pointerSignal.scrollDelta.dy
              : pointerSignal.scrollDelta.dx;
          if (delta != 0 && _controller.hasClients) {
            final double newOffset = _controller.offset + delta;
            _controller.jumpTo(
              newOffset.clamp(0.0, _controller.position.maxScrollExtent),
            );
          }
        }
      },
      child: widget.builder(context, _controller),
    );
  }
}

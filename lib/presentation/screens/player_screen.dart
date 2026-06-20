import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Player Screen')),
    );
  }
}

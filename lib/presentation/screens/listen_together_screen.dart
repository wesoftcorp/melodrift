import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class ListenTogetherScreen extends StatelessWidget {
  const ListenTogetherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Listen Together Screen')),
    );
  }
}

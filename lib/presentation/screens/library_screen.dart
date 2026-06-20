import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Library Screen')),
    );
  }
}

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  ConnectivityService() {
    _init();
  }

  void _init() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final bool isOnline = result != ConnectivityResult.none;
      _controller.add(isOnline);
    });
  }

  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<bool> get isOnline async {
    final ConnectivityResult result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}

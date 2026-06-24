import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enum representing network connectivity state
enum ConnectivityState {
  online,      // Has internet connection
  offline,     // No internet connection
  unknown,     // Unknown state (checking)
}

/// Provider for current network connectivity state
/// 
/// Returns a stream of connectivity changes. Usage:
/// ```dart
/// final connectivity = ref.watch(connectivityProvider);
/// connectivity.when(
///   data: (state) => Text('Status: ${state.name}'),
///   loading: () => Text('Checking...'),
///   error: (err, st) => Text('Error: $err'),
/// );
/// ```
final connectivityProvider = StreamProvider<ConnectivityState>((ref) async* {
  final connectivity = Connectivity();
  
  // Yield initial state
  final result = await connectivity.checkConnectivity();
  yield _mapConnectivityResult(result);
  
  // Listen to connectivity changes
  await for (final result in connectivity.onConnectivityChanged) {
    yield _mapConnectivityResult(result);
  }
});

/// Map ConnectivityResult to our ConnectivityState enum
ConnectivityState _mapConnectivityResult(ConnectivityResult result) {
  switch (result) {
    case ConnectivityResult.mobile:
    case ConnectivityResult.wifi:
    case ConnectivityResult.ethernet:
    case ConnectivityResult.vpn:
      return ConnectivityState.online;
    case ConnectivityResult.none:
      return ConnectivityState.offline;
    case ConnectivityResult.other:
      return ConnectivityState.unknown;
    case ConnectivityResult.bluetooth:
      return ConnectivityState.unknown;
  }
}

/// Derived provider: Is device currently online?
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityState = ref.watch(connectivityProvider);
  
  return connectivityState.when(
    data: (state) => state == ConnectivityState.online,
    loading: () => true, // Assume online while checking
    error: (_, __) => false, // Assume offline on error
  );
});

/// Derived provider: Is device currently offline?
final isOfflineProvider = Provider<bool>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  return !isOnline;
});

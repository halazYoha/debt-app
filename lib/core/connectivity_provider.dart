import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the device has internet, `false` when offline.
/// Uses connectivity_plus to watch real-time network changes.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map((results) {
    // onConnectivityChanged emits a List<ConnectivityResult>
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  });
});

/// Snapshot of the current connectivity status (non-streaming helper).
/// Returns true if online, false if offline or status unknown.
bool isOnline(AsyncValue<bool> connectivityValue) {
  return connectivityValue.value ?? true;
}

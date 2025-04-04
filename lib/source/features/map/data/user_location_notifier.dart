import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, Position?>((ref) {
  return UserLocationNotifier();
});

class UserLocationNotifier extends StateNotifier<Position?> {
  UserLocationNotifier() : super(null) {
    _getCurrentLocation(); // Initialize tracking
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;

    // ✅ Check if GPS is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("❌ GPS is disabled.");
      return;
    }

    // ✅ Listen to live location updates
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      print(
          "📍 User Location Updated: ${position.latitude}, ${position.longitude}");
      state = position; // Update provider state
    });
  }
}

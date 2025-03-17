import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/map/data/active_button_notifier.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';

/// 🎯 CameraState model
class CameraState {
  final mp.CameraOptions cameraOptions;
  final String mode; // "none", "latestPoint", "ownPosition"

  CameraState({required this.cameraOptions, this.mode = "none"});

  CameraState copyWith({mp.CameraOptions? cameraOptions, String? mode}) {
    return CameraState(
      cameraOptions: cameraOptions ?? this.cameraOptions,
      mode: mode ?? this.mode,
    );
  }
}

class CameraPositionNotifier extends StateNotifier<CameraState> {
  final Ref ref;
  bool hasMovedToLatestPoint = false; // 📌
  StreamSubscription<gl.Position>? userPositionStream;

  CameraPositionNotifier(this.ref)
      : super(CameraState(
          cameraOptions: _createCameraOptions(lat: 38.7993, lng: -122.8469),
          mode: 'none',
        )) {
    _listenToDataUpdates();
    _listenToUserLocation();
  }

  void flyToLocation(double longitude, double latitude) {
    final newPosition = _createCameraOptions(lat: latitude, lng: longitude);
    state = state.copyWith(cameraOptions: newPosition);
    _mapboxMapController?.flyTo(
        newPosition, mp.MapAnimationOptions(duration: 2000));

    // Deactivate tracking modes
    state = state.copyWith(mode: 'none');
    // Update active button state
    ref.read(activeButtonProvider.notifier).setActiveButton('none');
  }

  /// ✅ **Manually initialize camera position (Called from `initState()`)**
  /// ✅ **Initialize camera once data is available**
  void initializeCamera() {
    final latestPoint = ref.read(latestDataPointProvider);

    if (latestPoint != null) {
      print("📍 Initializing camera to latest data point.");
      _flyToLocation(
        double.tryParse(latestPoint.dataLong ?? '-122.8469') ?? -122.8469,
        double.tryParse(latestPoint.dataLat ?? '38.7993') ?? 38.7993,
      );
    } else {
      print("🟢 Waiting for data before setting initial camera...");
      _waitForDataAndSetCamera();
    }
  }

  /// ✅ **Wait until `latestDataPointProvider` has data**
  void _waitForDataAndSetCamera() {
    ref.listen<FluxData?>(latestDataPointProvider, (prev, latestPoint) {
      if (latestPoint != null && !hasMovedToLatestPoint) {
        // Check if the camera hasn't been set yet
        print("✅ Data is available! Setting camera to latest point...");
        _flyToLocation(
          double.tryParse(latestPoint.dataLong ?? '-122.8469') ?? -122.8469,
          double.tryParse(latestPoint.dataLat ?? '38.7993') ?? 38.7993,
        );

        // Set flag to true so the camera won't move again
        hasMovedToLatestPoint = true;

        // Deactivate tracking after flying to the latest point
        state = state.copyWith(mode: 'none');
        ref.read(activeButtonProvider.notifier).setActiveButton('none');
      }
    });
  }

  void _listenToDataUpdates() {
    ref.listen<FluxData?>(latestDataPointProvider, (prev, latestPoint) {
      if (state.mode == "latestPoint" && latestPoint != null) {
        _flyToLocation(
          double.tryParse(latestPoint.dataLong ?? '-122.8469') ?? -122.8469,
          double.tryParse(latestPoint.dataLat ?? '38.7993') ?? 38.7993,
        );
      }
    });
  }

  void _listenToUserLocation() {
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((gl.Position? position) {
      if (state.mode == "ownPosition" && position != null) {
        _flyToLocation(position.longitude, position.latitude);
      }
    });
  }

  /// 🚀 Move the camera to a specified location smoothly
  void _flyToLocation(double longitude, double latitude) {
    final newPosition = _createCameraOptions(lat: latitude, lng: longitude);
    state = state.copyWith(cameraOptions: newPosition);
    _mapboxMapController?.flyTo(
        newPosition, mp.MapAnimationOptions(duration: 2000));
  }

  /// **📌 Toggle camera mode**
  void toggleCameraMode(String mode) {
    if (state.mode == mode) {
      state = state.copyWith(mode: "none");
      print("🛑 Camera tracking disabled.");
      return;
    }

    state = state.copyWith(mode: mode);
    print("🔄 Camera mode set to: ${state.mode}");

    if (mode == "latestPoint") {
      final latestPoint = ref.read(latestDataPointProvider);
      if (latestPoint != null) {
        _flyToLocation(
          double.tryParse(latestPoint.dataLong ?? '-122.8469') ?? -122.8469,
          double.tryParse(latestPoint.dataLat ?? '38.7993') ?? 38.7993,
        );
      }
    } else if (mode == "ownPosition") {
      _moveToOwnPosition();
    }
  }

  /// **Go to the User's Current GPS Position**
  Future<void> _moveToOwnPosition() async {
    try {
      final position = await gl.Geolocator.getCurrentPosition();
      _flyToLocation(position.longitude, position.latitude);
    } catch (e) {
      print("❌ Error getting user position: $e");
    }
  }

  /// ✅ Helper function to create camera options
  static mp.CameraOptions _createCameraOptions({
    required double lat,
    required double lng,
  }) {
    return mp.CameraOptions(
      center: mp.Point(coordinates: mp.Position(lng, lat)),
      zoom: 13,
    );
  }

  mp.MapboxMap? get _mapboxMapController =>
      ref.read(heatmapProvider.notifier).getMapboxController();
}

/// 📌 **Register Provider for CameraPositionNotifier**
final cameraPositionProvider =
    StateNotifierProvider<CameraPositionNotifier, CameraState>(
  (ref) => CameraPositionNotifier(ref),
);

/// **📌 Get the latest data point**
final latestDataPointProvider = Provider<FluxData?>((ref) {
  final dataList = ref.watch(fluxDataListProvider).maybeWhen(
        data: (data) => List.from(data),
        orElse: () => [],
      );

  return dataList.isNotEmpty ? dataList.last : null;
});

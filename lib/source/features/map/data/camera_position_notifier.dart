import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';

class CameraPositionNotifier extends StateNotifier<mp.CameraOptions> {
  final Ref ref;
  StreamSubscription<gl.Position>? userPositionStream;
  String cameraMode = "none"; // ✅ "latestPoint", "ownPosition", or "none"

  CameraPositionNotifier(this.ref)
      : super(mp.CameraOptions(
          center: mp.Point(
              coordinates: mp.Position(13.4050, 52.5200)), // Default: Berlin
          zoom: 13,
        )) {
    // ✅ Listen for changes in the latest data point
    ref.listen<FluxData?>(latestDataPointProvider, (prev, latestPoint) {
      if (cameraMode == "latestPoint" && latestPoint != null) {
        _flyToLocation(
          double.tryParse(latestPoint.dataLong ?? '13.4050') ?? 13.4050,
          double.tryParse(latestPoint.dataLat ?? '52.5200') ?? 52.5200,
        );
      }
    });

    // ✅ Listen for changes in the user's position
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((gl.Position? position) {
      if (cameraMode == "ownPosition" && position != null) {
        _flyToLocation(position.longitude, position.latitude);
      }
    });
  }

  /// 🚀 Move the camera to a specified location smoothly
  void _flyToLocation(double longitude, double latitude) {
    final newPosition = mp.CameraOptions(
      center: mp.Point(coordinates: mp.Position(longitude, latitude)),
      zoom: 13,
    );

    state = newPosition;
    _mapboxMapController?.flyTo(
        newPosition, mp.MapAnimationOptions(duration: 2000));
  }

  /// 🎯 **Toggle camera mode** (latest data point, own position, or manual)
  void toggleCameraMode(String mode) {
    if (cameraMode == mode) {
      // ✅ If the same button is tapped again, turn off tracking
      cameraMode = "none";
      print("🛑 Camera tracking disabled.");
    } else {
      // ✅ Enable tracking for the selected mode
      cameraMode = mode;
      print("🔄 Camera mode set to: $cameraMode");

      // ✅ Move to the correct position immediately
      if (mode == "latestPoint") {
        final latestPoint = ref.read(latestDataPointProvider);
        if (latestPoint != null) {
          _flyToLocation(
            double.tryParse(latestPoint.dataLong ?? '13.4050') ?? 13.4050,
            double.tryParse(latestPoint.dataLat ?? '52.5200') ?? 52.5200,
          );
        }
      } else if (mode == "ownPosition") {
        _moveToOwnPosition();
      }
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

  mp.MapboxMap? get _mapboxMapController =>
      ref.read(heatmapProvider.notifier).getMapboxController();
}

/// 📌 **Register Provider for CameraPositionNotifier**
final cameraPositionProvider =
    StateNotifierProvider<CameraPositionNotifier, mp.CameraOptions>(
  (ref) => CameraPositionNotifier(ref),
);

final latestDataPointProvider = Provider<FluxData?>((ref) {
  return ref.watch(fluxDataListProvider).maybeWhen(
        data: (dataList) => dataList.isNotEmpty ? dataList.last : null,
        orElse: () => null,
      );
});

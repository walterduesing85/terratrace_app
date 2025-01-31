import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

final cameraPositionProvider = StateProvider<LatLng>((ref) {
  return LatLng(0, 0); // Initial position
});

final mapControllerProvider =
    StateNotifierProvider<MapControllerNotifier, MapController?>((ref) {
  return MapControllerNotifier(ref);
});

class MapControllerNotifier extends StateNotifier<MapController?> {
  MapControllerNotifier(this.ref) : super(null);

  final Ref ref;

  void setController(MapController controller) {
    state = controller;
  }

  Future<void> moveCamera(LatLng target) async {
    if (state != null) {
      state?.move(
          target,
          state!.camera
              .zoom); // move to the new target without changing the zoom level
      ref.read(cameraPositionProvider) ==
          target; // update the camera position provider
    }
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
}

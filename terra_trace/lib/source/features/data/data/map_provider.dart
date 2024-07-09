//import 'package:google_maps_flutter_heatmap/google_maps_flutter_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// final cameraPositionProvider = StateProvider<CameraPosition>((ref) {
//   return CameraPosition(
//     target: LatLng(0, 0), // Initial position
//     zoom: 14,
//     tilt: 10,
//   );
// });

// final mapControllerProvider =
//     StateNotifierProvider<MapController, GoogleMapController?>((ref) {
//   return MapController();
// });

// final mapControllerProvider2 =
//     StateNotifierProvider<MapController, GoogleMapController?>((ref) {
//   return MapController();
// });

// class MapController extends StateNotifier<GoogleMapController?> {
//   MapController() : super(null);

//   void setController(GoogleMapController controller) {
//     state = controller;
//   }

//   Future<void> moveCamera(LatLng target) async {
//     if (state != null) {
//       await state?.animateCamera(CameraUpdate.newLatLng(target));
//     }
//   }
// }

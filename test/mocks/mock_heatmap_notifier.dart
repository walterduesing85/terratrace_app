import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';

class MockHeatmapNotifier extends HeatmapNotifier {
  MockHeatmapNotifier(Ref ref) : super(ref);

  @override
  Future<void> updateHeatmapLayer(HeatmapLayer layer) async {
    print("🔥 [Mock] updateHeatmapLayer called with $layer");
  }

  @override
  void disposeNotifier() {
    print("🧹 [Mock] disposeNotifier called");
  }

  @override
  void setMapboxController(dynamic controller) {
    print("🗺️ [Mock] setMapboxController called");
  }

  @override
  Future<void> updateHeatmapSource(dynamic data) async {
    print("🟢 [Mock] updateHeatmapSource called");
  }

  @override
  Future<void> updateMarkerLayer() async {
    print("📍 [Mock] updateMarkerLayer called");
  }
}

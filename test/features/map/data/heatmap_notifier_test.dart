import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';


void main() {
  test('HeatmapNotifier does not crash when updating marker layer without map',
      () async {
    final container = ProviderContainer();
    final notifier = container.read(heatmapProvider.notifier);

    // Don't set a mapbox controller, just call the method
    await notifier.updateMarkerLayer();

    // You should see the error log:
    // 🚨 ERROR: MapboxMapController is NULL! Cannot update heatmap.
  });
}

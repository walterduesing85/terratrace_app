import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class MapScreen extends ConsumerStatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;

  @override
  Widget build(
    BuildContext context,
  ) {
    ref.watch(geoJsonProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () {}),
      body: MapWidget(
        styleUri: "mapbox://styles/mapbox/dark-v10",
        onMapCreated: (mapboxMap) => _onMapCreated(mapboxMap, ref),
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap, WidgetRef ref) {
    _mapboxMap = mapboxMap;
    _mapboxMap?.setCamera(
      CameraOptions(
          zoom: 13, center: Point(coordinates: Position(12.46811, 50.20735))),
    );
    _addHeatmapLayer(ref);
  }

  Future<void> _addHeatmapLayer(WidgetRef ref) async {
    try {
      final geoJsonData = ref.watch(geoJsonProvider).maybeWhen(
            data: (data) => data,
            orElse: () => null,
          );

      if (geoJsonData == null ||
          geoJsonData.isEmpty ||
          geoJsonData.contains('"features": []')) {
        Future.delayed(Duration(milliseconds: 500),
            () => _addHeatmapLayer(ref)); // Retry after 1 second
        return;
      }

      await _mapboxMap?.style.addSource(GeoJsonSource(
        id: "heatmap-source",
        data: geoJsonData,
      ));

      await _mapboxMap?.style.addLayer(ref.watch(heatmapProvider));
    } catch (e) {
      print("🚨 Error adding heatmap layer: $e");
    }
  }
}

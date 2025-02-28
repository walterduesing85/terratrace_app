import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'dart:convert';
import 'map_data.dart';

class HeatmapNotifier extends StateNotifier<void> {
  HeatmapNotifier(this.ref) : super(null) {
    // ✅ Listen for changes in map state and update the heatmap
    ref.listen<MapState>(mapStateProvider, (previous, next) {
      if (_shouldUpdate(previous, next)) {
        print("🔥 Map state changed, updating heatmap...");
        updateHeatmap(next);
      }
    });
  }

  final Ref ref;
  mp.MapboxMap? _mapboxMapController;
  Timer? _debounce;

  /// ✅ Returns the Mapbox controller if available
  mp.MapboxMap? getMapboxController() {
    if (_mapboxMapController == null) {
      print("🚨 ERROR: Mapbox controller is null!");
    }
    return _mapboxMapController;
  }

  /// ✅ Prevents unnecessary updates
  bool _shouldUpdate(MapState? prev, MapState next) {
    if (prev == null) return true;
    return prev.radius != next.radius ||
        prev.opacity != next.opacity ||
        prev.rangeValues != next.rangeValues ||
        prev.geoJson != next.geoJson;
  }

  void setMapboxController(mp.MapboxMap controller) {
    _mapboxMapController = controller;
  }

  /// ✅ Updates both **source** and **layer**
  void updateHeatmap(MapState mapState) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      print("🔥 Debounced heatmap update triggered...");
      await _updateHeatmapSource(mapState);
      await _updateHeatmapLayer(mapState);
    });
  }

  /// ✅ Ensures the **heatmap source** is correctly updated
  Future<void> _updateHeatmapSource(MapState mapState) async {
    if (_mapboxMapController == null) {
      print("🚨 ERROR: Mapbox controller is null!");
      return;
    }

    final style = _mapboxMapController!.style;
    final sources = await style.getStyleSources();
    final hasHeatmapSource = sources.any((s) => s?.id == "heatmap-source");
    final List<mp.Feature> features = _parseGeoJsonFeatures(mapState.geoJson);
    if (!hasHeatmapSource) {
      print("🆕 Adding heatmap source...");
      await style.addSource(mp.GeoJsonSource(
        id: "heatmap-source",
        data: mapState.geoJson,
      ));
    } else {
      print("♻️ Updating existing heatmap source...");

      if (features.isNotEmpty) {
        await style.updateGeoJSONSourceFeatures(
          "heatmap-source",
          "features",
          features,
        );
      } else {
        print("❌ Error parsing GeoJSON features");
      }
    }
  }


  Future<void> _updateHeatmapLayer(MapState mapState) async {
    if (_mapboxMapController == null) {
      print("🚨 ERROR: Mapbox controller is null! Heatmap update aborted.");
      return;
    }

    final style = _mapboxMapController!.style;
    final layers = await style.getStyleLayers();
    final hasHeatmapLayer = layers.any((l) => l?.id == "heatmap-layer");

    print("🛠 Heatmap update triggered!");
    print("🎛 Radius: ${mapState.radius}, Opacity: ${mapState.opacity}");
    print("🎚 Range Values: ${mapState.rangeValues}");

    final globalMinMax = ref.watch(minMaxGramProvider);
    MinMaxValues normalizedRange = normalizeMinMax(mapState.rangeValues,
        globalMinMax.minV, globalMinMax.maxV); // Normalize range values
    final dynamicExpression = generateDynamicHeatmapWeightExpression(
        normalizedRange.minV, normalizedRange.maxV);

    print("🧐 New Heatmap Weight Expression: $dynamicExpression");

    final heatmapLayer = mp.HeatmapLayer(
      id: "heatmap-layer",
      sourceId: "heatmap-source",
      heatmapWeightExpression: dynamicExpression,
      heatmapColorExpression: [
        "interpolate",
        ["linear"],
        ["heatmap-density"],
        0,
        "rgba(0, 0, 255, 0)",
        0.2,
        "royalblue",
        0.4,
        "cyan",
        0.6,
        "lime",
        0.8,
        "yellow",
        1.0,
        "red"
      ],
      heatmapRadius: mapState.radius,
      heatmapOpacity: mapState.opacity,
    );

    if (hasHeatmapLayer) {
      print("🔄 Updating existing heatmap layer...");
      await style.updateLayer(heatmapLayer);
    } else {
      print("🆕 Adding new heatmap layer...");
      await style.addLayer(heatmapLayer);
    }

    print("✅ Heatmap successfully updated!");
  }

//Method to generate dynamic heatmap weight expression
  List<Object> generateDynamicHeatmapWeightExpression(
      double minWeight, double maxWeight) {
    // Ensure minWeight < maxWeight, otherwise adjust
    if (minWeight >= maxWeight) {
      maxWeight = minWeight + 0.01; // Prevents identical values
    }

    return [
      "interpolate", ["linear"],

      // Use heatmap-weight based directly on "weight" property
      [
        "coalesce",
        ["get", "weight"],
        1
      ], // Fallback to 1 if weight is missing

      minWeight, 0.5, // Minimum weight → low intensity
      (minWeight + maxWeight) / 2, 2, // Mid-range weight → moderate intensity
      maxWeight, 10 // Maximum weight → highest intensity
    ];
  }

  //Method to normalize the min and max values to be used in dynamic heatmap weight expression
  MinMaxValues normalizeMinMax(
      MinMaxValues input, double globalMin, double globalMax) {
    if (globalMax == globalMin) {
      return MinMaxValues(minV: 0, maxV: 1);
    }

    // Ensure input values are within valid range
    double adjustedMin = input.minV.clamp(globalMin, globalMax);
    double adjustedMax = input.maxV.clamp(globalMin, globalMax);

    // Normalize using range slider values
    double normalizedMin = (adjustedMin - globalMin) / (globalMax - globalMin);
    double normalizedMax = (adjustedMax - globalMin) / (globalMax - globalMin);

    // Ensure there's always a valid range
    if ((normalizedMax - normalizedMin).abs() < 0.01) {
      normalizedMax = (normalizedMin + 0.01).clamp(0.0, 1.0);
    }

    return MinMaxValues(
      minV: normalizedMin,
      maxV: normalizedMax,
    );
  }

  List<mp.Feature> _parseGeoJsonFeatures(String geoJsonString) {
    try {
      final geoJsonMap = jsonDecode(geoJsonString);
      if (geoJsonMap['features'] is List) {
        return (geoJsonMap['features'] as List).map((feature) {
          return mp.Feature(
            geometry: mp.GeoJSONObject.fromJson(feature['geometry'])
                as mp.GeometryObject,
            id: feature['properties']?['id'] ??
                "feature-${DateTime.now().millisecondsSinceEpoch}",
            properties: feature['properties'] ?? {},
          );
        }).toList();
      }
    } catch (e) {
      print("❌ Error parsing GeoJSON: $e");
    }
    return [];
  }
}

// ✅ Register the provider
final heatmapProvider = StateNotifierProvider<HeatmapNotifier, void>((ref) {
  return HeatmapNotifier(ref);
});

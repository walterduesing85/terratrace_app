import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'map_data.dart';

class HeatmapNotifier extends StateNotifier<void> {
  HeatmapNotifier(this.ref) : super(null) {
    // ✅ Ensure the heatmap is initialized properly
    initHeatmap();

    // ✅ Listen for changes in flux data to update the heatmap source
    ref.listen<AsyncValue<List<FluxData>>>(fluxDataListProvider, (prev, next) {
      next.when(
        data: (fluxDataList) async {
          print("🔥 Flux data updated (${fluxDataList.length} points)");
          await updateHeatmapSource(fluxDataList);
        },
        loading: () => print("⏳ Flux data is loading..."),
        error: (err, stack) => print("❌ Error loading flux data: $err"),
      );
    });
  }

  final Ref ref;
  mp.MapboxMap? _mapboxMapController;

  /// ✅ Initialize the heatmap when the provider is first created
  Future<void> initHeatmap() async {
    print("🔥 Initializing heatmap...");
    final fluxDataList = ref.read(fluxDataListProvider).maybeWhen(
          data: (data) =>
              data.cast<FluxData>(), // ✅ Explicitly cast to List<FluxData>
          orElse: () => <FluxData>[], // ✅ Ensure the list type is correct
        );

    if (fluxDataList.isNotEmpty) {
      await updateHeatmapSource(fluxDataList);
    }
  }

  void setMapboxController(mp.MapboxMap controller) {
    _mapboxMapController = controller;
  }

  /// ✅ Get the current Mapbox controller
  mp.MapboxMap? getMapboxController() {
    return _mapboxMapController;
  }

  Future<void> updateHeatmapSource(List<FluxData> fluxDataList) async {
    if (_mapboxMapController == null) return;

    final style = _mapboxMapController!.style;
    final hasHeatmapSource =
        (await style.getStyleSources()).any((s) => s?.id == "heatmap-source");
    final layers = await style.getStyleLayers();
    final hasHeatmapLayer = layers.any((l) => l?.id == "heatmap-layer");

    final geoJsonString = _convertFluxDataToGeoJSON(fluxDataList);

    if (hasHeatmapSource) {
      await style.setStyleSourceProperties(
          "heatmap-source", json.encode({"data": json.decode(geoJsonString)}));
    } else {
      await style.addSource(
          mp.GeoJsonSource(id: "heatmap-source", data: geoJsonString));
      if (hasHeatmapLayer == false) {
        print("🔥 Adding heatmap layer... from UpdateSOurce");
        updateHeatmapLayer(ref.read(heatmapLayerProvider));
      }
    }
  }

  Future<void> updateHeatmapLayer(heatmapLayer) async {
    if (_mapboxMapController == null) {
      print("🚨 ERROR: MapboxMapController is NULL! Cannot update heatmap.");
      return;
    }

    if (_mapboxMapController == null) return;

    final style = _mapboxMapController!.style;
    final layers = await style.getStyleLayers();
    final hasHeatmapLayer = layers.any((l) => l?.id == "heatmap-layer");

    if (hasHeatmapLayer) {
      await style.updateLayer(heatmapLayer);
      print("🔥 Updated heatmap layer YEAHHH");
    } else {
      await style.addLayer(heatmapLayer);
    }
  }
}

final heatmapProvider = StateNotifierProvider<HeatmapNotifier, void>((ref) {
  return HeatmapNotifier(ref);
});

/// ✅ **Provider for HeatmapNotifier**
final heatmapLayerProvider = Provider<mp.HeatmapLayer>((ref) {
  final mapState = ref.watch(mapStateProvider);
  final globalMinMax = ref.watch(minMaxGramProvider);

  final normalizedRange = normalizeMinMax(
    mapState.rangeValues,
    globalMinMax.minV,
    globalMinMax.maxV,
  );

  print(
      "🟢 HeatmapLayerProvider updated: radius=${mapState.radius}, opacity=${mapState.opacity}, rangeValues=${mapState.rangeValues}");

  return mp.HeatmapLayer(
    id: "heatmap-layer",
    sourceId: "heatmap-source",
    heatmapWeightExpression: generateDynamicHeatmapWeightExpression(
        normalizedRange.minV, normalizedRange.maxV),
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
});

//Method to generate dynamic heatmap weight expression
List<Object> generateDynamicHeatmapWeightExpression(
    double minWeight, double maxWeight) {
  if (minWeight >= maxWeight) {
    maxWeight = minWeight + 0.01; // Prevents identical values
  }

  print("🔍 Generating Weight Expression with: min=$minWeight, max=$maxWeight");

  final expression = [
    "interpolate",
    ["linear"],
    [
      "coalesce",
      ["get", "weight"],
      1.0
    ],
    minWeight, 0.2, // 🔥 Start with **visible low intensity**
    (minWeight + maxWeight) / 2, 5.0, // 🔥 Increase the middle intensity
    maxWeight, 10.0 // 🔥 Make the highest intensity much stronger
  ];

  print("🔥 Final Generated Heatmap Weight Expression: $expression");
  return expression;
}

MinMaxValues normalizeMinMax(
    MinMaxValues input, double globalMin, double globalMax) {
  if (globalMax == globalMin) {
    return MinMaxValues(minV: 1, maxV: 10); // Prevents division by zero
  }

  // ✅ Scale up normalization to ensure values don't collapse near zero
  double scalingFactor = 50.0;

  double adjustedMin = input.minV.clamp(globalMin, globalMax);
  double adjustedMax = input.maxV.clamp(globalMin, globalMax);

  double normalizedMin = ((adjustedMin - globalMin) / (globalMax - globalMin)) * scalingFactor;
  double normalizedMax = ((adjustedMax - globalMin) / (globalMax - globalMin)) * scalingFactor;

  // Ensure a valid range
  if ((normalizedMax - normalizedMin).abs() < 1.0) {
    normalizedMax = (normalizedMin + 1.0).clamp(1.0, scalingFactor);
  }

  print("🔍 Normalized Min/Max: $normalizedMin - $normalizedMax");

  return MinMaxValues(
    minV: normalizedMin,
    maxV: normalizedMax,
  );
}


/// ✅ Converts `FluxDataList` to GeoJSON format
String _convertFluxDataToGeoJSON(List<FluxData> fluxDataList) {
  final features = fluxDataList.map((fluxData) {
    final lat = double.tryParse(fluxData.dataLat ?? '0.0') ?? 0.0;
    final lng = double.tryParse(fluxData.dataLong ?? '0.0') ?? 0.0;
    final weight = double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 1.0;

    return {
      "type": "Feature",
      "properties": {"weight": weight},
      "geometry": {
        "type": "Point",
        "coordinates": [lng, lat]
      }
    };
  }).toList();

  return json.encode({"type": "FeatureCollection", "features": features});
}

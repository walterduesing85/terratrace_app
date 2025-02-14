import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import '../../data/domain/flux_data.dart';

// Class to hold min/max CO2 values for normalization
class MinMaxValues {
  final double minV;
  final double maxV;

  const MinMaxValues({required this.minV, required this.maxV});
}

// Class to generate heatmap intensities
class MapData {
  List<double> createIntensity(
      MinMaxValues minMax, List<FluxData> fluxDataList) {
    return fluxDataList.map((fluxData) {
      final cO2 = double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 0.0;
      final normalized =
          (log(cO2 - minMax.minV + 1) / log(minMax.maxV - minMax.minV + 1))
              .clamp(0.0, 1.0);
      return normalized;
    }).toList();
  }
}

// State class for map configuration
class MapState {
  final String geoJson;
  final double zoom;
  final double radius;
  final double opacity;

  MapState({
    this.geoJson = '',
    this.zoom = 15.0,
    this.radius = 30.0,
    this.opacity = 0.75,
  });

  MapState copyWith({
    String? geoJson,
    double? zoom,
    double? radius,
    double? opacity,
  }) {
    return MapState(
      geoJson: geoJson ?? this.geoJson,
      zoom: zoom ?? this.zoom,
      radius: radius ?? this.radius,
      opacity: opacity ?? this.opacity,
    );
  }
}

// StateNotifier for managing map state
class MapStateNotifier extends StateNotifier<MapState> {
  MapStateNotifier() : super(MapState());

  Future<void> initHeatmap(WidgetRef ref) async {
    final geoJson = await ref.watch(geoJsonProvider.future);
    state = state.copyWith(geoJson: geoJson);
  }

  void setRadius(double value) {
    state = state.copyWith(radius: value);
  }

  void setOpacity(double value) {
    state = state.copyWith(opacity: value);
  }
}

// Providers
final mapStateProvider = StateNotifierProvider<MapStateNotifier, MapState>(
    (ref) => MapStateNotifier());

final radiusProvider = StateProvider<double>((ref) => 30.0);
final layerOpacityProvider = StateProvider<double>((ref) => 0.75);

final mapDataProvider = Provider<MapData>((ref) => MapData());

// Provider for min and max CO2 values
final minMaxGramProvider = StateProvider<MinMaxValues>((ref) {
  final fluxDataListAsync = ref.watch(fluxDataListProvider);
  return fluxDataListAsync.maybeWhen(
    data: (dataList) {
      final cO2List = dataList.map((fluxData) {
        return double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 0.0;
      }).toList();
      if (cO2List.isEmpty) return const MinMaxValues(minV: 0.0, maxV: 1.0);
      return MinMaxValues(
        minV: cO2List.reduce(min),
        maxV: cO2List.reduce(max),
      );
    },
    orElse: () => const MinMaxValues(minV: 0.0, maxV: 1.0),
  );
});

// Provider for intensity values
final intensityProvider = FutureProvider.autoDispose<List<double>>((ref) async {
  final minMaxValues = ref.watch(minMaxGramProvider);
  final fluxDataListAsync = ref.watch(fluxDataListProvider);
  return fluxDataListAsync.maybeWhen(
    data: (dataList) =>
        ref.read(mapDataProvider).createIntensity(minMaxValues, dataList),
    orElse: () => [],
  );
});

// Provider for GeoJSON generation
final geoJsonProvider = FutureProvider.autoDispose<String>((ref) async {
  final intensities = await ref.watch(intensityProvider.future);
  final fluxDataListAsync = ref.watch(fluxDataListProvider);

  return fluxDataListAsync.maybeWhen(
    data: (dataList) {
      final features = dataList.asMap().entries.map((entry) {
        final index = entry.key;
        final fluxData = entry.value;

        final lat = double.tryParse(fluxData.dataLat ?? '0.0') ?? 0.0;
        final long = double.tryParse(fluxData.dataLong ?? '0.0') ?? 0.0;
        final weight = intensities[index].clamp(0.0, 1.0);

        return '''
          {
            "type": "Feature",
            "properties": { "weight": $weight },
            "geometry": {
              "type": "Point",
              "coordinates": [$long, $lat]
            }
          }
        ''';
      }).join(',');

      return '''
      {
        "type": "FeatureCollection",
        "features": [
          $features
        ]
      }
      ''';
    },
    orElse: () => '{ "type": "FeatureCollection", "features": [] }',
  );
});

final heatmapProvider = FutureProvider.autoDispose<HeatmapLayer>((ref) async {
  final radius = ref.watch(radiusProvider);
  final opacity = ref.watch(layerOpacityProvider);
  await ref.watch(geoJsonProvider.future);

  return HeatmapLayer(
    id: "heatmap-layer",
    sourceId: "heatmap-source",
    heatmapWeightExpression: [
      "interpolate", ["linear"], ["get", "weight"],
      0.1, 0.1, // Very low weight → weak effect
      0.3, 0.3, // Low weight → slightly visible
      0.6, 0.6, // Medium-low weight → moderate visibility
      0.8, 0.9, // High weight → strong intensity
      1.0, 1.0 // Maximum weight → full intensity
    ],
    heatmapColorExpression: [
      "interpolate", ["linear"], ["heatmap-density"],
      0, "rgba(0, 0, 255, 0)", // Transparent at low density
      0.2, "royalblue",
      0.4, "cyan",
      0.6, "lime",
      0.8, "yellow",
      1.0, "red" // High density → red
    ],
    heatmapRadius: radius,
    heatmapIntensity: 4,
    heatmapOpacity: opacity,
  );
});

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

class MapData {
  List<double> createIntensity(MinMaxValues minMax, List<FluxData> fluxDataList,
      bool useLogNormalization) {
    return fluxDataList.map((fluxData) {
      final cO2 = double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 0.0;
      double normalized;

      if (useLogNormalization) {
        // ✅ Log Normalization
        final logMin = log(minMax.minV + 1);
        final logMax = log(minMax.maxV + 1);
        final logC02 = log(cO2 + 1);
        normalized = ((logC02 - logMin) / (logMax - logMin)).clamp(0.0, 1.0);
      } else {
        // ✅ Linear Normalization
        normalized =
            ((cO2 - minMax.minV) / (minMax.maxV - minMax.minV)).clamp(0.0, 1.0);
      }

      return normalized;
    }).toList();
  }
}

class MapState {
  final String geoJson;
  final double zoom;
  final double radius;
  final double opacity;
  final List<double> intensities;
  final MinMaxValues rangeValues;
  final bool useLogNormalization;
  final String mapStyle; // ✅ Include map style

  MapState({
    this.geoJson = '',
    this.zoom = 15.0,
    this.radius = 30.0,
    this.opacity = 0.75,
    this.intensities = const [],
    required this.rangeValues,
    this.useLogNormalization = false,
    this.mapStyle = "mapbox://styles/mapbox/streets-v12", // ✅ Default style
  });

  MapState copyWith({
    String? geoJson,
    double? zoom,
    double? radius,
    double? opacity,
    List<double>? intensities,
    MinMaxValues? rangeValues,
    bool? useLogNormalization,
    String? mapStyle, // ✅ Allow changing styles
  }) {
    return MapState(
      geoJson: geoJson ?? this.geoJson,
      zoom: zoom ?? this.zoom,
      radius: radius ?? this.radius,
      opacity: opacity ?? this.opacity,
      intensities: intensities ?? this.intensities,
      rangeValues: rangeValues ?? this.rangeValues,
      useLogNormalization: useLogNormalization ?? this.useLogNormalization,
      mapStyle: mapStyle ?? this.mapStyle, // ✅ Preserve map style
    );
  }
}

class MapStateNotifier extends StateNotifier<MapState> {
  MapStateNotifier()
      : super(MapState(rangeValues: MinMaxValues(minV: 0.0, maxV: 1.0)));

  Future<void> initHeatmap(WidgetRef ref) async {
    final geoJson = await ref.watch(geoJsonProvider.future);
    final intensities = await ref.watch(intensityProvider.future);
    final rangeValues = ref.read(rangeValuesProvider);

    state = state.copyWith(
      geoJson: geoJson,
      intensities: intensities,
      rangeValues: rangeValues,
    );
  }

  void setRadius(double value) {
    state = state.copyWith(radius: value);
  }

  void setOpacity(double value) {
    state = state.copyWith(opacity: value);
  }

  void toggleLogNormalization(WidgetRef ref) async {
    state = state.copyWith(useLogNormalization: !state.useLogNormalization);
    await updateGeoJson(ref);
  }

  void updateRangeValues(MinMaxValues values, WidgetRef ref) {
    state = state.copyWith(rangeValues: values);
  }

  Future<void> updateGeoJson(WidgetRef ref) async {
    final newGeoJson = await ref.watch(geoJsonProvider.future);
    final newIntensities = await ref.watch(intensityProvider.future);

    state = state.copyWith(
      geoJson: newGeoJson,
      intensities: newIntensities,
    );
  }

  void setMapStyle(String style) {
    state = state.copyWith(mapStyle: style);
  }
}

// Providers
final mapStateProvider = StateNotifierProvider<MapStateNotifier, MapState>(
    (ref) => MapStateNotifier());

final radiusProvider = StateProvider<double>((ref) => 30.0);
final layerOpacityProvider = StateProvider<double>((ref) => 0.75);
final rangeValuesProvider = StateProvider<MinMaxValues>((ref) {
  final minMax =
      ref.watch(minMaxGramProvider); // ✅ Watches for changes dynamically

  // Ensure minV is not greater than maxV and both are valid
  final minV = minMax.minV.isFinite ? minMax.minV : 0.0;
  final maxV = minMax.maxV.isFinite ? minMax.maxV : 1.0;

  if (minV == maxV) {
    return MinMaxValues(
        minV: minV, maxV: minV + 1.0); // ✅ Prevents invalid sliders
  }

  return MinMaxValues(minV: minV, maxV: maxV);
});

final mapDataProvider = Provider<MapData>((ref) => MapData());

// Provider for min and max CO2 values
final minMaxGramProvider = StateProvider<MinMaxValues>((ref) {
  final fluxDataListAsync = ref.watch(fluxDataListProvider);
  return fluxDataListAsync.maybeWhen(
    data: (dataList) {
      if (dataList.isEmpty) {
        return const MinMaxValues(minV: 0.0, maxV: 1.0); // ✅ Prevents issues
      }

      final cO2List = dataList
          .map((fluxData) =>
              double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 0.0)
          .toList();

      return MinMaxValues(
        minV: cO2List.reduce((a, b) => a < b ? a : b), // Min value
        maxV: cO2List.reduce((a, b) => a > b ? a : b), // Max value
      );
    },
    orElse: () =>
        const MinMaxValues(minV: 0.0, maxV: 1.0), // ✅ Prevents crashes
  );
});

// Provider for intensity values
final intensityProvider = FutureProvider.autoDispose<List<double>>((ref) async {
  // final minMaxValues = ref.watch(rangeValuesProvider);
  final minMaxValues =
      ref.watch(minMaxGramProvider); //updating when minMaxGramProvider changes
  final fluxDataListAsync = ref.watch(fluxDataListProvider);
  return fluxDataListAsync.maybeWhen(
    data: (dataList) => ref
        .read(mapDataProvider)
        .createIntensity(minMaxValues, dataList, false),
    orElse: () => [],
  );
});

final geoJsonProvider = FutureProvider.autoDispose<String>((ref) async {
  // final rangeValues = ref.watch(rangeValuesProvider); // ✅ Ensure it's watched

  final intensities = await ref.watch(intensityProvider.future);
  final fluxDataListAsync = ref.watch(fluxDataListProvider);

  return fluxDataListAsync.maybeWhen(
    data: (dataList) {
      final features = dataList.asMap().entries.map((entry) {
        final index = entry.key;
        final fluxData = entry.value;

        final lat = double.tryParse(fluxData.dataLat ?? '0.0') ?? 0.0;
        final long = double.tryParse(fluxData.dataLong ?? '0.0') ?? 0.0;
        final weight = intensities[index].clamp(0.0, 1.0); // ✅ Check weights

        //   print("🔍 Feature $index | Lat: $lat, Long: $long, Weight: $weight");

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

// final heatmapProvider = FutureProvider.autoDispose<HeatmapLayer>((ref) async {
//   final radius = ref.watch(radiusProvider);
//   final opacity = ref.watch(layerOpacityProvider);
//   await ref.watch(geoJsonProvider.future); // ✅ Ensures refresh

//   return HeatmapLayer(
//     id: "heatmap-layer",
//     sourceId: "heatmap-source",
//     heatmapWeightExpression: [
//       "interpolate", ["linear"], ["get", "weight"],
//       0.1, 1.0, // Very low weight → weak effect
//       0.3, 1.0, // Low weight → slightly visible
//       0.6, 1.0, // Medium-low weight → moderate visibility
//       0.8, 1.0, // High weight → strong intensity
//       1.0, 1.0 // Maximum weight → full intensity
//     ],
//     heatmapColorExpression: [
//       "interpolate", ["linear"], ["heatmap-density"],
//       0, "rgba(0, 0, 255, 1)", // not Transparent at low density
//       0.2, "royalblue",
//       0.4, "cyan",
//       0.6, "lime",
//       0.8, "yellow",
//       1.0, "red" // High density → red
//     ],
//     heatmapRadius: radius,
//     heatmapIntensity: 4,
//     heatmapOpacity: opacity,
//   );
// });

import 'dart:async';

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';

import 'package:terratrace/source/features/map/data/marker_popup_provider.dart';
import '../../data/domain/flux_data.dart';

// Class to hold min/max CO2 values for normalization
class MinMaxValues {
  final double minV;
  final double maxV;

  const MinMaxValues({required this.minV, required this.maxV});
}

class MapData {
  Timer? _debounce;
  List<double> createIntensity(MinMaxValues minMax, List<FluxData> fluxDataList,
      bool useLogNormalization) {
    return fluxDataList.map((fluxData) {
      final cO2 = double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 0.0;
      double normalized;

      if (useLogNormalization) {
        final logMin = log(minMax.minV + 1);
        final logMax = log(minMax.maxV + 1);
        final logC02 = log(cO2 + 1);
        normalized = ((logC02 - logMin) / (logMax - logMin)).clamp(0.0, 1.0);
      } else {
        normalized =
            ((cO2 - minMax.minV) / (minMax.maxV - minMax.minV)).clamp(0.0, 1.0);
      }

      return normalized;
    }).toList();
  }

  Future<void> updateMarkerLayer(
      MapboxMap mapboxMap, List<FluxData> fluxDataList, WidgetRef ref) async {
    print("📍 updateMarkerLayer() called with ${fluxDataList.length} markers.");

    if (mapboxMap == null) {
      print("🚨 ERROR: Mapbox controller is NULL! Markers cannot be added.");
      return;
    }

    // ✅ Create or reuse the PointAnnotationManager
    final pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // ✅ Remove previous annotations before adding new ones (prevents duplicates)
    await pointAnnotationManager.deleteAll();

    if (fluxDataList.isNotEmpty) {
      // ✅ Load marker icon from assets
      final ByteData bytes =
          await rootBundle.load('assets/black-dot.png'); // Ensure this exists
      final Uint8List imageData = bytes.buffer.asUint8List();

      print("✅ Adding ${fluxDataList.length} markers...");

      // ✅ Convert FluxData into Mapbox PointAnnotations
      List<PointAnnotationOptions> pointAnnotations = [];

      for (var data in fluxDataList) {
        final double latitude = double.tryParse(data.dataLat ?? '') ?? 0.0;
        final double longitude = double.tryParse(data.dataLong ?? '') ?? 0.0;

        print("🛰️ Adding marker at LAT: $latitude, LNG: $longitude");

        final PointAnnotationOptions pointAnnotationOptions =
            PointAnnotationOptions(
          geometry: Point(coordinates: Position(longitude, latitude)),
          image: imageData, // ✅ Custom marker image
          iconSize: 0.08, // ✅ Adjust size as needed
        );

        pointAnnotations.add(pointAnnotationOptions);
      }

      // ✅ Create multiple annotations at once
      await pointAnnotationManager.createMulti(pointAnnotations);

      // ✅ Pass `ref` to CustomPointAnnotationClickListener
      pointAnnotationManager.addOnPointAnnotationClickListener(
        CustomPointAnnotationClickListener(fluxDataList, ref),
      );

      print("✅ All markers added successfully with tap support!");
    } else {
      print("⚠️ No flux data available for markers.");
    }
  }
}

/// ✅ Custom class to handle marker taps

class CustomPointAnnotationClickListener
    extends OnPointAnnotationClickListener {
  final List<FluxData> fluxDataList;
  final WidgetRef ref; // Riverpod reference

  CustomPointAnnotationClickListener(this.fluxDataList, this.ref);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    print("📍 Marker tapped: ${annotation.geometry}");

    // 🎯 Find the matching FluxData entry
    final tappedFluxData = fluxDataList.firstWhere(
      (data) {
        final lat = double.tryParse(data.dataLat ?? '') ?? 0.0;
        final lng = double.tryParse(data.dataLong ?? '') ?? 0.0;
        return annotation.geometry == Point(coordinates: Position(lng, lat));
      },
      orElse: () => FluxData(dataLat: "0.0", dataLong: "0.0"),
    );

    // ✅ Send data to Riverpod provider
    ref.read(markerPopupProvider.notifier).addPopup(tappedFluxData);
  }
}

// /// 🎯 Function to handle marker taps
// void _onMarkerTapped(FluxData data) {
//   print("🛰️ Marker Details: ${data.toString()}");
//   // 👉 Show a dialog, navigate to another screen, or fetch more details
// }

class MapState {
  final String geoJson;
  final double zoom;
  final double radius;
  final double opacity;
  final List<double> intensities;
  final MinMaxValues rangeValues;
  final bool useLogNormalization;
  final String mapStyle;
  final List<FluxData> fluxDataList; // ✅ NEW: Store flux data here

  MapState({
    this.geoJson = '',
    this.zoom = 15.0,
    this.radius = 10.0,
    this.opacity = 0.75,
    this.intensities = const [],
    required this.rangeValues,
    this.useLogNormalization = false,
    this.mapStyle = "mapbox://styles/mapbox/streets-v12",
    this.fluxDataList = const [], // ✅ Default empty list
  });

  MapState copyWith({
    String? geoJson,
    double? zoom,
    double? radius,
    double? opacity,
    List<double>? intensities,
    MinMaxValues? rangeValues,
    bool? useLogNormalization,
    String? mapStyle,
    List<FluxData>? fluxDataList, // ✅ Ensure it can be updated
  }) {
    return MapState(
      geoJson: geoJson ?? this.geoJson,
      zoom: zoom ?? this.zoom,
      radius: radius ?? this.radius,
      opacity: opacity ?? this.opacity,
      intensities: intensities ?? this.intensities,
      rangeValues: rangeValues ?? this.rangeValues,
      useLogNormalization: useLogNormalization ?? this.useLogNormalization,
      mapStyle: mapStyle ?? this.mapStyle,
      fluxDataList: fluxDataList ?? this.fluxDataList, // ✅ Preserve flux data
    );
  }
}

class MapStateNotifier extends StateNotifier<MapState> {
  final Ref ref;

  MapStateNotifier(this.ref)
      : super(MapState(rangeValues: MinMaxValues(minV: 0.0, maxV: 1.0))) {
    // ✅ Listen for changes in `fluxDataListProvider` to update the heatmap
    ref.listen<AsyncValue<List<FluxData>>>(fluxDataListProvider, (prev, next) {
      next.when(
        data: (fluxDataList) {
          print("🔥 Flux data updated (${fluxDataList.length} points)");

          Future.microtask(() async {
            print("🔍 Updating map state with new flux data...");
            await _updateMapStateWithFluxData(fluxDataList);
          });
        },
        loading: () => print("⏳ Flux data is loading..."),
        error: (err, stack) => print("❌ Error loading flux data: $err"),
      );
    });

    // ✅ Listen for changes in `geoJsonProvider` to trigger heatmap update
    ref.listen<AsyncValue<String>>(geoJsonProvider, (_, next) {
      next.when(
        data: (geoJson) {
          print("🔥 geoJson updated, refreshing heatmap...");
          _updateHeatmap();
        },
        loading: () => print("⏳ geoJson is loading..."),
        error: (err, stack) => print("❌ Error updating geoJson: $err"),
      );
    });
  }

  Future<void> _updateMapStateWithFluxData(List<FluxData> fluxDataList) async {
    final geoJson = await ref.read(geoJsonProvider.future);
    final intensities = await ref.read(intensityProvider.future);
    // ✅ Update markers when initializing map
    final mapboxMap = ref.read(heatmapProvider.notifier).getMapboxController();
    if (mapboxMap != null) {
      ref
          .read(mapDataProvider)
          .updateMarkerLayer(mapboxMap, fluxDataList, ref as WidgetRef);
    } else {
      print("⚠️ Mapbox controller is NULL during initialization.");
    }

    state = state.copyWith(
      geoJson: geoJson,
      intensities: intensities,
      fluxDataList: List.from(fluxDataList), // ✅ Always create a new list
    );

    _updateHeatmap();
  }

  /// ✅ Triggers heatmap update
  void _updateHeatmap() {
    print("🔥 Updating heatmap...");
    ref.read(heatmapProvider.notifier).updateHeatmapLayer(state);
  }

  /// ✅ Initializes the heatmap using available flux data
  Future<void> initHeatmap(WidgetRef ref) async {
    final geoJson = await ref.watch(geoJsonProvider.future);
    final intensities = await ref.watch(intensityProvider.future);
    final rangeValues = ref.read(rangeValuesProvider);

    // ✅ Ensure correct type casting to `List<FluxData>`
    final List<FluxData> fluxDataList =
        ref.read(fluxDataListProvider).maybeWhen(
              data: (data) => data.cast<FluxData>(), // Explicit cast
              orElse: () => [],
            );

    state = state.copyWith(
      geoJson: geoJson,
      intensities: intensities,
      rangeValues: rangeValues,
      fluxDataList: fluxDataList, // ✅ Now correctly typed
    );
    // ✅ Update markers when initializing map
    final mapboxMap = ref.read(heatmapProvider.notifier).getMapboxController();
    if (mapboxMap != null) {
      ref.read(mapDataProvider).updateMarkerLayer(mapboxMap, fluxDataList, ref);
    } else {
      print("⚠️ Mapbox controller is NULL during initialization.");
    }

    // ✅ Trigger heatmap update
    // ref.read(heatmapProvider.notifier).updateHeatmapLayer(state);
  }

  /// ✅ UI Functions to modify `MapState`
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

    // ✅ Trigger heatmap update
    ref.read(heatmapProvider.notifier).updateHeatmapLayer(state);
  }

  void setMapStyle(String style) {
    state = state.copyWith(mapStyle: style);
  }
}

// Providers
final mapStateProvider =
    StateNotifierProvider<MapStateNotifier, MapState>((ref) {
  return MapStateNotifier(ref);
});

final radiusProvider = StateProvider<double>((ref) => 10.0);
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
  // ✅ Read flux data asynchronously to prevent circular dependencies
  final fluxDataListAsync = await ref.watch(fluxDataListProvider.future);
  final intensities = await ref.watch(intensityProvider.future);

  final features = fluxDataListAsync.asMap().entries.map((entry) {
    final index = entry.key;
    final fluxData = entry.value;

    final lat = double.tryParse(fluxData.dataLat ?? '0.0') ?? 0.0;
    final long = double.tryParse(fluxData.dataLong ?? '0.0') ?? 0.0;
    final weight =
        (index < intensities.length) ? intensities[index].clamp(0.0, 1.0) : 0.0;

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

  print(
      "🔥 geoJsonProvider recomputed with ${fluxDataListAsync.length} points");

  return '''
  {
    "type": "FeatureCollection",
    "features": [
      $features
    ]
  }
  ''';
});

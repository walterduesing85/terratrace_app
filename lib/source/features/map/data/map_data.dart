import 'dart:async';

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
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
}

// /// ✅ Custom class to handle marker taps
// class CustomPointAnnotationClickListener
//     extends mp.OnPointAnnotationClickListener {
//   final List<FluxData> fluxDataList;
//   final Ref ref; // ✅ Use `Ref` instead of `WidgetRef`

//   CustomPointAnnotationClickListener(this.fluxDataList, this.ref);

//   @override
//   void onPointAnnotationClick(mp.PointAnnotation annotation) {
//     print("📍 Marker tapped: ${annotation.geometry}");

//     final tappedFluxData = fluxDataList.firstWhere(
//       (data) {
//         final lat = double.tryParse(data.dataLat ?? '') ?? 0.0;
//         final lng = double.tryParse(data.dataLong ?? '') ?? 0.0;
//         return annotation.geometry ==
//             mp.Point(coordinates: mp.Position(lng, lat));
//       },
//       orElse: () => FluxData(dataLat: "0.0", dataLong: "0.0"),
//     );

//     // ✅ Pass `Ref` instead of `WidgetRef`
//     ref.read(markerPopupProvider.notifier).addPopup(tappedFluxData);
//   }
// }

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

  mp.PointAnnotationManager? _selectedAnnotationManager;

  MapStateNotifier(this.ref)
      : super(MapState(rangeValues: MinMaxValues(minV: 0.0, maxV: 1.0))) {
    // ✅ Listen for changes to the selected data

    ref.listen<List<FluxData>>(selectedFluxDataProvider, (prev, next) async {
      print("📍 Selected FluxData updated: ${next.length} points");
      await updateSelectedAnnotations();
    });
  }

  final List<mp.PointAnnotation> selectedAnnotations = [];

  Future<void> updateSelectedAnnotations() async {
    print("📍 Updating Selected Annotations...");

    final selectedData = ref.read(selectedFluxDataProvider);

    // ✅ Get Mapbox controller
    final mapboxMap = ref.read(heatmapProvider.notifier).getMapboxController();
    if (mapboxMap == null) {
      print("⚠️ Mapbox controller is NULL. Cannot update annotations.");
      return;
    }

    // ✅ Create (or reuse) the annotation manager for selected annotations
    if (_selectedAnnotationManager == null) {
      _selectedAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      print("✅ Created new SelectedAnnotationManager.");
    }

    if (_selectedAnnotationManager == null) {
      print("🚨 ERROR: Failed to initialize SelectedAnnotationManager!");
      return;
    }

    // ✅ Clear previous selected annotations using deleteAll()
    print("🗑 Removing previous selected annotations...");
    await _selectedAnnotationManager!.deleteAll();
    selectedAnnotations.clear();

    if (selectedData.isNotEmpty) {
      print("🖼 Loading marker icon for selected data...");
      final ByteData bytes = await rootBundle.load('assets/marker_tt.png');
      final Uint8List imageData = bytes.buffer.asUint8List();

      print("📍 Creating annotations for ${selectedData.length} points...");
      List<mp.PointAnnotationOptions> annotationOptions =
          selectedData.map((data) {
        final lat = double.tryParse(data.dataLat ?? '') ?? 0.0;
        final lng = double.tryParse(data.dataLong ?? '') ?? 0.0;

        return mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: mp.Position(lng, lat)),
            image: imageData,
            iconSize: 1.0,
            iconAnchor: mp.IconAnchor.BOTTOM);
      }).toList();

      // ✅ Remove null values before adding new annotations
      final newAnnotations =
          await _selectedAnnotationManager!.createMulti(annotationOptions);
      selectedAnnotations
          .addAll(newAnnotations.whereType<mp.PointAnnotation>());
    }

    print(
        "✅ Selected Annotations updated: ${selectedAnnotations.length} points");
  }

  /// ✅ UI Functions to modify `MapState`
  void setRadius(double value) {
    state = state.copyWith(radius: value);
  }

  void setOpacity(double value) {
    state = state.copyWith(opacity: value);
  }

  Future<void> toggleLogNormalization(WidgetRef ref) async {
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

final minMaxGramProvider = StateProvider<MinMaxValues>((ref) {
  final fluxDataListAsync = ref.watch(selectedDataSetProvider);

  return fluxDataListAsync.maybeWhen(
    data: (dataList) {
      if (dataList.isEmpty) {
        return const MinMaxValues(minV: 0.0, maxV: 1.0); // ✅ Prevents issues
      }

      final cO2List = dataList
          .map((fluxData) => double.tryParse(fluxData ?? '0.0') ?? 0.0)
          .toList();

      if (cO2List.length == 1) {
        final singleValue = cO2List.first;
        print("📊 Single value: $singleValue");
        return MinMaxValues(
          minV: singleValue,
          maxV: singleValue + 1.0, // ✅ Ensures valid range
        );
      }

      return MinMaxValues(
        minV: cO2List.reduce(min), // Min value
        maxV: cO2List.reduce(max), // Max value
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

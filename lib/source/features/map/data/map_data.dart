import 'dart:math';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import '../../data/domain/flux_data.dart';

// Class to hold minimum and maximum values
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
    //   final cO2 = double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 0.0;
    //   if (cO2 <= minMax.minV) return 0.0;
    //   if (cO2 >= minMax.maxV) return 1.0;
    //   return ((cO2 - minMax.minV) / (minMax.maxV - minMax.minV))
    //       .clamp(0.0, 1.0); // Ensure minimum intensity
    // }).toList();
  }
}

// State class for map configuration
class MapState {
  final Set<WeightedLatLng> heatmaps;
  final double zoom;
  final double radius;
  final double minOpacity;
  final double blurFactor;
  final double layerOpacity;
  final bool showMarkers;

  MapState({
    this.heatmaps = const {},
    this.zoom = 15.0,
    this.radius = 30.0,
    this.minOpacity = 0.3,
    this.blurFactor = 0.5,
    this.layerOpacity = 0.75,
    this.showMarkers = false,
  });

  MapState copyWith({
    Set<WeightedLatLng>? heatmaps,
    double? zoom,
    double? radius,
    double? minOpacity,
    double? blurFactor,
    double? layerOpacity,
    bool? showMarkers,
  }) {
    return MapState(
      heatmaps: heatmaps ?? this.heatmaps,
      zoom: zoom ?? this.zoom,
      radius: radius ?? this.radius,
      minOpacity: minOpacity ?? this.minOpacity,
      blurFactor: blurFactor ?? this.blurFactor,
      layerOpacity: layerOpacity ?? this.layerOpacity,
      showMarkers: showMarkers ?? this.showMarkers,
    );
  }
}

class MapSettings {
  final List<WeightedLatLng> weightedLatLngList;
  final double pointRadius;
  final double mapOpacity;
  final bool showMarkers;

  MapSettings({
    required this.weightedLatLngList,
    required this.pointRadius,
    required this.mapOpacity,
    required this.showMarkers,
  });
}

// StateNotifier for managing map state
class MapStateNotifier extends StateNotifier<MapState> {
  MapStateNotifier() : super(MapState());

  void initHeatmap(WidgetRef ref) async {
    final weightedLatLngList =
        await ref.watch(weightedLatLngListProvider.future);
    state = state.copyWith(heatmaps: weightedLatLngList.toSet());
  }

  void setWeightedLatLngList(List<WeightedLatLng> list) {
    state = state.copyWith(heatmaps: list.toSet());
  }

  void setZoom(double value) {
    state = state.copyWith(
      zoom: value,
      radius: (50 / value).clamp(10.0, 50.0),
      layerOpacity: (value / 18).clamp(0.3, 1.0),
      showMarkers: value > 15,
      // showMarkers: value > 15,
    );
  }

  void setRadius(double value) {
    state = state.copyWith(radius: value);
  }

  void setLayerOpacity(double value) {
    state = state.copyWith(layerOpacity: value);
  }

  // void updateHeatmap(List<WeightedLatLng> data, double radius, double opacity) {
  //   print('hello from updateHeatmap $radius $opacity');
  //   state = state.copyWith(
  //     heatmaps: data.toSet(),
  //     radius: radius,
  //     layerOpacity: opacity,
  //   );
  // }
}

// Providers for map state and settings
final mapStateProvider = StateNotifierProvider<MapStateNotifier, MapState>(
    (ref) => MapStateNotifier());

final radiusProvider = StateProvider<double>((ref) => 30.0);
final layerOpacityProvider = StateProvider<double>((ref) => 0.75);
final showMarkersProvider = StateProvider<bool>((ref) => false);
final mapDataProvider = Provider<MapData>((ref) => MapData());

// Provider for min and max values
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

// Provider for WeightedLatLng list
final weightedLatLngListProvider =
    FutureProvider.autoDispose<List<WeightedLatLng>>((ref) async {
  final intensities = await ref.watch(intensityProvider.future);
  final fluxDataListAsync = ref.watch(fluxDataListProvider);

  return fluxDataListAsync.maybeWhen(
    data: (dataList) {
      return dataList.asMap().entries.map((entry) {
        final index = entry.key;
        final fluxData = entry.value;
        return WeightedLatLng(
          LatLng(
            double.tryParse(fluxData.dataLat ?? '0.0') ?? 0.0,
            double.tryParse(fluxData.dataLong ?? '0.0') ?? 0.0,
          ),
          intensities[index].clamp(0.0, 1.0),
        );
      }).toList();
      // return List<WeightedLatLng>.generate(
      //     min(dataList.length, intensities.length), (index) {
      //   // Ensure intensities.length == dataList.length.
      //   final fluxData = dataList[index];
      //   return WeightedLatLng(
      //     LatLng(
      //       double.tryParse(fluxData.dataLat ?? '0.0') ?? 0.0,
      //       double.tryParse(fluxData.dataLong ?? '0.0') ?? 0.0,
      //     ),
      //     intensities[index],
      //   );
      // });
    },
    orElse: () => [],
  );
});

// Provider for MapSettings
final mapSettingsProvider =
    FutureProvider.autoDispose<MapSettings>((ref) async {
  final weightedLatLngList = await ref.watch(weightedLatLngListProvider.future);
  final radius = ref.watch(radiusProvider);
  final opacity = ref.watch(layerOpacityProvider);
  final showMarkers = ref.watch(showMarkersProvider);

  return MapSettings(
    weightedLatLngList: weightedLatLngList,
    pointRadius: radius,
    mapOpacity: opacity,
    showMarkers: showMarkers,
  );
});

// Provider for initial camera position
final initialCameraPositionProvider = StateProvider<LatLng>((ref) {
  final fluxDataListAsync = ref.watch(fluxDataListProvider);

  return fluxDataListAsync.maybeWhen(
    data: (dataList) {
      if (dataList.isNotEmpty) {
        final firstEntry = dataList.first;
        return LatLng(
          double.tryParse(firstEntry.dataLat ?? '0.0') ?? 0.0,
          double.tryParse(firstEntry.dataLong ?? '0.0') ?? 0.0,
        );
      }
      return const LatLng(52.4894, 13.4381); // Default location
    },
    orElse: () => const LatLng(52.4894, 13.4381),
  );
});

import 'dart:math';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:terra_trace/source/features/data/data/data_management.dart';

import '../../data/domain/flux_data.dart';

class MinMaxValues {
  final double minV;
  final double maxV;

  const MinMaxValues({required this.minV, required this.maxV});
}

class MapData {
  //Intensities values for FLutter Maps Heatmap
  List<double> createIntensitiy(
      MinMaxValues minMaxV, List<FluxData> fluxDataList) {
    List<double> intensitiy = [];
    List<double> cO2 = [];
    for (int i = 0; i < fluxDataList.length; i++) {
      FluxData fluxData = fluxDataList[i];

      cO2.add(double.parse(fluxData.dataCflux!));
    }

    double roundedValue;

    for (int i = 0; i < fluxDataList.length; i++) {
      if (cO2[i] >= minMaxV.minV && cO2[i] <= minMaxV.maxV) {
        roundedValue =
            (((cO2[i] - minMaxV.minV) / (minMaxV.maxV - minMaxV.minV)));

        intensitiy.add(double.parse(roundedValue.toStringAsFixed(2)));
      } else if (cO2[i] < minMaxV.minV.round()) {
        intensitiy.add(0);
      } else if (cO2[i] > minMaxV.maxV.round()) {
        intensitiy.add(1);
      } else if (cO2[i] == minMaxV.maxV.round()) {
        intensitiy.add(1);
      } else if (cO2[i] == minMaxV.minV.round()) {
        intensitiy.add(0);
      }
    }

    return intensitiy;
  }
}

final mapDataProvider = Provider<MapData>((ref) {
  return MapData();
});


final minMaxValuesProvider = StateProvider.autoDispose<MinMaxValues>((ref) {
  final dataListAsyncValue = ref.watch(fluxDataListProvider);

  return dataListAsyncValue.when(
    data: (dataList) {
      // Extract the List<double> from FluxData.dataCflux
      final List<double> cO2List = dataList.map((fluxData) {
        try {
          return double.parse(fluxData.dataCflux!);
        } catch (e) {
          // Handle the case where parsing fails (e.g., log an error)

          return 0.0; // Provide a default value
        }
      }).toList();

      // Calculate the minimum and maximum values
      double minV = cO2List.reduce(min);
      double maxV = cO2List.reduce(max);

      return MinMaxValues(minV: minV, maxV: maxV);
    },
    loading: () => MinMaxValues(
        minV: 0.0, maxV: 1), // Provide default values during loading
    error: (error, stackTrace) {
      // Handle the error state as needed

      return MinMaxValues(
          minV: 0.0, maxV: 1); // Provide default values on error
    },
  );
});


//returns the values in grams for the range slider
final minMaxGramProvider = StateProvider<MinMaxValues>((ref) {
  final dataListAsyncValue = ref.watch(fluxDataListProvider);

  return dataListAsyncValue.when(
    data: (dataList) {
      // Extract the List<double> from FluxData.dataCflux
      final List<double> cO2List = dataList.map((fluxData) {
        try {
          return double.parse(fluxData.dataCfluxGram!);
        } catch (e) {
          // Handle the case where parsing fails (e.g., log an error)

          return 0.0; // Provide a default value
        }
      }).toList();

      // Calculate the minimum and maximum values
      double minV = cO2List.reduce(min);
      double maxV = cO2List.reduce(max);

      return MinMaxValues(minV: minV, maxV: maxV);
    },
    loading: () => MinMaxValues(
        minV: 0.0, maxV: 1), // Provide default values during loading
    error: (error, stackTrace) {
      // Handle the error state as needed

      return MinMaxValues(
          minV: 0.0, maxV: 1); // Provide default values on error
    },
  );
});

final rangeSliderMinMaxProvider = StateProvider<MinMaxValues>((ref) {
  return ref.watch(minMaxGramProvider);
});

class RangeSliderNotifier extends StateNotifier<MinMaxValues> {
  RangeSliderNotifier(MinMaxValues initialValues) : super(initialValues);

  void updateMinMaxValues(double min, double max) {
    state = MinMaxValues(minV: min, maxV: max);
  }
}

final rangeSliderNotifierProvider =
    StateNotifierProvider<RangeSliderNotifier, MinMaxValues>((ref) {
  return RangeSliderNotifier(ref.watch(rangeSliderMinMaxProvider));
});

//write me a provider that uses MinMaxValues to create a list of intensities
final intensityProvider = FutureProvider<List<double>>((ref) async {
  // Watch the minMaxValuesProvider for changes
  final minMaxValues = ref.watch(rangeSliderNotifierProvider);

  // Watch the fluxDataListProvider to get the list of FluxData asynchronously
  final fluxDataListAsyncValue = ref.watch(fluxDataListProvider);

  // Fetch and handle the FluxData list
  return fluxDataListAsyncValue.when(
    data: (fluxDataList) {
      // Access the MapData class
      final mapData = ref.read(mapDataProvider);

      if (fluxDataList.isNotEmpty) {
        // Calculate intensities based on minMaxValues and fluxDataList
        List<double> intensities =
            mapData.createIntensitiy(minMaxValues, fluxDataList);

        return intensities;
      } else {
        // Return an empty list if minMaxValues or fluxDataList is unavailable
        return [];
      }
    },
    loading: () {
      // Return an empty list during loading
      return [];
    },
    error: (error, stackTrace) {
      // Handle error state if needed

      return [];
    },
  );
});

final weightedLatLngListProvider =
    FutureProvider<List<WeightedLatLng>>((ref) async {
  // Watch the fluxDataListProvider to get the list of FluxData asynchronously
  final dataListAsyncValue = await ref.watch(fluxDataListProvider);
  print('hello from weightedLatLngListProvider-_-_-_-_-_');
  // Wait for the intensityProvider to resolve
  final intensitiesAsyncValue = await ref.watch(intensityProvider);

  WeightedLatLng createWeightedLatLng(double lat, double lng, double weight) {
    return WeightedLatLng(LatLng(lat, lng), weight);
  }

  // Check the state of dataListAsyncValue
  return dataListAsyncValue.when(
    data: (data) {
      final List<WeightedLatLng> weightedLatLngList = [];

      // Check the state of intensitiesAsyncValue
      return intensitiesAsyncValue.when(
        data: (intensities) {
          for (int i = 0; i < data.length; i++) {
            weightedLatLngList.add(createWeightedLatLng(
              double.parse(data[i].dataLat!),
              double.parse(data[i].dataLong!),
              intensities[i],
            ));
          }
          return weightedLatLngList;
        },
        loading: () {
          // Return an empty list during loading
          return [];
        },
        error: (error, stackTrace) {
          // Handle error state if needed
          return [];
        },
      );
    },
    loading: () {
      // Return an empty list during loading
      return [];
    },
    error: (error, stackTrace) {
      // Handle error state if needed
      return [];
    },
  );
});

// Heat map provider for Google Maps Heatmap package

// HeatmapController class

final initialCameraPositionProvider = StateProvider<LatLng>((ref) {
  // By default, set the camera position to a specific default value
  // You can change this logic based on your requirements

  // Get the fluxDataList asynchronously
  final fluxDataList = ref.read(fluxDataListProvider);

  // Default camera position (e.g., center of the map)
  LatLng defaultPosition = LatLng(52.4894, 13.4381); // Default position

  // Logic to determine the camera position based on fluxDataList or user selection
  fluxDataList.maybeWhen(
    data: (dataList) {
      if (dataList.isNotEmpty) {
        // Use the first entry in the dataList to determine camera position
        final firstEntry = dataList.first;
        defaultPosition = LatLng(
          double.parse(firstEntry.dataLat!),
          double.parse(firstEntry.dataLong!),
        );
      }
    },
    orElse: () {
      // Handle other states or scenarios where dataList is not available
      // For example, you might set the camera position to a default value
      // based on user preferences or application logic.
    },
  );

  return defaultPosition;
});

final initialCameraPositionProvider2 = StateProvider<LatLng>((ref) {
  // By default, set the camera position to a specific default value
  // You can change this logic based on your requirements

  // Get the fluxDataList asynchronously
  final fluxDataList = ref.read(fluxDataListProvider);

  // Default camera position (e.g., center of the map)
  LatLng defaultPosition = LatLng(52.4894, 13.4381); // Default position

  // Logic to determine the camera position based on fluxDataList or user selection
  fluxDataList.maybeWhen(
    data: (dataList) {
      if (dataList.isNotEmpty) {
        // Use the first entry in the dataList to determine camera position
        final firstEntry = dataList.first;
        defaultPosition = LatLng(
          double.parse(firstEntry.dataLat!),
          double.parse(firstEntry.dataLong!),
        );
      }
    },
    orElse: () {
      // Handle other states or scenarios where dataList is not available
      // For example, you might set the camera position to a default value
      // based on user preferences or application logic.
    },
  );

  return defaultPosition;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

//import 'package:hive/hive.dart';

import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';

final dataPointCountProvider =
    StateNotifierProvider<DataPointCountValueNotifier, int>(
        (ref) => DataPointCountValueNotifier());

class DataPointCountValueNotifier extends StateNotifier<int> {
  DataPointCountValueNotifier() : super(1);

  // Sets the data point count to a specific value.
  void setDataPointCount(int value) {
    state = value;
  }

  // Increments the data point count by one.
  void increment() {
    state++;
  }

  // Clears the count (resets it to zero).
  void clear() {
    state = 1;
  }
}

/// **1️⃣ Select the Flux Type (Dropdown-controlled)**
class SelectedFluxTypeNotifier extends StateNotifier<String> {
  SelectedFluxTypeNotifier() : super("CO2"); // Default selection
  void setFluxType(String fluxType) {
    state = fluxType;
  }
}

final selectedFluxTypeProvider =
    StateNotifierProvider<SelectedFluxTypeNotifier, String>((ref) {
  return SelectedFluxTypeNotifier();
});

final selectedDataSetProvider =
    StreamProvider.autoDispose<List<String>>((ref) async* {
  final fluxDataList = ref.watch(fluxDataListProvider); // Full dataset
  final selectedFluxType =
      ref.watch(selectedFluxTypeProvider); // Selected flux type

  // ✅ Handle loading & error state
  if (fluxDataList.isLoading) {
    print("🚀 selectedDataSetProvider is waiting for data...");
    yield [];
    return;
  }
  if (fluxDataList.hasError) {
    print("❌ ERROR in selectedDataSetProvider: ${fluxDataList.error}");
    yield [];
    return;
  }

  final dataList = fluxDataList.value ?? [];
  print('🔥 selectedDataSetProvider - Found ${dataList.length} items');

  // ✅ Filter the dataset only when needed
  final filteredData = dataList.map((fluxData) {
    switch (selectedFluxType) {
      case "Methane":
        return fluxData.dataCh4fluxGram ?? "0.0";
      case "VOC":
        return fluxData.dataVocfluxGram ?? "0.0";
      case "H2O":
        return fluxData.dataH2ofluxGram ?? "0.0";
      default: // CO₂ by default
        return fluxData.dataCfluxGram ?? "0.0";
    }
  }).toList();

  print("✅ Selected dataset updated with ${filteredData.length} values.");
  yield filteredData; // Emit only when data actually changes
});

class SearchValueNotifier extends StateNotifier<String> {
  SearchValueNotifier() : super('');

  void setSearchValue(String value) {
    state = value;
  }

  void clearSearchValue() {
    state = '';
  }
}

final searchValueTabProvider =
    StateNotifierProvider<SearchValueNotifier, String>((ref) {
  return SearchValueNotifier();
});

final searchValueProvider =
    StateNotifierProvider<SearchValueNotifier, String>((ref) {
  return SearchValueNotifier();
});

//Providers that are set for set up when project is created.. Usually do not change much

final sortPreferenceProvider = StateProvider<String>((ref) => 'highest');

class SortData {
  int counter;
  double values;
  String dates;

  SortData({this.counter = 0, this.values = 0.0, this.dates = ''});
}

final fluxDataListProvider = StreamProvider<List<FluxData>>((ref) async* {
  final projectManager = ref.watch(projectManagementProvider.notifier);
  final project = ref.watch(projectNameProvider);
  final searchValue = ref.watch(searchValueProvider);

  if (project.isNotEmpty) {
    // Call the function with the required project parameter to get the Stream
    final fluxDataStream = projectManager.getFluxDataStream(project);
    await for (final dataList in fluxDataStream) {
      yield dataList
          .where((fluxDataEl) =>
              fluxDataEl.dataSite!
                  .toLowerCase()
                  .contains(searchValue.toLowerCase()) ||
              searchValue.isEmpty)
          .toList();
    }
  } else {
    yield [];
  }
});

final listLengthProvider = Provider.autoDispose<int>((ref) {
  final dataListAsyncValue = ref.watch(fluxDataListProvider);

  return dataListAsyncValue.when(
    data: (dataList) => dataList.length,
    loading: () => 0,
    error: (error, stackTrace) => 0,
  );
});

//draws a marker on the map  when selected in Data List
final selectedFluxDataProvider =
    StateNotifierProvider<SelectedFluxDataNotifier, List<FluxData>>((ref) {
  return SelectedFluxDataNotifier();
});

class SelectedFluxDataNotifier extends StateNotifier<List<FluxData>> {
  SelectedFluxDataNotifier() : super([]);

  void toggleFluxData(FluxData fluxData) {
    if (state.contains(fluxData)) {
      state = state.where((data) => data != fluxData).toList();
    } else {
      print("new Point added");
      state = [...state, fluxData];
    }
  }

  void clear() {
    state = [];
  }
}

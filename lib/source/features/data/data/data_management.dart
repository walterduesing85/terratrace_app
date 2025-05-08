import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Toggle flux data in the selection list
  void toggleFluxData(FluxData fluxData) {
    if (state.contains(fluxData)) {
      state = state.where((data) => data != fluxData).toList();
    } else {
      print("new Point added");
      state = [...state, fluxData];
    }
  }

  // Clear the selected flux data
  void clear() {
    state = [];
  }

  // Save the selected flux data to the markerCollection inside the current project
  Future<void> saveSelectedData(
      String projectName, String collectionName, String note) async {
    try {
      // Extract the keys of the selected flux data
      final selectedDataKeys =
          state.map((fluxData) => fluxData.dataKey).toList();

      if (selectedDataKeys.isEmpty) {
        print("🛑 No selected data to save.");
        return;
      }

      // Save the selected flux data to the project's markerCollection
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectName) // Access the current project
          .collection('markerCollection') // Access the markerCollection
          .doc(collectionName) // Use the collection name as the document ID
          .set({
        'selectedDataKeys':
            selectedDataKeys, // Store the list of selected data keys
        'note': note, // Store the optional note
        'timestamp': FieldValue.serverTimestamp(), // Track the time of saving
      });

      print(
          "✅ Selected flux data saved to project: $projectName, collection: $collectionName");
    } catch (e) {
      print("🚨 Error saving selected data: $e");
    }
  }

  // Load the saved markers (dataKeys) from Firestore for a project and collection
  Future<List<String>> loadSelectedData(
      String projectName, String collectionName) async {
    try {
      // Load the selected markers from the markerCollection inside the current project
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectName) // Access the current project
          .collection('markerCollection') // Access the markerCollection
          .doc(collectionName) // Use the collection name as the document ID
          .get();

      if (doc.exists) {
        final selectedDataKeys =
            List<String>.from(doc['selectedDataKeys'] ?? []);

        if (selectedDataKeys.isNotEmpty) {
          print(
              "✅ Loaded selected flux data keys for project: $projectName, collection: $collectionName");
          return selectedDataKeys;
        } else {
          print("🛑 No saved markers found for this project/collection.");
          return [];
        }
      } else {
        print("🛑 No saved data found for this project/collection.");
        return [];
      }
    } catch (e) {
      print("🚨 Error loading selected data: $e");
      return [];
    }
  }

  // Method to load all collection names inside the 'markerCollection' for a project
  Future<List<String>> loadMarkerCollectionNames(String projectName) async {
    print("🔄 Loading marker collection names for project: $projectName...");
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectName) // Access the current project
          .collection('markerCollection') // Access the markerCollection
          .get();

      final collectionNames = snapshot.docs.map((doc) => doc.id).toList();

      print(
          "✅ Found ${collectionNames.length} collection names for project: $projectName");

      if (collectionNames.isNotEmpty) {
        print("✅ Loaded collection names for project: $projectName");
        return collectionNames;
      } else {
        print("🛑 No collections found for this project.");
        return [];
      }
    } catch (e) {
      print("🚨 Error loading marker collection names: $e");
      return [];
    }
  }

  // Method to add a list of FluxData to the selectedFluxDataProvider
  void addFluxData(List<FluxData> fluxDataList) {
    state = [...state, ...fluxDataList];
  }

  // Method to delete a marker collection
  Future<void> deleteMarkerCollection(String projectName, String collectionName) async {
    try {
      // Delete the marker collection from the project
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectName)
          .collection('markerCollection')
          .doc(collectionName)
          .delete();  
      print("✅ Marker collection deleted: $collectionName");
    } catch (e) {
      print("🚨 Error deleting marker collection: $e");
    }
  }
  
}

// Provider to track the current marker collection name
final currentMarkerCollectionProvider = StateProvider<String?>((ref) => null);

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

final projectNameProvider =
    StateNotifierProvider<ProjectNameValueNotifier, String>(
        (ref) => ProjectNameValueNotifier());

class ProjectNameValueNotifier extends StateNotifier<String> {
  ProjectNameValueNotifier() : super('');

  setProjectName(String value) {
    state = value;
  }

  void clearProjectName() {
    state = '';
  }
}

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
  final projectManager = ref.watch(projectManagementProvider);
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

class FluxDataNotifier extends StateNotifier<List<FluxData>> {
  FluxDataNotifier() : super([]);

  void setFluxData(List<FluxData> fluxData) {
    state = fluxData;
  }

  void addFluxData(FluxData fluxData) {
    Future.delayed(Duration(milliseconds: 100), () {
      state = [...state, fluxData];
    });
  }
}

final fluxDataNotifierProvider =
    StateNotifierProvider<FluxDataNotifier, List<FluxData>>((ref) {
  return FluxDataNotifier();
});

final listLengthProvider = Provider.autoDispose<int>((ref) {
  final dataListAsyncValue = ref.watch(fluxDataListProvider);

  return dataListAsyncValue.when(
    data: (dataList) => dataList.length,
    loading: () => 0,
    error: (error, stackTrace) => 0,
  );
});

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
      state = [...state, fluxData];
    }
  }

  void clear() {
    state = [];
  }
}

final markersProvider2 = Provider<Set<Marker>>((ref) {
  final selectedData = ref.watch(selectedFluxDataProvider);
  return selectedData
      .map((data) => Marker(
            point: LatLng(
              double.parse(data.dataLat!),
              double.parse(data.dataLong!),
            ),
            width: 80,
            height: 80,
            child: GestureDetector(
              // onTap: () => _showInfoWindow(, data),
              child: Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40.0,
              ),
            ),
          ))
      .toSet();
});

void _showInfoWindow(BuildContext context, FluxData data) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(data.dataSite ?? 'No Title'),
      content: Text(data.dataCfluxGram ?? 'No Content'),
      actions: <Widget>[
        TextButton(
          child: Text('Close'),
          onPressed: () {
            Navigator.of(ctx).pop();
          },
        ),
      ],
    ),
  );
}

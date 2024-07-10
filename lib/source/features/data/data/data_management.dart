import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

//import 'package:hive/hive.dart';

import 'package:terra_trace/source/features/data/domain/flux_data.dart';
import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';


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
  print('SearchValueNotifier working');
  return SearchValueNotifier();
});

final searchValueProvider =
    StateNotifierProvider<SearchValueNotifier, String>((ref) {
  return SearchValueNotifier();
});

//Providers that are set for set up when project is created.. Usually do not change much
final isRemoteProvider = StateProvider<bool>((ref) => false);
final browseFilesProvider = StateProvider<bool>((ref) => false);

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
    await for (final dataList in projectManager.fluxDataListStream) {
      print('DataList length: ${dataList.length}');
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
      print(fluxData.dataCflux);
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



// --_-_Section for Mock Data:: !!! ...............................................................................................................
// --_-_Section for Mock Data:: !!!...      .,....  



// // Define a StateNotifier to manage the FluxData list
// class FluxMockDataNotifier extends StateNotifier<List<FluxData>> {
//   FluxMockDataNotifier() : super([]);

//   void addData(FluxData data) {
//     state = [...state, data];
//   }
// }

// // Create a provider for FluxDataNotifier
// final fluxMockDataNotifierProvider = StateNotifierProvider<FluxMockDataNotifier, List<FluxData>>((ref) {
//   return FluxMockDataNotifier();
// });

// // Function to generate mock FluxData
// FluxData generateMockFluxData(int index) {
//   final random = Random();
//   final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  
//   double randomLat = 52.0 + random.nextDouble() * 2; // Brandenburg latitude range
//   double randomLong = 12.0 + random.nextDouble() * 2; // Brandenburg longitude range
//   double randomTemp = 15.0 + random.nextDouble() * 10; // Temperature range 15-25 degrees Celsius
//   double randomPress = 1000.0 + random.nextDouble() * 20; // Pressure range 1000-1020 hPa
//   double randomCflux = random.nextDouble() * 10; // Cflux range 0-10
//   double randomSoilTemp = 10.0 + random.nextDouble() * 10; // Soil temperature range 10-20 degrees Celsius
//   double randomCfluxGram = random.nextDouble() * 5; // CfluxGram range 0-5

//   return FluxData(
//     dataSite: 'Site ${index + 1}',
//     dataLong: randomLong.toString(),
//     dataLat: randomLat.toString(),
//     dataTemp: randomTemp.toStringAsFixed(2),
//     dataPress: randomPress.toStringAsFixed(2),
//     dataCflux: randomCflux.toStringAsFixed(2),
//     dataDate: dateFormat.format(DateTime.now().subtract(Duration(days: random.nextInt(30)))),
//     dataKey: 'key_$index',
//     dataNote: 'Note ${index + 1}',
//     dataSoilTemp: randomSoilTemp.toStringAsFixed(2),
//     dataInstrument: 'Instrument ${random.nextInt(10)}',
//     dataCfluxGram: randomCfluxGram.toStringAsFixed(2),
//     dataOrigin: 'Origin ${random.nextInt(5)}',
//   );
// }

// DateFormat(String s) {
// }

// // Stream controller for emitting FluxData
// final StreamController<FluxData> _fluxMockDataController = StreamController<FluxData>.broadcast();

// // StreamProvider for the FluxData stream
// final fluxDataListProvider = StreamProvider<List<FluxData>>((ref) {
//   ref.onDispose(() {
//     _fluxMockDataController.close();
//   });

//   // Listen to the FluxDataNotifier and add data to the stream
//   final fluxMockDataNotifier = ref.watch(fluxMockDataNotifierProvider.notifier);
//   fluxMockDataNotifier.addListener((state) {
//     state.forEach((data) {
//       _fluxMockDataController.add(data);
//     });
//   });

//   return _fluxMockDataController.stream.map((event) => ref.read(fluxMockDataNotifierProvider));
// });

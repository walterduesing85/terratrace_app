import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';

class DataExport {
  DataExport(this.fileName);

  final String fileName;

  List<String> rows = [];

  List<List<String>> fluxListData = [];

  Future<String> createCSV(List<FluxData> fluxDataList) async {
    int num = fluxDataList.length;
    fluxListData = [];
    fluxListData.add([
      'Site',
      'Latitude',
      'Longitude',
      'Temperature',
      'Pressure',
      'CO2 flux [ppm]',
      'Soil Temperature [°]',
      'Comment',
      'Instrument',
      'Date',
      'flux[g/m2/d]',
      'data quality'
    ]);
    for (int k = 0; k < num; k++) {
      rows = [];
      rows.add(fluxDataList[k].dataSite!);
      rows.add(fluxDataList[k].dataLat!);
      rows.add(fluxDataList[k].dataLong!);
      rows.add(fluxDataList[k].dataTemp!);
      rows.add(fluxDataList[k].dataPress!);
      rows.add(fluxDataList[k].dataCflux!);
      rows.add(fluxDataList[k].dataSoilTemp!);
      rows.add(fluxDataList[k].dataNote!);
      rows.add(fluxDataList[k].dataInstrument!);
      rows.add(fluxDataList[k].dataDate!);
      rows.add(fluxDataList[k].dataCfluxGram!);
      rows.add(fluxDataList[k].dataOrigin!);

      fluxListData.add(rows);
    }
    String dataTable = ListToCsvConverter().convert(fluxListData);

    return dataTable;
  }

/// Gets the local storage path in a cross-compatible way
  Future<String> get _localPath async {
   
    
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory != null) {
      final storageDir = Directory('${directory.path}/terratrace/data/');
      await storageDir.create(recursive: true);
      return storageDir.path;
    } else {
      throw Exception("Could not get storage directory");
    }
  }

  Future<String> get _fileName async {
    return fileName;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    final fileName = await _fileName;

    return File('$path/$fileName.txt');
  }

  Future<File> createFile() async {
    final Future<File> testFile =
        File('storage/emulated/0/terratrace/data/').create();
    return testFile;
  }

  Future<String> readCounter() async {
    try {
      final file = await _localFile;

      // Read the file
      String contents = await file.readAsString();

      return contents;
    } catch (e) {
      // If encountering an error, return 0

      return 'no data found';
    }
  }

  Future<File> writeTable(String dataTable) async {
    final file = await _localFile;

    return file.writeAsString(dataTable);
  }

  Future<void> saveData(List<FluxData> fluxDataList) async {
    String dataTable = await createCSV(fluxDataList);
    writeTable(dataTable);
  }
}

// final dataExportProvider = Provider<DataExport>((ref) {
//   return DataExport();
// });

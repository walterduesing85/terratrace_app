import 'dart:io';

import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';

class DataExport {
  DataExport(this.fileName);

  final String fileName;

  List<String> rows = [];

  List<List<String>> fluxListData = [];
  Future<void> getPermission() async {
    var status = await Permission.storage.status;
    if (status.isDenied) {
      // You can request multiple permissions at once.
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
      ].request();
      print(statuses[
          Permission.storage]); // it should print PermissionStatus.granted
    }
  }

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

      fluxListData.add(rows);
    }
    String dataTable = ListToCsvConverter().convert(fluxListData);

    return dataTable;
  }

  Future<String> get _localPath async {
    await getPermission();
    // final Directory directoryFolder = Directory('${directory.path}/data/');
    final Directory directoryFolder =
        Directory('storage/emulated/0/terratrace/data/');
    final directoryNewFolder = await directoryFolder.create(recursive: true);

    return directoryNewFolder.path;
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

  Future<File> writeCounter(String dataTable) async {
    final file = await _localFile;

    return file.writeAsString(dataTable);
  }

  Future<void> saveData(List<FluxData> fluxDataList) async {
    String dataTable = await createCSV(fluxDataList);
    writeCounter(dataTable);
  }
}

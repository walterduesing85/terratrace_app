import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
// import 'package:share_plus/share_plus.dart';
// import 'utils.dart';

Future<String> exportFirestoreToCSV(String projectName) async {
  String jsonString = await rootBundle.loadString('assets/mbus.json');
  Map<String, dynamic> jsonData = jsonDecode(jsonString);

  final collection = FirebaseFirestore.instance
      .collection('projects')
      .doc(projectName)
      .collection("data");
  final snapshot = await collection.get();
  final docs = snapshot.docs;

  // Sort the documents based on 'dataPoint' field after converting it to integer
  docs.sort((a, b) {
    // Convert 'dataPoint' to integer for sorting
    int dataPointA = int.tryParse(a.data()['dataPoint'] ?? '0') ?? 0;
    int dataPointB = int.tryParse(b.data()['dataPoint'] ?? '0') ?? 0;
    return dataPointA.compareTo(dataPointB);
  });

  final mbusDoc = await FirebaseFirestore.instance
      .collection('projects')
      .doc(projectName)
      .get();
  final mbus = mbusDoc.data()!['mbus'];

  // Create a list to hold the headers (field names that match the filter).
  List<String> headers = [
    "Date",
    "Time",
    "Project ID",
    "Site",
    "Sampling #",
    "Latitude [°]",
    "Longitude [°]",
    "UTM easting",
    "UTM Northing",
    "Zone",
    "EPSG",
    "Position Error [m]",
  ];

  List<String> headersFirestore = [
    "dataDate",
    "dataDate",
    "Project ID",
    "dataSite",
    "dataPoint",
    "dataLat",
    "dataLong",
    "dataEasting",
    "dataNorthing",
    "dataZone",
    "dataEPSG",
    "dataLocationAccuracy",
  ];

  // Create number formatter for CH4 values
  NumberFormat formatter = NumberFormat("0.000E+0", "en_US");

  // Iterate through each device name in mbus
  for (var deviceName in mbus) {
    if (jsonData.containsKey(deviceName)) {
      // Get the list of parameters for the device
      var parameters = jsonData[deviceName];

      // Filter the parameters by Class "FLX" or "EPV"
      for (var param in parameters) {
        final paramFirestore =
            '${param["Name"]}${deviceName.replaceAll("Terratrace", "")}';
        if (param['Class'] == 'FLX') {
          // Add the matching parameter to the filtered list
          headers.add('${param["Name"]} Flux [moles/(m2*day)]');
          headers.add('${param["Name"]} Slope [ppm/sec]');
          headers.add('${param["Name"]} r2');
          headers.add('${param["Name"]} Flux error [%]');

          headersFirestore.add('${paramFirestore}FluxMoles');
          headersFirestore.add('${paramFirestore}Slope');
          headersFirestore.add('${paramFirestore}RSquared');
          headersFirestore.add('${paramFirestore}FluxError');
        }
        if (param['Class'] == 'EPV') {
          headers.add('${param["Name"]} Average [${param["Unit"]}]');
          headers.add('${param["Name"]} Max [${param["Unit"]}]');
          headers.add('${param["Name"]} Min [${param["Unit"]}]');
          headers.add('${param["Name"]} Std.Dev. [${param["Unit"]}]');

          headersFirestore.add('${paramFirestore}Avg');
          headersFirestore.add('${paramFirestore}Max');
          headersFirestore.add('${paramFirestore}Min');
          headersFirestore.add('${paramFirestore}Std');
        }
      }
    }
  }

  // Create a list to hold all CSV rows.
  List<List<dynamic>> rows = [];

  // First row: header columns.
  rows.add(headers);

  // Iterate through each document to collect the data.
  for (var doc in docs) {
    Map<String, dynamic> data = doc.data();
    List<dynamic> row = [];

    // Add basic fields
    for (var i = 0; i < 12; i++) {
      row.add(data[headersFirestore[i]] ?? '');
    }

    // Process date/time
    String tempDateStr = data['dataDate'] ?? '';
    DateTime dateTime;
    try {
      dateTime = DateTime.parse(tempDateStr);
    } catch (e) {
      dateTime = DateTime.now();
    }
    String formattedDate = DateFormat('dd-MM-yyyy').format(dateTime);
    String formattedTime = DateFormat('HH:mm:ss').format(dateTime);
    row[0] = formattedDate;
    row[1] = formattedTime;
    row[2] = projectName;

    // Add FLX and EPV parameter values
    for (var deviceName in mbus) {
      if (jsonData.containsKey(deviceName)) {
        var parameters = jsonData[deviceName];
        for (var param in parameters) {
          final paramFirestore =
              '${param["Name"]}${deviceName.replaceAll("Terratrace", "")}';
          if (param['Class'] == 'FLX') {
            // Format CH4 values using scientific notation
            if (param["Name"] == "CH4") {
              row.addAll([
                formatter.format(data['${paramFirestore}FluxMoles'] ?? 0),
                formatter.format(data['${paramFirestore}Slope'] ?? 0),
                data['${paramFirestore}RSquared'] ?? '',
                data['${paramFirestore}FluxError'] ?? '',
              ]);
            } else {
              row.addAll([
                data['${paramFirestore}FluxMoles'] ?? '',
                data['${paramFirestore}Slope'] ?? '',
                data['${paramFirestore}RSquared'] ?? '',
                data['${paramFirestore}FluxError'] ?? '',
              ]);
            }
          }
          if (param['Class'] == 'EPV') {
            row.addAll([
              data['${paramFirestore}Avg'] ?? '',
              data['${paramFirestore}Max'] ?? '',
              data['${paramFirestore}Min'] ?? '',
              data['${paramFirestore}Std'] ?? '',
            ]);
          }
        }
      }
    }
    rows.add(row);
  }

  // Convert the rows to a CSV formatted string.
  String csvData = const ListToCsvConverter().convert(rows);

  // Determine a path to save the CSV file.
  Directory directory = Directory('/storage/emulated/0/Documents');
  final path = '${directory.path}/BTLE_Parameters_Summary($projectName).csv';
  final file = File(path);
  await file.writeAsString(csvData);

  print('CSV file exported to: $path');
  return path;
}

// download all files related to the project (txt files and csv)
Future<String> zipFilesContainingProjectName(String projectName) async {
  // Define the directory you want to scan.
  final Directory directory = Directory('/storage/emulated/0/Documents');

  // Define where you want to save the zip file.
  final String zipFilePath =
      '/storage/emulated/0/Documents/${projectName}_files.zip';
  final File zipFile = File(zipFilePath);

  // Create an archive object to hold our files.
  final Archive archive = Archive();

  // List all files in the directory (recursively, if needed)
  final List<FileSystemEntity> files = directory.listSync(recursive: true);

  for (var entity in files) {
    // Ensure we're processing only files.
    if (entity is File) {
      // Check if the file path or name contains the specified projectName.
      if (entity.path.contains(projectName)) {
        // Read the file contents.
        final List<int> fileBytes = await entity.readAsBytes();
        // Get a relative path for the file (optional but useful for preserving folder structure in the zip).
        final String relativePath =
            entity.path.replaceFirst(directory.path, '');
        // Add the file to the archive.
        archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
      }
    }
  }

  // Encode the archive as a zip file.
  final List<int> zipData = ZipEncoder().encode(archive);

  // Write the zip data to a file.
  await zipFile.writeAsBytes(zipData);

  print('Zip file created at: $zipFilePath');
  return zipFilePath;
}

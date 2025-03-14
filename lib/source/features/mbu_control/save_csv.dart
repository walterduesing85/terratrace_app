import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
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
  // // Sort docs by "dataPoint" (convert to integer)
  // docs = docs.sort((a, b) {
  //   var aValue = a.data()["dataPoint"];
  //   var bValue = b.data()["dataPoint"];

  //   // Convert to integer if possible
  //   int aInt = int.tryParse(aValue ?? '') ?? 0;
  //   int bInt = int.tryParse(bValue ?? '') ?? 0;

  //   return aInt.compareTo(bInt); // Ascending order based on integer value
  // });

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
    // For each header (i.e. field), add the document value or empty string if missing.
    for (var header in headersFirestore) {
      row.add(data[header] ?? '');
    }
    final tempData = row[0];
    // Parse the date-time string into a DateTime object.
    DateTime dateTime = DateTime.parse(tempData);

    // Format the date part (dd-MM-yyyy).
    String formattedDate = DateFormat('dd-MM-yyyy').format(dateTime);

    // Format the time part (HH:mm:ss.sss).
    String formattedTime = DateFormat('HH:mm:ss').format(dateTime);
    row[0] = formattedDate;
    row[1] = formattedTime;
    row[2] = projectName;
    rows.add(row);
  }

  // Convert the rows to a CSV formatted string.
  String csvData = const ListToCsvConverter().convert(rows);

  // Determine a path to save the CSV file.
  Directory directory = Directory('/storage/emulated/0/Documents');
  final path = '${directory.path}/BTLEParametersandSummary($projectName).csv';
  final file = File(path);
  await file.writeAsString(csvData);

  print('CSV file exported to: $path');
  return path;
}

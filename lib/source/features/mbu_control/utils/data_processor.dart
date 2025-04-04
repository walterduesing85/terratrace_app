import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataProcessor {
  static final NumberFormat _formatter = NumberFormat("0.000E+0", "en_US");

  static Future<Map<String, dynamic>> loadDeviceDefinitions() async {
    String jsonString = await rootBundle.loadString('assets/mbus.json');
    return jsonDecode(jsonString);
  }

  static List<String> buildHeaders(
      List<String> mbus, Map<String, dynamic> jsonData) {
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

    for (var deviceName in mbus) {
      if (jsonData.containsKey(deviceName)) {
        var parameters = jsonData[deviceName] as List<dynamic>;
        for (var param in parameters) {
          if (param['Class'] == 'FLX') {
            headers.addAll([
              '${param["Name"]} Flux [moles/(m2*day)]',
              '${param["Name"]} Slope [ppm/sec]',
              '${param["Name"]} r2',
              '${param["Name"]} Flux error [%]',
            ]);
          }
          if (param['Class'] == 'EPV') {
            headers.addAll([
              '${param["Name"]} Average [${param["Unit"]}]',
              '${param["Name"]} Max [${param["Unit"]}]',
              '${param["Name"]} Min [${param["Unit"]}]',
              '${param["Name"]} Std.Dev. [${param["Unit"]}]',
            ]);
          }
        }
      }
    }
    return headers;
  }

  static List<String> buildFirestoreHeaders(
      List<String> mbus, Map<String, dynamic> jsonData) {
    List<String> headers = [
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

    for (var deviceName in mbus) {
      if (jsonData.containsKey(deviceName)) {
        var parameters = jsonData[deviceName];
        for (var param in parameters) {
          final paramFirestore =
              '${param["Name"]}${deviceName.replaceAll("Terratrace", "")}';
          if (param['Class'] == 'FLX') {
            headers.addAll([
              '${paramFirestore}FluxMoles',
              '${paramFirestore}Slope',
              '${paramFirestore}RSquared',
              '${paramFirestore}FluxError',
            ]);
          }
          if (param['Class'] == 'EPV') {
            headers.addAll([
              '${paramFirestore}Avg',
              '${paramFirestore}Max',
              '${paramFirestore}Min',
              '${paramFirestore}Std',
            ]);
          }
        }
      }
    }
    return headers;
  }

  static List<dynamic> processRowData(
    Map<String, dynamic> data,
    String projectName,
    List<String> mbus,
    Map<String, dynamic> jsonData,
  ) {
    List<dynamic> row = [];

    // Add basic fields
    for (var i = 0; i < 12; i++) {
      row.add(data[buildFirestoreHeaders(mbus, jsonData)[i]] ?? '');
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
            if (param["Name"] == "CH4") {
              row.addAll([
                _formatter.format(data['${paramFirestore}FluxMoles'] ?? 0),
                _formatter.format(data['${paramFirestore}Slope'] ?? 0),
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
    return row;
  }

  static List<QueryDocumentSnapshot> sortDocuments(
      List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
      Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
      int dataPointA = int.tryParse(dataA['dataPoint']?.toString() ?? '0') ?? 0;
      int dataPointB = int.tryParse(dataB['dataPoint']?.toString() ?? '0') ?? 0;
      return dataPointA.compareTo(dataPointB);
    });
    return docs;
  }
}

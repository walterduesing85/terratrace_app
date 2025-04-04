import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
// import 'package:terratrace/source/common_widgets/custom_appbar.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'stats_func.dart';
import 'dart:io';
// import 'utils.dart';
import 'package:terratrace/source/features/mbu_control/widgets/chart_widgets.dart';
// import 'chart_menu.dart';
// import 'package:go_router/go_router.dart';
// import 'package:terratrace/source/routing/app_router.dart';

class ReselectScreen extends StatefulWidget {
  final String? project;
  final String? samplingPoint;
  const ReselectScreen(
      {required this.project, required this.samplingPoint, Key? key})
      : super(key: key);
  @override
  _ReselectScreenState createState() => _ReselectScreenState();
}

class _ReselectScreenState extends State<ReselectScreen> {
  // BluetoothDevice? connectedDevice;

  // List<BluetoothService> services = [];
  // Map<Guid, List<int>> readValues = {};
  final Map<String, List<Map<String, dynamic>>> collectedData = {};

  // These boundaries are expressed in pixel offsets relative to the chart's width.
  double leftBoundary = 40.0;
  double rightBoundary = 350.0;
  double chartWidth = 1.0;

  int indexLeftBoundary = 0;
  int indexRightBoundary = 0;

  // Regression results
  double slope = 0.0;
  double rSquared = 0.0;
  double flux = 0.0;
  double fluxError = 0.0;

  double chamberDiameter = 0.2;
  double chamberHeight = 0.1;
  double avgPressure = 1013.25;
  double avgTemp = 20;

  // A minimum separation (in pixels) between handles
  final double minHandleSeparation = 20.0;
  // Handle width for display purposes
  final double handleWidth = 16.0;

  List<FlSpot> slopeLinePoints = [];

  // Subscription to track the connected device's state.
  // StreamSubscription<BluetoothConnectionState>? deviceStateSubscription;
  List<BluetoothDevice> connectedDevices = [];
  Map<String, StreamSubscription<BluetoothConnectionState>>
      deviceStateSubscriptions = {};
  Map<String, List<BluetoothService>> deviceServices = {};
  Map<String, Map<Guid, dynamic>> readValues = {};

  Map<String, List<String>> deviceParametersMap =
      {}; // All parameters per device.
  Map<String, Map<String, List<double>>> deviceR2SlopeMap =
      {}; // Boundaries per parameter, per device.
  Map<String, List<String>> deviceFlxParamsMap =
      {}; // FLX parameters per device.
  // Temporary map for unique uuid mappings from Char -> Name
  Map<String, String> unitMap = {};
  Map<String, String> formatMap = {};

  String selectedParameter = "";
  late NumberFormat formatter;
  // late String trimmedSelectedParameter;
  List<FlSpot> dataPoints = [];
  String selectedParamDevice = "";

  bool isLoading = true;
  late Map<String, dynamic>? projectData;
  String currentSamplingPoint = "1";
  int totalSamplingPoints = 0;
  bool hasCalculatedSlope = false;
  Set<String> visitedParameters = {}; // Track visited parameters
  bool isAllParametersVisited =
      false; // Track if all parameters have been visited

  @override
  void initState() {
    super.initState();
    print("initState called");
    currentSamplingPoint = widget.samplingPoint ?? "1";
    _updatePlot();
    _getTotalSamplingPoints();
  }

  Future<void> _updatePlot() async {
    try {
      String jsonString = await rootBundle.loadString('assets/mbus.json');
      Map<String, dynamic> jsonData = jsonDecode(jsonString);

      Map<String, String> tempFormatMap = {};
      Map<String, String> tempUnitMap = {};
      Map<String, List<String>> tempDeviceFlxParamsMap = {};
      Map<String, List<String>> tempDeviceParametersMap = {};

      final collection = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project)
          .collection("data")
          .doc(currentSamplingPoint)
          .get();

      if (!collection.exists) {
        throw Exception('Document does not exist');
      }

      final data = collection.data();
      if (data == null) {
        throw Exception('No data found');
      }

      setState(() {
        projectData = data;
      });

      final mbus = projectData!["dataInstrument"];

      // Clear existing data before loading new data
      collectedData.clear();
      dataPoints.clear();
      slopeLinePoints.clear();

      // Iterate through each device name in mbus
      for (var deviceName in mbus) {
        if (jsonData.containsKey(deviceName)) {
          var parameters = jsonData[deviceName];
          for (var param in parameters) {
            if (param['Class'] == 'FLX' //|| param['Class'] == 'EPV'
                ) {
              final paramFirestore =
                  '${param["Name"]}${deviceName.replaceAll("Terratrace", "")}';
              tempFormatMap[param["Name"]] = param["Format"];
              tempUnitMap[param["Name"]] = param["Unit"];
              tempDeviceParametersMap.putIfAbsent(deviceName, () => []);
              tempDeviceFlxParamsMap.putIfAbsent(deviceName, () => []);
              tempDeviceParametersMap[deviceName]!.add(param["Name"]);

              if (param['Class'] == 'FLX') {
                tempDeviceFlxParamsMap[deviceName]!.add(param["Name"]);
                deviceR2SlopeMap.putIfAbsent(deviceName, () => {});
                deviceR2SlopeMap[deviceName]!
                    .putIfAbsent(param["Name"], () => []);
                deviceR2SlopeMap[deviceName]![param["Name"]] = [
                  data['${paramFirestore}LeftBoundary'] ?? leftBoundary,
                  data['${paramFirestore}RightBoundary'] ?? rightBoundary,
                  data['${paramFirestore}Slope'] ?? 0,
                  data['${paramFirestore}RSquared'] ?? 0,
                  (data['${paramFirestore}LeftIndexBoundary'] ?? 0).toDouble(),
                  (data['${paramFirestore}RightIndexBoundary'] ?? 0).toDouble(),
                  data['${paramFirestore}FluxMoles'] ?? 0,
                  data['${paramFirestore}FluxError'] ?? 0,
                ];
              }

              if (paramFirestore.contains("Temperature")) {
                avgTemp = double.parse(data['${paramFirestore}Avg']);
              }
              if (paramFirestore.contains("Pressure")) {
                avgPressure = double.parse(data['${paramFirestore}Avg']);
              }

              final timeseriesSnapshot = await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.project)
                  .collection("time-series")
                  .doc(paramFirestore)
                  .collection(currentSamplingPoint)
                  .get();

              for (var doc in timeseriesSnapshot.docs) {
                var value = doc.data()['value'];
                var sec = doc.data()['elapsedTime'];

                collectedData.putIfAbsent(paramFirestore, () => []);
                collectedData[paramFirestore]!.add({
                  "value": value,
                  "sec": sec,
                });
              }
            }
          }
        }
      }

      // Update state with new maps
      setState(() {
        formatMap = tempFormatMap;
        unitMap = tempUnitMap;
        deviceParametersMap = tempDeviceParametersMap;
        deviceFlxParamsMap = tempDeviceFlxParamsMap;
      });

      // Find first available FLX parameter if none selected
      if (selectedParameter.isEmpty || selectedParamDevice.isEmpty) {
        for (var device in deviceParametersMap.keys) {
          for (var param in deviceParametersMap[device]!) {
            if (deviceFlxParamsMap[device]?.contains(param) == true) {
              setState(() {
                if (selectedParameter == "" && selectedParamDevice == "") {
                  selectedParameter = param;
                  selectedParamDevice = device;
                }
                formatter = NumberFormat(formatMap[selectedParameter], "en_US");
              });
              break;
            }
          }
          if (selectedParameter.isNotEmpty) break;
        }
      }

      // Update plot data
      if (selectedParameter.isNotEmpty) {
        String deviceParam =
            "$selectedParameter${selectedParamDevice.replaceAll('Terratrace', '')}";
        updatePlotData(deviceParam);
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error updating plot: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _getTotalSamplingPoints() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.project)
        .collection('data')
        .get();

    setState(() {
      totalSamplingPoints = snapshot.docs.length;
    });
  }

  Future<void> _navigateToSamplingPoint(String direction) async {
    // Save current data if slope was calculated and parameter is a FLX parameter
    if (hasCalculatedSlope &&
        deviceFlxParamsMap[selectedParamDevice]?.contains(selectedParameter) ==
            true) {
      await _saveData();
    }

    if (direction == 'right') {
      int currentPoint = int.parse(currentSamplingPoint);
      if (currentPoint < totalSamplingPoints) {
        // Reset state before loading new data
        setState(() {
          hasCalculatedSlope = false;
          collectedData.clear();
          dataPoints.clear();
          slopeLinePoints.clear();
          isLoading = true;
        });

        // Update sampling point
        setState(() {
          currentSamplingPoint = (currentPoint + 1).toString();
        });

        // Update plot with new data
        await _updatePlot();
      } else {
        // If we're at the last point, move to next parameter and reset to point 1
        // Only move to next parameter if current parameter is a FLX parameter
        if (deviceFlxParamsMap[selectedParamDevice]
                ?.contains(selectedParameter) ==
            true) {
          await _moveToNextParameter();

          // If all parameters have been visited, show completion message
          if (isAllParametersVisited) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'All sampling points for all flux parameters have been checked'),
                duration: Duration(seconds: 3),
              ),
            );
            // Don't change any state, just let the UI update to show disabled right arrow
          }
        } else {
          // For non-FLX parameters, just show a message that we're at the last point
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Last sampling point reached for this parameter'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else if (direction == 'left') {
      int currentPoint = int.parse(currentSamplingPoint);
      if (currentPoint > 1) {
        // Reset state before loading new data
        setState(() {
          hasCalculatedSlope = false;
          collectedData.clear();
          dataPoints.clear();
          slopeLinePoints.clear();
          isLoading = true;
        });

        // Update sampling point
        setState(() {
          currentSamplingPoint = (currentPoint - 1).toString();
        });

        // Update plot with new data
        await _updatePlot();
      }
    }
  }

  Future<void> _moveToNextParameter() async {
    // Find current parameter index
    int currentDeviceIndex =
        deviceParametersMap.keys.toList().indexOf(selectedParamDevice);
    int currentParamIndex =
        deviceParametersMap[selectedParamDevice]!.indexOf(selectedParameter);

    // Mark current parameter as visited
    // visitedParameters.add("$selectedParamDevice-$selectedParameter");
    visitedParameters.add("$selectedParamDevice-$selectedParameter");

    // Check if all FLX parameters have been visited
    bool allFlxParamsVisited = true;
    for (var device in deviceFlxParamsMap.keys) {
      for (var param in deviceFlxParamsMap[device]!) {
        if (!visitedParameters.contains("$device-$param")) {
          allFlxParamsVisited = false;
          break;
        }
      }
      if (!allFlxParamsVisited) break;
    }

    if (allFlxParamsVisited) {
      setState(() {
        isAllParametersVisited = true;
      });
      return;
    }

    // Clear current data before switching parameters
    setState(() {
      hasCalculatedSlope = false;
      collectedData.clear();
      dataPoints.clear();
      slopeLinePoints.clear();
      isLoading = true;
    });

    // Move to next parameter
    if (currentParamIndex <
        deviceParametersMap[selectedParamDevice]!.length - 1) {
      // Find next FLX parameter in current device
      bool foundNext = false;
      String? nextDevice;
      String? nextParameter;

      // First check remaining parameters in current device
      for (var i = currentParamIndex + 1;
          i < deviceParametersMap[selectedParamDevice]!.length;
          i++) {
        String param = deviceParametersMap[selectedParamDevice]![i];

        if (deviceFlxParamsMap[selectedParamDevice]!.contains(param) &&
            !visitedParameters.contains("$selectedParamDevice-$param")) {
          nextDevice = selectedParamDevice;
          nextParameter = param;
          print("CHEEEECK $nextDevice $nextParameter");
          setState(() {
            selectedParameter = nextParameter!;
            selectedParamDevice = nextDevice!;
            currentSamplingPoint = "1";
            formatter = NumberFormat(formatMap[selectedParameter], "en_US");
          });
          foundNext = true;
          await _updatePlot();
          break;
        }
      }
    } else {
      // Move to next device
      await _moveToNextDevice();
    }
  }

  Future<void> _moveToNextDevice() async {
    int currentDeviceIndex =
        deviceParametersMap.keys.toList().indexOf(selectedParamDevice);
    if (currentDeviceIndex < deviceParametersMap.keys.length - 1) {
      String nextDevice =
          deviceParametersMap.keys.elementAt(currentDeviceIndex + 1);

      // Find first FLX parameter in next device
      bool foundNext = false;
      for (var param in deviceParametersMap[nextDevice]!) {
        if (deviceFlxParamsMap[nextDevice]!.contains(param)) {
          setState(() {
            selectedParamDevice = nextDevice;
            selectedParameter = param;
            currentSamplingPoint = "1";
          });
          foundNext = true;
          await _updatePlot();
          break;
        }
      }

      if (!foundNext) {
        // No FLX parameters in next device, try next device
        await _moveToNextDevice();
      }
    }
  }

// Function to refresh the plot when switching parameters
  void updatePlotData(String deviceParam) {
    setState(() {
      // Create a new list reference for dataPoints
      List<FlSpot> newPoints = [];
      if (collectedData.containsKey(deviceParam)) {
        List<Map<String, dynamic>> allData = collectedData[deviceParam]!;
        if (allData.isNotEmpty) {
          // Process and sort the data points.
          for (var point in allData) {
            double timeInSeconds = double.parse(point["sec"]);
            newPoints.add(FlSpot(timeInSeconds, point["value"]));
          }
          newPoints.sort((a, b) => a.x.compareTo(b.x));
        }
      }
      dataPoints = newPoints; // update the reference
      if (deviceR2SlopeMap.containsKey(selectedParamDevice) &&
          deviceR2SlopeMap[selectedParamDevice]!
              .containsKey(selectedParameter) &&
          deviceR2SlopeMap[selectedParamDevice]![selectedParameter]!.length >=
              2) {
        leftBoundary = deviceR2SlopeMap[selectedParamDevice]![
            selectedParameter]![0]; // Saved left boundary
        rightBoundary = deviceR2SlopeMap[selectedParamDevice]![
            selectedParameter]![1]; // Saved right boundary
        slope = deviceR2SlopeMap[selectedParamDevice]![selectedParameter]![2];
        rSquared =
            deviceR2SlopeMap[selectedParamDevice]![selectedParameter]![3];
        indexLeftBoundary =
            deviceR2SlopeMap[selectedParamDevice]![selectedParameter]![4]
                .toInt();
        indexRightBoundary =
            deviceR2SlopeMap[selectedParamDevice]![selectedParameter]![5]
                .toInt();
        flux = deviceR2SlopeMap[selectedParamDevice]![selectedParameter]![6];
        fluxError =
            deviceR2SlopeMap[selectedParamDevice]![selectedParameter]![7];
      }
    });
  }

  void saveParameterValues(String deviceName) {
    if (deviceFlxParamsMap[selectedParamDevice]!.contains(selectedParameter)) {
      if (!deviceR2SlopeMap.containsKey(deviceName)) {
        deviceR2SlopeMap[deviceName] = {}; // Initialize if not present
      }

      deviceR2SlopeMap[deviceName]![selectedParameter] = [
        leftBoundary,
        rightBoundary,
        slope,
        rSquared,
        indexLeftBoundary.toDouble(),
        indexRightBoundary.toDouble(),
        flux,
        fluxError
      ];
    }
  }

  /// Convert boundary positions into data indices and calculate regression
  void dynamicSlopeAndRSquared(String deviceName) {
    if (dataPoints.isEmpty) return;
    print(
        "Chart width: $chartWidth, Left: $leftBoundary, Right: $rightBoundary");
    // Convert boundary positions (px) to index range
    int startIndex = ((leftBoundary / chartWidth) * dataPoints.length).floor();
    int endIndex = ((rightBoundary / chartWidth) * dataPoints.length).ceil();

    // Ensure indices are within valid range
    startIndex = startIndex.clamp(0, dataPoints.length - 1);
    endIndex = endIndex.clamp(0, dataPoints.length - 1);
    print(
        "Start Index: $startIndex, End Index: $endIndex, Total: ${dataPoints.length}");

    // Need at least 2 points for regression
    if (endIndex - startIndex < 1) {
      print("Not enough data points for regression.");
      setState(() {
        slope = 0.0;
        rSquared = 0.0;
        indexLeftBoundary = startIndex;
        indexRightBoundary = endIndex;
        fluxError = 0.0;
      });
      saveParameterValues(deviceName);
      return;
    }

    // Extract subset of selected points
    List<FlSpot> subset = dataPoints.sublist(startIndex, endIndex + 1);
    int n = subset.length;

    // Summation variables for linear regression
    double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0, sumY2 = 0.0;

    for (var point in subset) {
      sumX += point.x;
      sumY += point.y;
      sumXY += point.x * point.y;
      sumX2 += point.x * point.x;
      sumY2 += point.y * point.y;
    }

    // Calculate slope (m)
    double denominator = (n * sumX2) - (sumX * sumX);
    double m =
        (denominator != 0) ? ((n * sumXY) - (sumX * sumY)) / denominator : 0.0;

    // Compute correlation coefficient (r)
    double numerator = (n * sumXY) - (sumX * sumY);
    double denominatorR =
        sqrt(((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)));
    double r = (denominatorR != 0) ? numerator / denominatorR : 0.0;

    // Compute R²
    double rSquaredCalculated = r * r;

    final dataset = collectedData[
        "$selectedParameter-${selectedParamDevice.replaceAll("Terratrace-", "")}"];
    final error = calculateSlopesAndStdDev(dataset, startIndex, endIndex);

    // Update UI
    setState(() {
      slope = double.parse(m.toStringAsFixed(2));
      rSquared = double.parse(rSquaredCalculated
          .toStringAsFixed(selectedParameter == "CH4" ? 4 : 2));

      indexLeftBoundary = startIndex;
      indexRightBoundary = endIndex;
      flux = selectedParameter == "CH4"
          ? (86400 * avgPressure * 100 * slope * chamberHeight) /
              (1000000 * gasConstant * (avgTemp + 273.15))
          : double.parse(((86400 * avgPressure * 100 * slope * chamberHeight) /
                  (1000000 * gasConstant * (avgTemp + 273.15)))
              .toStringAsFixed(3));

      fluxError = slope == 0
          ? 0
          : double.parse(
              ((error["stdDeviation"]! / m) * 100).toStringAsFixed(1));

      // Define start and end points for the slope line
      double xStart = subset.first.x;
      double yStart = subset.first.y;
      double xEnd = subset.last.x;
      double yEnd = yStart + m * (xEnd - xStart);

      slopeLinePoints = [
        FlSpot(xStart, yStart),
        FlSpot(xEnd, yEnd),
      ];
      hasCalculatedSlope = true; // Set this flag when slope is calculated
    });
    saveParameterValues(deviceName);
    print("Slope: $slope, R²: $rSquared, FluxError: $fluxError");
  }

  // Function to calculate Y-axis step size based on min and max values
  double calculateStepSize(double minY, double maxY) {
    double dY = maxY - minY;
    double step = dY / 10;

    // Round to the nearest 0.1 if dY < 1
    if (dY < 1) {
      step = (step * 10).ceil() / 10.0;
    }
    // Round to the nearest integer if dY < 10
    else if (dY < 10) {
      step = step.ceilToDouble();
    }
    // Otherwise, round to the nearest multiple of 10
    else {
      step = (step / 10).ceil() * 10.0;
    }

    return step;
  }

// // Function to format Y-axis labels
//   String formatYAxisLabel(double value, double stepSize) {
//     if (stepSize >= 10) {
//       return value.toStringAsFixed(0); // No decimals
//     } else {
//       return value.toStringAsFixed(2); // Two decimal places
//     }
//   }

  Future<String> _saveData() async {
    Map<String, dynamic> dataMap = {};

    // if (collectedData.isEmpty || widget.samplingPoint!.isEmpty) {
    //   print("Incomplete data");
    //   return;
    // }

    // final directory = await getApplicationDocumentsDirectory();
    Directory directory = Directory('/storage/emulated/0/Documents');
    final filePath =
        '${directory.path}/${widget.project}_Sampling#${currentSamplingPoint}.txt';
    final file = File(filePath);
    print("FILEPATH: $filePath");

    // Build the dataMap with all the required fields.

    // Header
    String header = """
TIME:\t${projectData!["dataDate"]}
SITE:\t${projectData!["dataSite"]}
POINT:\t${currentSamplingPoint}
LONGITUDE:\t${projectData!["dataLong"]}
LATITUDE:\t${projectData!["dataLat"]}
EASTING:\t${projectData!["dataEasting"]}
NORTHING:\t${projectData!["dataNorthing"]}
ZONE:\t${projectData!["dataZone"]}
HEMISPHERE:\t${projectData!["dataHemisphere"]}
EPSG:\t${projectData!["dataEPSG"]}
LOCATION ACCURACY:\t${projectData!["dataLocationAccuracy"]} meters

NOTE:\t${projectData!["dataNote"]}

PARAMETER ANALYSIS
""";

    // Initialize rows
    List<String> rows = [];

    final db = FirebaseFirestore.instance;

    // Loop through each parameter in collectedData
    await Future.forEach(collectedData.entries,
        (MapEntry<String, List<Map<String, dynamic>>> entry) async {
      final param = entry.key;
      final data = entry.value;
      // Create a reference to the subcollection for the current parameter

      // Add parameter-specific table header
      String paramHeader = "\n$param:\n#\tTIME (sec)\t$param\n";

      // Populate rows for this parameter
      await Future.wait(data.asMap().entries.map((mapEntry) async {
        final i = mapEntry.key;
        // double value = data[i]["value"].toDouble();

        // Build row for the parameter
        String row = "${i + 1}\t${data[i]["sec"]}\t${data[i]["value"]}";
        paramHeader += row + "\n";
      }));
      if (!deviceFlxParamsMap[
              "Terratrace-${param.split('-').skip(1).join('-')}"]!
          .contains(param.split("-")[0])) {
        header += "$param:\n";
        header += "  MIN: ${projectData!["${param}Min"]}\n";
        header += "  MAX: ${projectData!["${param}Max"]}\n";
        header += "  AVG: ${projectData!["${param}Avg"]}\n";
        header += "  STD.DEV.: ${projectData!["${param}Std"]}\n\n";
      }
      // Add the parameter table to the content
      rows.add(paramHeader);
    });

    // Adding R² and slope for each parameter in r2SlopeMap
    deviceR2SlopeMap.forEach((device, parameters) {
      parameters.forEach((param, values) {
        if (values.length >= 4) {
          double leftBound = values[0];
          double rightBound = values[1];
          double rSquared = values[3];
          double slope = values[2];
          int leftIndex = values[4].toInt();
          int rightIndex = values[5].toInt();
          // var dataForIndex =
          //     collectedData["$param${device.replaceAll("Terratrace", "")}"];

          double fluxInMoles = values[6];
          double fluxError = values[7];
          double fluxInGrams = fluxInMoles * molarMassCO2;
          String prefix = "$param-${device.replaceAll("Terratrace-", "")}";

          // var errorSlope =
          //     calculateSlopesAndStdDev(dataForIndex, leftIndex, rightIndex);
          // double fluxError = (errorSlope["stdDeviation"]! /
          //         errorSlope["wholeIntervalSlope"]!) *
          //     100;

          header += "$prefix:\n";
          header += "  Left Boundary: $leftIndex\n";
          header += "  Right Boundary: $rightIndex\n";
          header += "  R²: ${rSquared.toStringAsFixed(2)}\n";
          header += "  Slope: ${slope.toStringAsFixed(2)}\n";
          header +=
              "  Flux [moles/(m2*day)]: ${fluxInMoles.toStringAsFixed(2)}\n";
          header += "  Flux [g/(m2*day)]: ${fluxInGrams.toStringAsFixed(2)}\n";
          header += "  Flux Error [%]: ${fluxError.toStringAsFixed(2)}\n\n";

          dataMap['${prefix}LeftBoundary'] = leftBound;
          dataMap['${prefix}RightBoundary'] = rightBound;
          dataMap['${prefix}RSquared'] = rSquared;
          dataMap['${prefix}Slope'] = slope;
          dataMap['${prefix}FluxMoles'] = fluxInMoles;
          dataMap['${prefix}FluxGrams'] = fluxInGrams;
          dataMap['${prefix}FluxError'] = fluxError;
          dataMap['${prefix}LeftIndexBoundary'] = leftIndex;
          dataMap['${prefix}RightIndexBoundary'] = rightIndex;
        }
      });
    });

    // Create a new document in the 'data' subcollection of the project document.
    DocumentReference dataDocRef = db
        .collection('projects')
        .doc(widget.project)
        .collection('data')
        .doc(currentSamplingPoint);
    // Save the entire dataMap to the document in the 'data' subcollection.
    await dataDocRef.update(dataMap);

    header += "FLUX RECORD TRACKS\n";

// Combine header and all rows (separate tables for each parameter)
    String content = header + rows.join("\n");

// Write the content to the file
    await file.writeAsString(content);
    print('Data saved to $filePath');
    return filePath;
    // collectedData.clear();
  }

  void showDownloadMessage(BuildContext context) {
    final snackBar = SnackBar(
      content: Text('File has been downloaded!'),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Loading..."),
          // backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
        ),
        body: Center(child: CircularProgressIndicator()),
        // backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
      );
    }

    // Calculate minY, maxY, and stepSize for the chart
    double minY = dataPoints.isNotEmpty
        ? dataPoints.map((e) => e.y).reduce((a, b) => a < b ? a : b)
        : 0.0;

    double maxY = dataPoints.isNotEmpty
        ? dataPoints.map((e) => e.y).reduce((a, b) => a > b ? a : b)
        : 1.0;

    double stepSize = calculateStepSize(minY, maxY);

    return Scaffold(
        // backgroundColor: const Color.fromARGB(255, 95, 98, 106),
        appBar: AppBar(
          toolbarHeight: 80,
          title: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align text to the left
            mainAxisSize:
                MainAxisSize.min, // Ensures the column takes minimal height
            children: [
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align text to the left
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Sampling #${currentSamplingPoint}",
                    style: TextStyle(
                        // color: Color(0xFFAEEA00),
                        color: kGreenFluxColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                      height: 2), // Small spacing between title and subtitle
                  Text(
                    "${projectData!["dataDate"].split('.')[0]}",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    softWrap: true,
                    maxLines: 2, // Limits to 2 lines
                    overflow: TextOverflow.visible, // Allows text to wrap
                  ),
                ],
              ),
              Expanded(child: SizedBox(width: 100)),
              Image.asset(
                'images/TT_Logo.png',
                width: 80,
              ),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ParameterDropdown(
                    selectedParameter: selectedParameter,
                    selectedParamDevice: selectedParamDevice,
                    deviceParametersMap: deviceParametersMap,
                    onParameterSelected: (value) {
                      List<String> parts = value.split('(');
                      if (parts.length == 2) {
                        setState(() {
                          selectedParameter = parts[0].trim();
                          selectedParamDevice =
                              parts[1].replaceAll(')', '').trim();
                          formatter = NumberFormat(
                              formatMap[selectedParameter], "en_US");
                          // Reset visited parameters tracking
                          visitedParameters.clear();
                          isAllParametersVisited = false;
                          updatePlotData(
                              "$selectedParameter${selectedParamDevice.replaceAll('Terratrace', '')}");
                        });
                      }
                    },
                    formatMap: formatMap,
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: int.parse(currentSamplingPoint) > 1
                        ? () => _navigateToSamplingPoint('left')
                        : null,
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: currentSamplingPoint,
                      dropdownColor: Colors.grey[900],
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                      isDense: true,
                      items: List.generate(totalSamplingPoints, (index) {
                        return DropdownMenuItem<String>(
                          value: (index + 1).toString(),
                          child: Text(
                            'Point ${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }),
                      onChanged: (String? newValue) async {
                        if (newValue != null) {
                          // Save current data if slope was calculated and parameter is a FLX parameter
                          if (hasCalculatedSlope &&
                              deviceFlxParamsMap[selectedParamDevice]
                                      ?.contains(selectedParameter) ==
                                  true) {
                            await _saveData();
                          }

                          // Reset state before loading new data
                          setState(() {
                            hasCalculatedSlope = false;
                            collectedData.clear();
                            dataPoints.clear();
                            slopeLinePoints.clear();
                            isLoading = true;
                          });

                          // Update sampling point
                          setState(() {
                            currentSamplingPoint = newValue;
                          });

                          // Update plot with new data
                          await _updatePlot();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, color: Colors.white),
                    onPressed: isAllParametersVisited
                        ? null
                        : () => _navigateToSamplingPoint('right'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                chartWidth = constraints.maxWidth - 20;
                rightBoundary = rightBoundary.clamp(
                    leftBoundary + minHandleSeparation,
                    chartWidth - handleWidth);

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    key: ValueKey(selectedParameter),
                    children: [
                      Positioned.fill(
                        child: CustomLineChart(
                          dataPoints: dataPoints,
                          slopeLinePoints: slopeLinePoints,
                          minY: minY,
                          maxY: maxY,
                          stepSize: stepSize,
                          selectedParameter: selectedParameter,
                          showSlopeLine:
                              deviceFlxParamsMap[selectedParamDevice]!
                                  .contains(selectedParameter),
                          chartWidth: chartWidth,
                        ),
                      ),
                      if (deviceFlxParamsMap[selectedParamDevice]!
                          .contains(selectedParameter))
                        Positioned.fill(
                          child: ChartOverlay(
                            leftBoundary: leftBoundary,
                            rightBoundary: rightBoundary,
                            chartWidth: chartWidth,
                            minHandleSeparation: minHandleSeparation,
                            onCalculateSlope: dynamicSlopeAndRSquared,
                            selectedParamDevice: selectedParamDevice,
                            showSelection:
                                deviceFlxParamsMap[selectedParamDevice]!
                                    .contains(selectedParameter),
                            onLeftBoundaryChanged: (newPosition) {
                              if (!mounted) return;
                              setState(() {
                                leftBoundary = newPosition;
                              });
                            },
                            onRightBoundaryChanged: (newPosition) {
                              if (!mounted) return;
                              setState(() {
                                rightBoundary = newPosition;
                              });
                            },
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChartValueDisplay(
                            selectedParameter: selectedParameter,
                            dataPoints: dataPoints,
                            formatter: formatter,
                            unitMap: unitMap,
                            avgTemp: avgTemp,
                            avgPressure: avgPressure,
                          ),
                          // ),
                          if (deviceFlxParamsMap[selectedParamDevice]!
                              .contains(selectedParameter))
                            ChartStatsDisplay(
                              slope: slope,
                              rSquared: rSquared,
                              flux: flux,
                              fluxError: fluxError,
                              formatter: formatter,
                            ),
                        ],
                      ),
                      if (deviceFlxParamsMap[selectedParamDevice]!
                          .contains(selectedParameter))
                        Positioned(
                          left: leftBoundary - handleWidth / 2,
                          top: 0,
                          bottom: 0,
                          child: ChartBoundaryHandle(
                            position: leftBoundary,
                            handleWidth: handleWidth,
                            isLeft: true,
                            minHandleSeparation: minHandleSeparation,
                            chartWidth: chartWidth,
                            onBoundaryChanged: (newPosition) {
                              if (!mounted) return;
                              setState(() {
                                leftBoundary = newPosition;
                              });
                            },
                            onPanEnd: () =>
                                dynamicSlopeAndRSquared(selectedParamDevice),
                            showHandle: true,
                          ),
                        ),
                      if (deviceFlxParamsMap[selectedParamDevice]!
                          .contains(selectedParameter))
                        Positioned(
                          left: rightBoundary - handleWidth / 2,
                          top: 0,
                          bottom: 0,
                          child: ChartBoundaryHandle(
                            position: rightBoundary,
                            handleWidth: handleWidth,
                            isLeft: false,
                            minHandleSeparation: minHandleSeparation,
                            chartWidth: chartWidth,
                            onBoundaryChanged: (newPosition) {
                              if (!mounted) return;
                              setState(() {
                                rightBoundary = newPosition;
                              });
                            },
                            onPanEnd: () =>
                                dynamicSlopeAndRSquared(selectedParamDevice),
                            showHandle: true,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            )
          ],
        ));
  }
}

// /// A simple custom painter to draw the selection overlay.
// class SelectionPainter extends CustomPainter {
//   final double leftBoundary;
//   final double rightBoundary;
//   final double chartWidth;

//   SelectionPainter(this.leftBoundary, this.rightBoundary, this.chartWidth);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint paint = Paint()
//       ..color = Colors.white.withOpacity(0.2)
//       ..style = PaintingStyle.fill;
//     Rect rect = Rect.fromLTRB(leftBoundary, 0, rightBoundary, size.height);
//     canvas.drawRect(rect, paint);
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }

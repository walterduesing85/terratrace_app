import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'stats_func.dart';
import 'dart:io';
import 'utils.dart';
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

  double chamberDiameter = 200;
  double chamberHeight = 100;
  double avgPressure = 1013.15;
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

  @override
  void initState() {
    super.initState();
    print("initState called");
    _updatePlot();
  }

  Future<void> _updatePlot() async {
    String jsonString = await rootBundle.loadString('assets/mbus.json');
    Map<String, dynamic> jsonData = jsonDecode(jsonString);

    // List<String> headersFirestore = [];

    Map<String, String> tempFormatMap = {};
    Map<String, String> tempUnitMap = {};
    Map<String, List<String>> tempDeviceFlxParamsMap = {};
    Map<String, List<String>> tempDeviceParametersMap = {};

    final collection = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.project)
        .collection("data")
        .doc(widget.samplingPoint)
        .get();
    final data = collection.data();
    setState(() {
      projectData = data;
    });

    final mbus = projectData!["dataInstrument"];

    // Iterate through each device name in mbus
    for (var deviceName in mbus) {
      if (jsonData.containsKey(deviceName)) {
        // Get the list of parameters for the device
        var parameters = jsonData[deviceName];
        for (var param in parameters) {
          if (param['Class'] == 'FLX' || param['Class'] == 'EPV') {
            final paramFirestore =
                '${param["Name"]}${deviceName.replaceAll("Terratrace", "")}';
            tempFormatMap[param["Name"]] = param["Format"];
            tempUnitMap[param["Name"]] = param["Unit"];
            tempDeviceParametersMap.putIfAbsent(deviceName, () => []);
            tempDeviceFlxParamsMap.putIfAbsent(deviceName, () => []);
            tempDeviceParametersMap[deviceName]!.add(param["Name"]);
            setState(() {
              formatMap = tempFormatMap;
              unitMap = tempUnitMap;
              deviceParametersMap = tempDeviceParametersMap;
            });

            if (param['Class'] == 'FLX') {
              tempDeviceFlxParamsMap[deviceName]!.add(param["Name"]);
              setState(() {
                deviceFlxParamsMap = tempDeviceFlxParamsMap;
                deviceR2SlopeMap.putIfAbsent(deviceName, () => {});
                deviceR2SlopeMap[deviceName]!
                    .putIfAbsent(param["Name"], () => []);
                deviceR2SlopeMap[deviceName]![param["Name"]] = [
                  data!['${paramFirestore}LeftBoundary'] ?? leftBoundary,
                  data['${paramFirestore}RightBoundary'] ?? rightBoundary,
                  data['${paramFirestore}Slope'] ?? 0,
                  data['${paramFirestore}RSquared'] ?? 0,
                  (data['${paramFirestore}LeftIndexBoundary'] ?? 0).toDouble(),
                  (data['${paramFirestore}RightIndexBoundary'] ?? 0).toDouble(),
                  data['${paramFirestore}FluxMoles'] ?? 0
                ];
              });
            }
            if (paramFirestore.contains("Temperature")) {
              avgTemp = double.parse(data!['${paramFirestore}Avg']);
            }
            if (paramFirestore.contains("Pressure")) {
              avgPressure = double.parse(data!['${paramFirestore}Avg']);
            }
            // if (param['Class'] == 'EPV') {
            //   headersFirestore.add('${paramFirestore}Avg');
            //   headersFirestore.add('${paramFirestore}Max');
            //   headersFirestore.add('${paramFirestore}Min');
            //   headersFirestore.add('${paramFirestore}Std');
            // }
            final timeseriesSnapshot = await FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.project)
                .collection("time-series")
                .doc(paramFirestore)
                .collection(widget.samplingPoint!)
                .get();

            setState(() {
              for (var doc in timeseriesSnapshot.docs) {
                // Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                var value = doc.data()['value'];
                var sec = doc.data()['elapsedTime'];

                collectedData.putIfAbsent(paramFirestore, () => []);
                collectedData[paramFirestore]!.add({
                  "value": value,
                  "sec": sec,
                });
              }
            });
          }
        }
      }
    }

    for (var device in deviceParametersMap.keys) {
      for (var param in deviceParametersMap[device]!) {
        if (deviceFlxParamsMap.containsKey(device) &&
            deviceFlxParamsMap[device]!.contains(param)) {
          setState(() {
            selectedParameter = param;
            selectedParamDevice = device;
            formatter = NumberFormat(formatMap[selectedParameter], "en_US");
          });
          break; // Exit once the first FLX parameter is found
        }
      }
    }

    // parameter = parameter.replaceAll('-', '').replaceAll(' ', '');
    String deviceParam =
        "$selectedParameter${selectedParamDevice.replaceAll('Terratrace', '')}";
    if (selectedParameter.isNotEmpty) {
      setState(() {
        // Ensure plot updates correctly when switching parameters
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
        }

        updatePlotData(deviceParam);
        _calculateSlopeAndRSquared(selectedParamDevice);
      });
    }
    // Data loading is complete.
    setState(() {
      isLoading = false;
    });
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
        (86400 * avgPressure * slope * (chamberHeight / 1000)) /
            (1000000 * gasConstant * avgTemp)
      ];
    }
  }

  /// Convert boundary positions into data indices and calculate regression
  void _calculateSlopeAndRSquared(String deviceName) {
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

    // Update UI
    setState(() {
      slope = double.parse(m.toStringAsFixed(2));
      rSquared = double.parse(rSquaredCalculated.toStringAsFixed(2));

      indexLeftBoundary = startIndex;
      indexRightBoundary = endIndex;

      // Define start and end points for the slope line
      double xStart = subset.first.x;
      double yStart = subset.first.y;
      double xEnd = subset.last.x;
      double yEnd = yStart + m * (xEnd - xStart);

      slopeLinePoints = [
        FlSpot(xStart, yStart),
        FlSpot(xEnd, yEnd),
      ];
    });
    saveParameterValues(deviceName);
    print("Slope: $slope, R²: $rSquared");
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

// Function to format Y-axis labels
  String formatYAxisLabel(double value, double stepSize) {
    if (stepSize >= 10) {
      return value.toStringAsFixed(0); // No decimals
    } else {
      return value.toStringAsFixed(2); // Two decimal places
    }
  }

  Future<String> _saveData() async {
    Map<String, dynamic> dataMap = {};

    // if (collectedData.isEmpty || widget.samplingPoint!.isEmpty) {
    //   print("Incomplete data");
    //   return;
    // }

    // final directory = await getApplicationDocumentsDirectory();
    Directory directory = Directory('/storage/emulated/0/Documents');
    final filePath =
        '${directory.path}/${widget.project}_Sampling#${widget.samplingPoint}_ble_data.txt';
    final file = File(filePath);
    print("FILEPATH: $filePath");

    // Build the dataMap with all the required fields.

    // Header
    String header = """
TIME:\t${projectData!["dataDate"]}
SITE:\t${projectData!["dataSite"]}
POINT:\t${widget.samplingPoint}
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
          var dataForIndex =
              collectedData["$param${device.replaceAll("Terratrace", "")}"];

          double fluxInMoles = values[6];
          double fluxInGrams = fluxInMoles * molarMassCO2;
          String prefix = "$param-${device.replaceAll("Terratrace-", "")}";

          var errorSlope =
              calculateSlopesAndStdDev(dataForIndex, leftIndex, rightIndex);
          double fluxError = (errorSlope["stdDeviation"]! /
                  errorSlope["wholeIntervalSlope"]!) *
              100;

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
        .doc(widget.samplingPoint);
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
    // Show a loading indicator until the data is loaded.
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Loading..."),
          backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
        ),
        body: Center(child: CircularProgressIndicator()),
        backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
      );
    }
    return Scaffold(
        backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
          title: CustomAppBar(
              title:
                  'Adjust Boundaries' // Use data when available, or default title
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
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      iconEnabledColor: Color.fromRGBO(58, 66, 86, 1.0),
                      dropdownColor: Color.fromRGBO(58, 66, 86, 1.0),
                      value: selectedParameter.isEmpty
                          ? null
                          : "$selectedParameter ($selectedParamDevice)",
                      items: deviceParametersMap
                          .entries // Iterate over key-value pairs (platform, parameters list)
                          .expand((entry) => entry.value.map((param) {
                                // For each parameter, append the platform name in parentheses
                                String displayText =
                                    "$param (${entry.key.replaceAll("Terratrace-", "")})";
                                return DropdownMenuItem<String>(
                                  value: "$param (${entry.key})",
                                  child: Text(
                                    displayText,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }))
                          .toList(),
                      onChanged: (value) {
                        // Split the string on the '(' character.
                        List<String> parts = value!.split('(');

                        setState(() {
                          if (parts.length == 2) {
                            // Trim the parameter name (before the '(').
                            selectedParameter = parts[0].trim();
                            // Remove the closing parenthesis and trim to get the device name.
                            selectedParamDevice =
                                parts[1].replaceAll(')', '').trim();
                            formatter = NumberFormat(
                                formatMap[selectedParameter], "en_US");
                          }
                          updatePlotData(
                              "$selectedParameter${selectedParamDevice.replaceAll('Terratrace', '')}");
                          // dataPoints.clear();
                        });
                      },
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      return IconButton(
                          onPressed: () async {
                            // try {
                            // Perform the download/export action
                            String filepath = await _saveData();
                            // Notify the user that the file has been downloaded
                            showDownloadMessage(context);
                            return showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text('Share BLE txt file'),
                                  content:
                                      Text('Do you want to share the file?'),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        await shareCSVFile(filepath);
                                        Navigator.of(context)
                                            .pop(); // close the dialog after sharing
                                      },
                                      child: Text('Share'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pop(); // close the dialog without sharing
                                      },
                                      child: Text('Cancel'),
                                    ),
                                  ],
                                );
                              },
                            );
                            // } catch (e) {
                            //   print(e);
                            //   // Handle error (if necessary)
                            //   final errorSnackBar = SnackBar(
                            //     content: Text(
                            //         'Failed to download the file. Please try again!'),
                            //     duration: Duration(seconds: 2),
                            //   );
                            //   ScaffoldMessenger.of(context)
                            //       .showSnackBar(errorSnackBar);
                            // }
                          },
                          icon: Icon(Icons.save_as, color: Colors.white)
                          // child: Text('Save'),
                          );
                    },
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
                // }

                print(
                    "Chart width: $chartWidth, Left: $leftBoundary, Right: $rightBoundary");
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    key: ValueKey(selectedParameter),
                    children: [
                      // The line chart.
                      Positioned.fill(
                        child: LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                // Customize tooltip appearance
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map(
                                    (touchedSpot) {
                                      final xValue =
                                          touchedSpot.x; // x coordinate
                                      final yValue =
                                          touchedSpot.y; // y coordinate
                                      return LineTooltipItem(
                                        'x: $xValue, y: $yValue', // Display both x and y values
                                        TextStyle(
                                            color: Colors
                                                .white), // Customize text style
                                      );
                                    },
                                  ).toList();
                                },
                              ),
                              touchSpotThreshold: 10, // Adjust sensitivity
                              getTouchedSpotIndicator: (barData, spotIndexes) {
                                // This prevents drawing the vertical line
                                return spotIndexes
                                    .map(
                                      (index) => TouchedSpotIndicatorData(
                                        FlLine(
                                            color: Colors
                                                .transparent), // Makes the line invisible
                                        FlDotData(
                                            show:
                                                true), // Keeps the dot highlight
                                      ),
                                    )
                                    .toList();
                              },
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: dataPoints.isNotEmpty
                                    ? dataPoints
                                    : [FlSpot(0, 0)],
                                isCurved: true,
                                curveSmoothness: 0.3,
                                barWidth: 2,
                                color: Color(0xFFAEEA00),
                              ),
                              // Slope line
                              if (deviceFlxParamsMap[selectedParamDevice]!
                                  .contains(selectedParameter))
                                LineChartBarData(
                                  spots: slopeLinePoints.isNotEmpty
                                      ? slopeLinePoints
                                      : [FlSpot(0, 0)],
                                  isCurved: false,
                                  barWidth: 2,
                                  color: Colors.redAccent,
                                  dashArray: [
                                    5,
                                    5
                                  ], // Dashed line for visibility
                                ),
                            ],
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  // interval:stepSize, // Dynamically set interval
                                  getTitlesWidget: (value, meta) {
                                    // Find min and max Y values in the dataset
// Check if dataPoints is empty before calculating min/max
                                    double minY = dataPoints.isNotEmpty
                                        ? dataPoints
                                            .map((e) => e.y)
                                            .reduce((a, b) => a < b ? a : b)
                                        : 0.0;

                                    double maxY = dataPoints.isNotEmpty
                                        ? dataPoints
                                            .map((e) => e.y)
                                            .reduce((a, b) => a > b ? a : b)
                                        : 1.0;
                                    double stepSize =
                                        calculateStepSize(minY, maxY);
                                    return Text(
                                      selectedParameter == "CH4"
                                          ? value.toStringAsFixed(3)
                                          : formatYAxisLabel(value, stepSize),
                                      // value.toStringAsFixed(2),
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white),
                                    );
                                  },
                                ),
                              ),
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 24,
                                  interval: (dataPoints.length >= 10)
                                      ? (dataPoints.length / 5).ceilToDouble()
                                      : 2, // Ensure proper spacing
                                  getTitlesWidget: (value, meta) {
                                    int index =
                                        value.round(); // Round to nearest int

                                    return Text(index.toString(),
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.white));
                                  },
                                ),
                              ),
                            ),
                            gridData: FlGridData(show: true),
                            borderData: FlBorderData(show: true),
                          ),
                        ),
                      ),
                      // Left draggable boundary handle.
                      // Interactive selection overlay.
                      // Wrap with IgnorePointer so it doesn't intercept gestures.
                      if (deviceFlxParamsMap[selectedParamDevice]!
                          .contains(selectedParameter))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: SelectionPainter(
                                  leftBoundary, rightBoundary, chartWidth),
                            ),
                          ),
                        ),
                      // Floating Legend for Latest Value
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            selectedParameter.contains("Temperature")
                                ? "$selectedParameter: ${dataPoints.isNotEmpty ? formatter.format(dataPoints.last.y) : "N/A"} ${unitMap[selectedParameter]} \nAverage: ${avgTemp.toStringAsFixed(2)}°C"
                                : selectedParameter.contains("Pressure")
                                    ? "$selectedParameter: ${dataPoints.isNotEmpty ? formatter.format(dataPoints.last.y) : "N/A"} ${unitMap[selectedParameter]} \nAverage: ${avgPressure.toStringAsFixed(2)} hPa"
                                    : "${selectedParameter}: ${dataPoints.isNotEmpty ? formatter.format(dataPoints.last.y) : "N/A"} ${unitMap[selectedParameter]}",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                      if (deviceFlxParamsMap[selectedParamDevice]!
                          .contains(selectedParameter))
                        // Display slope and R².
                        Positioned(
                          top: 60,
                          left: 20,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "Slope: ${slope.toStringAsFixed(2)} [ppm/sec] \nR²: ${rSquared.toStringAsFixed(2)} \nFlux: ${flux.toStringAsFixed(3)} [moles/(m2*day)]",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ),
                      // Left draggable boundary handle (placed on top).
                      if (deviceFlxParamsMap[selectedParamDevice]!
                          .contains(selectedParameter))
                        Positioned(
                          left: leftBoundary - handleWidth / 2,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                leftBoundary = (leftBoundary + details.delta.dx)
                                    .clamp(0.0,
                                        rightBoundary - minHandleSeparation);
                              });
                              // _calculateSlopeAndRSquared();
                              print("Left boundary moved to: $leftBoundary");
                            },
                            onPanEnd: (_) {
                              _calculateSlopeAndRSquared(selectedParamDevice);
                            },
                            child: Container(
                              width: handleWidth,
                              color: Colors.white.withOpacity(0.0),
                            ),
                          ),
                        ),

                      // Right draggable boundary handle (placed on top).
                      if (deviceFlxParamsMap[selectedParamDevice]!
                          .contains(selectedParameter))
                        Positioned(
                          left: rightBoundary - handleWidth / 2,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                rightBoundary =
                                    (rightBoundary + details.delta.dx).clamp(
                                        leftBoundary + minHandleSeparation,
                                        chartWidth);
                              });
                              // _calculateSlopeAndRSquared();
                              print("Right boundary moved to: $rightBoundary");
                            },
                            onPanEnd: (_) {
                              _calculateSlopeAndRSquared(selectedParamDevice);
                            },
                            child: Container(
                              width: handleWidth,
                              color: Colors.white.withOpacity(0.0),
                            ),
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

/// A simple custom painter to draw the selection overlay.
class SelectionPainter extends CustomPainter {
  final double leftBoundary;
  final double rightBoundary;
  final double chartWidth;

  SelectionPainter(this.leftBoundary, this.rightBoundary, this.chartWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    Rect rect = Rect.fromLTRB(leftBoundary, 0, rightBoundary, size.height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

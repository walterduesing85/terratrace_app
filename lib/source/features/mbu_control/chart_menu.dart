import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:terratrace/source/features/mbu_control/save_data.dart';
import 'package:terratrace/source/features/mbu_control/commands.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';
// import 'package:go_router/go_router.dart';
// import 'package:terratrace/source/routing/app_router.dart';

class BLEScreen extends StatefulWidget {
  final String? type;
  const BLEScreen({Key? key, required this.type}) : super(key: key);
  @override
  _BLEScreenState createState() => _BLEScreenState();
}

class _BLEScreenState extends State<BLEScreen> {
  BluetoothDevice? connectedDevice;
  List<BluetoothDevice> availableDevices = [];
  bool isScanning = false;
  List<BluetoothService> services = [];
  Map<Guid, List<int>> readValues = {};
  final Map<String, List<Map<String, dynamic>>> collectedData = {};
  Position? userLocation;
  // int playStopCounter = 0;

  // These boundaries are expressed in pixel offsets relative to the chart's width.
  double leftBoundary = 40.0;
  double rightBoundary = 350.0;
  double chartWidth = 1.0;

  // Regression results
  double slope = 0.0;
  double rSquared = 0.0;

  // A minimum separation (in pixels) between handles
  final double minHandleSeparation = 20.0;
  // Handle width for display purposes
  final double handleWidth = 16.0;

  List<FlSpot> slopeLinePoints = [];

  // Subscription to track the connected device's state.
  StreamSubscription<BluetoothConnectionState>? deviceStateSubscription;

  final List<String> parameters = [
    "CO2",
    "Battery Voltage",
    "Barometric Pressure",
    "Air Temperature",
    "Air Humidity",
  ];

  final List<String> parameters_mbu2 = [
    "CH4",
    "VOC",
  ];

// Store boundaries and calculated values for each parameter
  Map<String, List<double>> r2SlopeMap = {
    "CO2": [],
    "Battery Voltage": [],
    "CH4": [],
    "VOC": [],
    "Barometric Pressure": [],
    "Air Temperature": [],
    "Air Humidity": [],
  };

  final List<String> commands = ["CO2 to Zero", "Set Filter Value"];

  String selectedParameter = "CO2";
  String selectedCommand = "CO2 to Zero";
  List<FlSpot> dataPoints = [];
  bool isPlaying = false;
  bool showSaveButton = false;

  @override
  void initState() {
    super.initState();
    checkSavedDevice();
    // startScan();
    _getUserLocation();
  }

  Future<void> checkSavedDevice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedDeviceId =
        prefs.getString('last_connected_device_${widget.type}');

    if (savedDeviceId != null) {
      BluetoothDevice savedDevice =
          BluetoothDevice(remoteId: DeviceIdentifier(savedDeviceId));
      connectToDevice(savedDevice);
    }
  }

  void startScan() {
    setState(() {
      availableDevices.clear();
      isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (ScanResult scanResult in results) {
          final deviceName = scanResult.device.platformName ?? "";

          // Only add devices with "Terratrace" in their name
          if (deviceName.contains("Terratrace") &&
              !availableDevices.contains(scanResult.device)) {
            availableDevices.add(scanResult.device);
          }
        }
      });
    });

    Future.delayed(Duration(seconds: 5), () {
      setState(() => isScanning = false);
      FlutterBluePlus.stopScan();
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      setState(() => connectedDevice = device);
      // Connect to the device
      await device.connect(timeout: Duration(seconds: 10));

      // Listen to the device state changes
      deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("Device disconnected, switching back to connecting screen");
          // Cancel the subscription and update the UI
          deviceStateSubscription?.cancel();
          deviceStateSubscription = null;
          setState(() {
            connectedDevice = null;
            dataPoints.clear();
            collectedData.clear();
            showSaveButton = false;
            isPlaying = false;
          });
        }
      });

      await saveLastConnectedDevice(device);
      discoverServices();
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  Future<void> saveLastConnectedDevice(BluetoothDevice device) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_connected_device_${widget.type}', device.remoteId.str);
  }

  void disconnectDevice() async {
    // Cancel the state subscription if active.
    await deviceStateSubscription?.cancel();
    deviceStateSubscription = null;

    await connectedDevice?.disconnect();
    setState(() => connectedDevice = null);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('last_connected_device_${widget.type}');
  }

  Future<void> discoverServices() async {
    if (connectedDevice == null) return;
    try {
      List<BluetoothService> _services =
          await connectedDevice!.discoverServices();
      setState(() {
        services = _services;
      });
      _subscribeToCharacteristics();
    } catch (e) {
      print('Error discovering services: $e');
    }
  }

  void _subscribeToCharacteristics() {
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          characteristic.lastValueStream.listen((value) {
            setState(() {
              readValues[characteristic.uuid] = value;
              _updatePlot(characteristic.uuid, value);
            });
          });
          characteristic.setNotifyValue(true);
        }
      }
    }
  }

  Future<void> sendCommand(Guid uuid, int value) async {
    if (connectedDevice == null) {
      print("Device not connected.");
      return;
    }

    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid == uuid && characteristic.properties.write) {
          print("WRITING THE COMMAND");
          await characteristic.write([value]);
        }
      }
    }
  }

  void _updatePlot(Guid uuid, List<int> value) {
    double parseFloat(List<int> value) {
      if (value.length >= 4) {
        return ByteData.sublistView(Uint8List.fromList(value))
            .getFloat32(0, Endian.little);
      }
      return 0.0;
    }

    Map<String, String> uuidMap = {
      '2a37': "CO2",
      '2a38': "Battery Voltage",
      '2a45': "CH4",
      '2a46': "VOC",
      '2a42': "Barometric Pressure",
      '2a43': "Air Temperature",
      '2a44': "Air Humidity",
    };

    String parameter = uuidMap[uuid.toString()] ?? "";
    if (parameter.isNotEmpty) {
      double dataPoint = parseFloat(value);
      DateTime timestamp = DateTime.now();

      setState(() {
        collectedData.putIfAbsent(parameter, () => []);
        collectedData[parameter]!.add({
          "timestamp": timestamp,
          "value": dataPoint,
        });

        // Keep only the last 30 data points for each parameter
        // if (collectedData[parameter]!.length > 30) {
        //   collectedData[parameter]!.removeAt(0);
        // }

        // Ensure plot updates correctly when switching parameters
        if (r2SlopeMap.containsKey(selectedParameter) &&
            r2SlopeMap[selectedParameter]!.length >= 2 &&
            parameter == selectedParameter) {
          leftBoundary =
              r2SlopeMap[selectedParameter]![0]; // Saved left boundary
          rightBoundary =
              r2SlopeMap[selectedParameter]![1]; // Saved right boundary
        }
        if (parameter == selectedParameter && isPlaying) {
          updatePlotData();
          _calculateSlopeAndRSquared();
        }
      });
    }
  }

// Function to refresh the plot when switching parameters
  void updatePlotData() {
    setState(() {
      dataPoints.clear();

      if (collectedData.containsKey(selectedParameter)) {
        List<Map<String, dynamic>> allData = collectedData[selectedParameter]!;

        if (allData.isNotEmpty) {
          // Get the timestamp of the first data point within the last 30 elements
          int startIndex = allData.length > 30 ? allData.length - 30 : 1;
          List<Map<String, dynamic>> last30 = allData.sublist(startIndex);

          DateTime startTime = allData.first["timestamp"];

          for (var point in last30) {
            int xMilliseconds =
                point["timestamp"].difference(startTime).inSeconds;
            dataPoints.add(FlSpot(xMilliseconds.toDouble(), point["value"]));
          }
        }
      }
    });
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      userLocation = await Geolocator.getCurrentPosition();
      print("GEOLOCATION: $userLocation");
    }
  }

  void togglePlay() {
    setState(() {
      // playStopCounter += 1;
      isPlaying = !isPlaying;
    });

    if (!isPlaying) {
      sendCommand(Guid("2a3c"), 1); // openAC
      sendCommand(Guid("2a3e"), 0); // setPumpStatus
      setState(() {
        showSaveButton = true;
      });
      // collectedData.clear();
      // dataPoints.clear();
    } else {
      sendCommand(Guid("2a3d"), 1); // closeAC
      sendCommand(Guid("2a3e"), 1); // setPumpStatus
      setState(() {
        // if (playStopCounter > 1) {
        showSaveButton = false;
        // }
      });
    }
  }

  void saveParameterValues() {
    if (r2SlopeMap.containsKey(selectedParameter)) {
      r2SlopeMap[selectedParameter] = [
        leftBoundary,
        rightBoundary,
        slope,
        rSquared
      ];
    }
  }

  /// Convert boundary positions into data indices and calculate regression
  void _calculateSlopeAndRSquared() {
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
      });
      saveParameterValues();
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
      slope = m;
      rSquared = rSquaredCalculated;

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
    saveParameterValues();
    print("Slope: $slope, R²: $rSquared");
  }

  @override
  void dispose() {
    // Cancel the subscription when disposing
    deviceStateSubscription?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return Scaffold(
        backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
          title: CustomAppBar(
              title: connectedDevice == null
                  ? 'Select Device ${widget.type?.toUpperCase()}'
                  : 'Connected: ${connectedDevice!.platformName}' // Use data when available, or default title
              ),
        ),
        body: connectedDevice == null
            ? Column(
                children: [
                  ElevatedButton(
                    onPressed: startScan,
                    child:
                        Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableDevices.length,
                      itemBuilder: (context, index) {
                        final device = availableDevices[index];
                        return ListTile(
                          title: Text(device.platformName ?? 'Unknown Device'),
                          textColor: Colors.white,
                          subtitle: Text(device.remoteId.str),
                          trailing: ElevatedButton(
                            onPressed: () => connectToDevice(device),
                            child: Text('Connect'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        type == "mbu1"
                            ? PopupMenuButton<String>(
                                icon: Icon(Icons.menu_open,
                                    color: Colors.white), // Menu icon
                                onSelected: (value) {
                                  if (value == "Co2") {
                                    showDialog(
                                      context: context,
                                      builder: (context) => CommandsPopup(
                                        connectedDevice: connectedDevice,
                                        services: services,
                                        command: "co2",
                                      ),
                                    );
                                  } else if (value == "Filter") {
                                    showDialog(
                                      context: context,
                                      builder: (context) => CommandsPopup(
                                          connectedDevice: connectedDevice,
                                          services: services,
                                          command: "filter"),
                                    );
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  PopupMenuItem(
                                    value: "Co2",
                                    child: Text("Set CO2 To Zero"),
                                  ),
                                  PopupMenuItem(
                                    value: "Filter",
                                    child: Text("Set Filter Value"),
                                  ),
                                ],
                              )
                            : Container(),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            iconEnabledColor: Color.fromRGBO(58, 66, 86, 1.0),
                            dropdownColor: Color.fromRGBO(58, 66, 86, 1.0),
                            value: type == "mbu1" ? selectedParameter : "CH4",
                            items: type == "mbu1"
                                ? parameters
                                    .map((param) => DropdownMenuItem(
                                          value: param,
                                          child: Text(
                                            param,
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ))
                                    .toList()
                                : parameters_mbu2
                                    .map((param) => DropdownMenuItem(
                                          value: param,
                                          child: Text(
                                            param,
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ))
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedParameter = value!;
                                dataPoints.clear();
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white),
                          onPressed: togglePlay,
                        ),
                        if (showSaveButton)
                          Consumer(
                            builder: (context, ref, child) {
                              return IconButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => SaveDataPopup(
                                        collectedData: collectedData,
                                        ref: ref,
                                        r2SlopeMap: r2SlopeMap,
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.save_as, color: Colors.white)
                                  // child: Text('Save'),
                                  );
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.power_off, color: Colors.white),
                          onPressed: () {
                            connectedDevice?.disconnect();
                            setState(() {
                              connectedDevice = null;
                              dataPoints.clear();
                              collectedData.clear();
                              showSaveButton = false;
                              isPlaying = false;
                            });
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
                          children: [
                            // The line chart.
                            Positioned.fill(
                              child: LineChart(
                                LineChartData(
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: dataPoints,
                                      isCurved: true,
                                      barWidth: 2,
                                      color: Color(0xFFAEEA00),
                                    ),
                                    // Slope line
                                    LineChartBarData(
                                      spots: slopeLinePoints,
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
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            value.toStringAsFixed(2),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white),
                                          );
                                        },
                                      ),
                                    ),
                                    topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 24,
                                        getTitlesWidget: (value, meta) {
                                          return Text(value.toInt().toString(),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white));
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
                                  "${selectedParameter}: ${dataPoints.isNotEmpty ? dataPoints.last.y.toStringAsFixed(3) : "N/A"} ppm",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ),

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
                                  "Slope: ${slope.toStringAsFixed(6)} \nR²: ${rSquared.toStringAsFixed(6)}",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ),
                            // Left draggable boundary handle (placed on top).
                            Positioned(
                              left: leftBoundary - handleWidth / 2,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    leftBoundary =
                                        (leftBoundary + details.delta.dx).clamp(
                                            0.0,
                                            rightBoundary -
                                                minHandleSeparation);
                                  });
                                  // _calculateSlopeAndRSquared();
                                  print(
                                      "Left boundary moved to: $leftBoundary");
                                },
                                onPanEnd: (_) {
                                  _calculateSlopeAndRSquared();
                                },
                                child: Container(
                                  width: handleWidth,
                                  color: Colors.white.withOpacity(0.0),
                                ),
                              ),
                            ),

                            // Right draggable boundary handle (placed on top).
                            Positioned(
                              left: rightBoundary - handleWidth / 2,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    rightBoundary = (rightBoundary +
                                            details.delta.dx)
                                        .clamp(
                                            leftBoundary + minHandleSeparation,
                                            chartWidth);
                                  });
                                  // _calculateSlopeAndRSquared();
                                  print(
                                      "Right boundary moved to: $rightBoundary");
                                },
                                onPanEnd: (_) {
                                  _calculateSlopeAndRSquared();
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
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    Rect rect = Rect.fromLTRB(leftBoundary, 0, rightBoundary, size.height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

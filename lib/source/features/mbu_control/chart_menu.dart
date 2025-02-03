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

  final List<String> commands = ["CO2 to Zero", "Set Filter Value"];

  String selectedParameter = "CO2";
  String selectedCommand = "CO2 to Zero";
  List<FlSpot> dataPoints = [];
  bool isPlaying = false;
  bool showSaveButton = false;
  double xValue = 0;

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

  // void startScan() {
  //   FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
  //   FlutterBluePlus.scanResults.listen((results) {
  //     for (ScanResult scanResult in results) {
  //       if (scanResult.device.platformName == "Terratrace") {
  //         FlutterBluePlus.stopScan();
  //         connectToDevice(scanResult.device);
  //         break;
  //       }
  //     }
  //   });
  // }

  void startScan() {
    setState(() {
      availableDevices.clear();
      isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (ScanResult scanResult in results) {
          if (!availableDevices.contains(scanResult.device)) {
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
      await device.connect(timeout: Duration(seconds: 10));
      saveLastConnectedDevice(device);
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
    await connectedDevice?.disconnect();
    setState(() => connectedDevice = null);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('last_connected_device_${widget.type}');
  }

  // Future<void> connectToDevice(BluetoothDevice device) async {
  //   try {
  //     setState(() {
  //       connectedDevice = device;
  //     });
  //     await device.connect();
  //     discoverServices();
  //   } catch (e) {
  //     print('Error connecting to device: $e');
  //   }
  // }

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
        if (collectedData[parameter]!.length > 30) {
          collectedData[parameter]!.removeAt(0);
        }

        // Ensure plot updates correctly when switching parameters
        if (parameter == selectedParameter) {
          updatePlotData();
        }
      });
    }
  }

// Function to refresh the plot when switching parameters
  void updatePlotData() {
    setState(() {
      dataPoints.clear();

      if (collectedData.containsKey(selectedParameter)) {
        List<Map<String, dynamic>> last30 = collectedData[selectedParameter]!
            .take(30) // Ensure we only take the last 30 values
            .toList();

        for (int i = 0; i < last30.length; i++) {
          dataPoints.add(FlSpot(i.toDouble(), last30[i]["value"]));
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
      isPlaying = !isPlaying;
    });

    if (isPlaying) {
      sendCommand(Guid("2a3c"), 1); // openAC
      sendCommand(Guid("2a3e"), 1); // setPumpStatus
      setState(() {
        showSaveButton = false;
      });
      // collectedData.clear();
      // dataPoints.clear();
    } else {
      sendCommand(Guid("2a3d"), 1); // closeAC
      setState(() {
        showSaveButton = true;
      });
    }
  }

  @override
  void dispose() {
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
                                xValue = 0;
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
                              xValue = 0;
                              showSaveButton = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Stack(
                        children: [
                          LineChart(
                            LineChartData(
                              lineBarsData: [
                                LineChartBarData(
                                  spots: dataPoints,
                                  isCurved: true,
                                  barWidth: 2,
                                  color: Color(0xFFAEEA00),
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

                          // Interactive selection for slope & R²
                          // Positioned.fill(
                          //   child: GestureDetector(
                          //     onPanUpdate: (details) {
                          //       // Update selected range dynamically
                          //       setState(() {
                          //         // Convert touch position to data index
                          //         selectedStart = details.localPosition.dx / chartWidth * dataPoints.length;
                          //         selectedEnd = selectedStart + 10; // Adjust range dynamically
                          //       });

                          //       _calculateSlopeAndRSquared();
                          //     },
                          //     child: IgnorePointer(
                          //       child: CustomPaint(
                          //         painter: SelectionPainter(selectedStart, selectedEnd, chartWidth),
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          // // Display slope and R²
                          // Positioned(
                          //   top: 60,
                          //   left: 20,
                          //   child: Container(
                          //     padding: EdgeInsets.all(8),
                          //     decoration: BoxDecoration(
                          //       color: Colors.black54,
                          //       borderRadius: BorderRadius.circular(10),
                          //     ),
                          //     child: Text(
                          //       "Slope: ${slope.toStringAsFixed(6)} ppm/s\nR²: ${rSquared.toStringAsFixed(6)}",
                          //       style: TextStyle(color: Colors.white, fontSize: 14),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ],
              ));
    // return connectedDevice == null
    //     ? Center(
    //         child: ElevatedButton(
    //           onPressed: startScan,
    //           child: Text('Scan for Devices'),
    //         ),
    //       )
    //     :
  }
}

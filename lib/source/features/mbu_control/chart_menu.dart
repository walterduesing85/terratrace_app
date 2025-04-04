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
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'stats_func.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/mbu_control/widgets/chart_widgets.dart';
// import 'package:go_router/go_router.dart';
// import 'package:terratrace/source/routing/app_router.dart';

class BLEScreen extends StatefulWidget {
  const BLEScreen({Key? key}) : super(key: key);
  @override
  _BLEScreenState createState() => _BLEScreenState();
}

class _BLEScreenState extends State<BLEScreen> {
  // BluetoothDevice? connectedDevice;
  List<BluetoothDevice> availableDevices = [];
  bool isScanning = false;
  // List<BluetoothService> services = [];
  // Map<Guid, List<int>> readValues = {};
  final Map<String, List<Map<String, dynamic>>> collectedData = {};
  List<Position> userLocation = [];
  int playStopCounter = 0;

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
  Map<String, List<String>> deviceCommandsMap = {}; // Commands per device.
  Map<String, List<String>> deviceFlxParamsMap =
      {}; // FLX parameters per device.
  // Temporary map for unique uuid mappings from Char -> Name
  Map<String, String> uuidMap = {};
  Map<String, List<String>> notifyParamsMap = {};
  Map<String, String> unitMap = {};
  Map<String, String> formatMap = {};
  List<double> tempValues = [];
  List<double> pressValues = [];
  double chamberDiameter = 0.2;
  double chamberHeight = 0.1;
  double avgPressure = 1013.25;
  double avgTemp = 20;

  double minY = 0;
  double maxY = 1.0;
  double stepSize = 0.1;

  late String selectedParameter;
  late NumberFormat formatter;
  // late String trimmedSelectedParameter;
  List<FlSpot> dataPoints = [];
  bool isPlaying = false;
  bool showSaveButton = false;
  bool proceedToAcquire = false;
  late String selectedParamDevice;
  bool isDeviceFound = false;
  List<String> savedDeviceNames = [];

  @override
  void initState() {
    super.initState();
    // checkSavedDevices();
    // startScan();
    _checkLocationPermissions();
  }

  /// Check and request location permissions.
  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return;
    }
  }

  /// Fetch the current position and add it to userLocation.
  Future<void> _saveUserLocation() async {
    if (!mounted) return; // Early return if widget is not mounted

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: true,
        ),
      );

      if (!mounted) return; // Check again after async operation

      setState(() {
        userLocation.add(position);
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> initializeSelectedParameter() async {
    for (var device in deviceParametersMap.keys) {
      for (var param in deviceParametersMap[device]!) {
        if (deviceFlxParamsMap.containsKey(device) &&
            deviceFlxParamsMap[device]!.contains(param)) {
          setState(() {
            selectedParameter = param;
            selectedParamDevice = device;
            formatter = NumberFormat(formatMap[selectedParameter], "en_US");
          });
          return; // Exit once the first FLX parameter is found
        }
      }
    }
  }

  Future<void> loadDeviceParameters(
      //List<BluetoothDevice> connectedDevices
      ) async {
    try {
      // Load the JSON file (ensure mbus.json is included in your assets)
      String jsonString = await rootBundle.loadString('assets/mbus.json');
      Map<String, dynamic> mbusData = jsonDecode(jsonString);

      // Temporary maps to accumulate data per device
      Map<String, List<String>> tempDeviceParametersMap = {};
      Map<String, Map<String, List<double>>> tempDeviceR2SlopeMap = {};
      Map<String, List<String>> tempDeviceCommandsMap = {};
      Map<String, List<String>> tempDeviceFlxParamsMap = {};
      Map<String, List<String>> tempNotifyParamsMap = {};
      // Temporary map for unique uuid mappings from Char -> Name
      Map<String, String> tempUuidMap = {};
      Map<String, String> tempFormatMap = {};
      Map<String, String> tempUnitMap = {};

      // Loop through each connected device
      for (var device in savedDeviceNames) {
        // String platform = device.platformName;
        String platform = device;
        if (!mbusData.containsKey(platform)) continue;

        List<dynamic> deviceData = mbusData[platform];

        // Initialize entries for this device if needed
        tempDeviceParametersMap.putIfAbsent(platform, () => []);
        tempDeviceR2SlopeMap.putIfAbsent(platform, () => {});
        tempDeviceCommandsMap.putIfAbsent(platform, () => []);
        tempDeviceFlxParamsMap.putIfAbsent(platform, () => []);
        tempNotifyParamsMap.putIfAbsent(platform, () => []);

        for (var param in deviceData) {
          String name = param["Name"];
          String classType = param["Class"];
          // Update the UUID map (ensure keys are in a consistent format, e.g., lowercase)
          String charValue = param["Char"].toString().toLowerCase();

          // Save commands and FLX parameters based on the class type.
          if (classType == "CMD") {
            tempDeviceCommandsMap[platform]!.add(name);
          } else if (classType == "FLX") {
            tempDeviceFlxParamsMap[platform]!.add(name);
            tempFormatMap[name] = param["Format"];
            tempUnitMap[name] = param["Unit"];
            // Save parameter name in this device's parameters list.
            tempDeviceParametersMap[platform]!.add(name);
            // Create an empty boundaries list (or other values) for this parameter.
            tempDeviceR2SlopeMap[platform]!.putIfAbsent(name, () => []);
          } else if (classType == "EPV") {
            // Save parameter name in this device's parameters list.
            tempDeviceParametersMap[platform]!.add(name);
            tempFormatMap[name] = param["Format"];
            tempUnitMap[name] = param["Unit"];
          } else {
            tempNotifyParamsMap[platform]!.add(name);
          }

          tempUuidMap[charValue] = name;
        }
      }

      setState(() {
        deviceParametersMap = tempDeviceParametersMap;
        deviceR2SlopeMap = tempDeviceR2SlopeMap;
        deviceCommandsMap = tempDeviceCommandsMap;
        deviceFlxParamsMap = tempDeviceFlxParamsMap;
        uuidMap = tempUuidMap;
        notifyParamsMap = tempNotifyParamsMap;
        formatMap = tempFormatMap;
        unitMap = tempUnitMap;
      });

      print("Device Parameters Map: $deviceParametersMap");
      print("Device Commands Map: $deviceCommandsMap");
      print("Device FLX Params Map: $deviceFlxParamsMap");
      print("Device Notify Params Map: $notifyParamsMap");
      print("UUID Map: $uuidMap");
      print("Unit Map: $unitMap");
      print("Format Map: $formatMap");
    } catch (e) {
      print("Error loading device parameters: $e");
    }
  }

  Future<void> checkSavedDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Retrieve all keys that start with the prefix for your device type.
    final savedDeviceKeys = prefs
        .getKeys()
        .where((key) => key.startsWith('last_connected_device_'));

    // Iterate through the keys and connect to each device.
    for (final key in savedDeviceKeys) {
      final savedDeviceId = prefs.getString(key);
      final savedDeviceName =
          prefs.getString('device_name_$savedDeviceId') ?? "Unknown Device";

      if (savedDeviceId != null) {
        BluetoothDevice savedDevice =
            BluetoothDevice(remoteId: DeviceIdentifier(savedDeviceId));
        print("Connecting to saved device: $savedDeviceName ($savedDeviceId)");
        setState(() {
          savedDeviceNames.add(savedDeviceName);
        });
        await connectToDevice(savedDevice);
      }
    }

    if (connectedDevices.length == savedDeviceKeys.length &&
        connectedDevices.isNotEmpty) {
      setState(() {
        proceedToAcquire = true;
      });
    }
  }

  void startScan() {
    setState(() {
      availableDevices.clear();
      isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      // setState(() {
      for (ScanResult scanResult in results) {
        final deviceName = scanResult.device.platformName;

        // Only add devices with "Terratrace" in their name
        if (deviceName.contains("Terratrace") &&
            !availableDevices.contains(scanResult.device)) {
          availableDevices.add(scanResult.device);
        }
      }
      // });
    });

    Future.delayed(Duration(seconds: 5), () {
      setState(() => isScanning = false);
      FlutterBluePlus.stopScan();
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Add the device to the list of connected devices.
      setState(() {
        connectedDevices.add(device);
        if (device.platformName.isNotEmpty) {
          savedDeviceNames.add(device.platformName);
        }
        // Check if there is a device with platformName "Terratrace-SSD-MBU"
        isDeviceFound = connectedDevices.any(
          (device) =>
              device.platformName ==
              "Terratrace-SSD-MBU", // TODO make it dynamic, check which MBUs have commands to send manually
        );
      });
      // Connect to the device
      await device.connect(timeout: Duration(seconds: 10));
      // Listen to the device state changes and store subscription using device ID as key.
      deviceStateSubscriptions[device.remoteId.str] =
          device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("Device ${device.remoteId.str} disconnected");
          _handleDeviceDisconnection(device);
        }
      });
      if (device.platformName.isNotEmpty &&
          !savedDeviceNames.contains(device.platformName)) {
        await saveLastConnectedDevice(device, device.platformName);
      }
      // Discover services for this specific device.
      await discoverServices(device);
      await loadDeviceParameters();
      await initializeSelectedParameter();
    } catch (e) {
      print('Error connecting to device ${device.remoteId.str}: $e');
      _handleDeviceDisconnection(device);
    }
  }

  void _handleDeviceDisconnection(BluetoothDevice device) {
    if (!mounted) return;

    // Cancel the subscription and update the UI for this device
    deviceStateSubscriptions[device.remoteId.str]?.cancel();
    deviceStateSubscriptions.remove(device.remoteId.str);

    setState(() {
      // Remove device from connected devices
      connectedDevices
          .removeWhere((d) => d.remoteId.str == device.remoteId.str);

      // Update device found status
      isDeviceFound = connectedDevices.any(
        (device) => device.platformName == "Terratrace-SSD-MBU",
      );

      // Clear all data
      dataPoints.clear();
      collectedData.clear();
      showSaveButton = false;
      isPlaying = false;
      playStopCounter = 0;

      // If no devices are connected, switch back to scan screen
      if (connectedDevices.isEmpty) {
        proceedToAcquire = false;
        savedDeviceNames.clear();
        deviceServices.clear();
        readValues.clear();
        deviceParametersMap.clear();
        deviceR2SlopeMap.clear();
        deviceCommandsMap.clear();
        deviceFlxParamsMap.clear();
        uuidMap.clear();
        notifyParamsMap.clear();
        unitMap.clear();
        formatMap.clear();
        tempValues.clear();
        pressValues.clear();
        avgPressure = 1013.25;
        avgTemp = 20;
        userLocation.clear();

        // Show SnackBar notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device ${device.platformName} disconnected'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    // Remove saved device preferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('last_connected_device_${device.remoteId.str}');
      prefs.remove('device_name_${device.remoteId.str}');
    });
  }

  Future<void> saveLastConnectedDevice(
      BluetoothDevice device, String deviceName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_connected_device_${device.remoteId.str}', device.remoteId.str);
    await prefs.setString('device_name_${device.remoteId.str}', deviceName);
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    // Cancel the state subscription for the device if active.
    await deviceStateSubscriptions[device.remoteId.str]?.cancel();
    deviceStateSubscriptions.remove(device.remoteId.str);

    await device.disconnect();
    setState(() {
      connectedDevices
          .removeWhere((d) => d.remoteId.str == device.remoteId.str);
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('last_connected_device_${device.remoteId.str}');
    prefs.remove('device_name_${device.remoteId.str}');
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> _services = await device.discoverServices();
      setState(() {
        deviceServices[device.platformName] = _services;
      });
      _subscribeToCharacteristics(device, _services);
    } catch (e) {
      print('Error discovering services for device ${device.remoteId.str}: $e');
    }
  }

  void _subscribeToCharacteristics(
      BluetoothDevice device, List<BluetoothService> services) {
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          characteristic.lastValueStream.listen((value) {
            if (!mounted) return; // Add mounted check

            // Store read values keyed by device ID and characteristic UUID.
            readValues[device.remoteId.str] ??= {};
            readValues[device.remoteId.str]![characteristic.uuid] = value;

            // Update plot and location in a single setState
            setState(() {
              _updatePlot(device.platformName, characteristic.uuid, value);
              _saveUserLocation();
            });
          });
          characteristic.setNotifyValue(true);
        }
      }
    }
  }

  void _updatePlot(String deviceName, Guid uuid, List<int> value) {
    if (!mounted) return; // Add mounted check at the start

    double parseFloat(List<int> value) {
      if (value.length >= 4) {
        return ByteData.sublistView(Uint8List.fromList(value))
            .getFloat32(0, Endian.little);
      }
      return 0.0;
    }

    String parameter = uuidMap[uuid.toString()] ?? "";
    String deviceParam = "$parameter${deviceName.replaceAll('Terratrace', '')}";

    if (parameter.isNotEmpty) {
      if (playStopCounter < 2) {
        double dataPoint = double.parse(
            parseFloat(value).toStringAsFixed(parameter == "CH4" ? 3 : 2));
        DateTime timestamp = DateTime.now();

        if (!mounted) return; // Add mounted check before setState

        // Update collectedData
        collectedData.putIfAbsent(deviceParam, () => []);
        DateTime firstTimestamp = collectedData[deviceParam]!.isEmpty
            ? timestamp
            : collectedData[deviceParam]![0]["timestamp"];

        double secondsDifference =
            timestamp.difference(firstTimestamp).inMilliseconds / 1000.0;

        collectedData[deviceParam]!.add({
          "timestamp": timestamp,
          "value": dataPoint,
          "sec": secondsDifference.toStringAsFixed(2),
        });

        // Update temperature and pressure values
        if (deviceParam.contains("Temperature")) {
          tempValues.add(dataPoint);
          avgTemp = calculateAverage(tempValues);
        }
        if (deviceParam.contains("Pressure")) {
          pressValues.add(dataPoint);
          avgPressure = calculateAverage(pressValues);
        }
      }

      if (!mounted) return; // Add mounted check before setState

      // Update plot data and boundaries
      if (deviceR2SlopeMap.containsKey(deviceName) &&
          deviceR2SlopeMap[deviceName]!.containsKey(selectedParameter) &&
          deviceR2SlopeMap[deviceName]![selectedParameter]!.length >= 2 &&
          parameter == selectedParameter) {
        leftBoundary = deviceR2SlopeMap[deviceName]![selectedParameter]![0];
        rightBoundary = deviceR2SlopeMap[deviceName]![selectedParameter]![1];
        slope = deviceR2SlopeMap[deviceName]![selectedParameter]![2];
        rSquared = deviceR2SlopeMap[deviceName]![selectedParameter]![3];
        indexLeftBoundary =
            deviceR2SlopeMap[deviceName]![selectedParameter]![4].toInt();
        indexRightBoundary =
            deviceR2SlopeMap[deviceName]![selectedParameter]![5].toInt();
        flux = deviceR2SlopeMap[deviceName]![selectedParameter]![6];
        fluxError = deviceR2SlopeMap[deviceName]![selectedParameter]![7];
      }

      if (parameter == selectedParameter) {
        updatePlotData(deviceParam);
        // if (isPlaying) {
        if (deviceFlxParamsMap[selectedParamDevice]!
            .contains(selectedParameter)) {
          dynamicSlopeAndRSquared(deviceName);
        }
        // }
      }
    }
  }

  Future<void> sendCommand(BluetoothDevice device, Guid uuid, int value) async {
    // Check if the device is connected
    if (!connectedDevices.contains(device)) {
      print("Device not connected.");
      return;
    }

    // final deviceId = device.remoteId.str;
    final deviceId = device.platformName;
    final deviceServiceList = deviceServices[deviceId];

    if (deviceServiceList == null || deviceServiceList.isEmpty) {
      print("No services found for device $deviceId.");
      return;
    }

    for (var service in deviceServiceList) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid == uuid && characteristic.properties.write) {
          print("WRITING THE COMMAND to device $deviceId");
          await characteristic.write([value]);
        }
      }
    }
  }

  void updatePlotData(String deviceParam) {
    setState(() {
      dataPoints.clear();

      if (collectedData.containsKey(deviceParam)) {
        List<Map<String, dynamic>> allData = collectedData[deviceParam]!;

        if (allData.isNotEmpty) {
          List<Map<String, dynamic>> dataToPlot;

          if (isPlaying || playStopCounter == 2) {
            // Plot all available data points
            dataToPlot = allData;
          } else {
            // Plot only the last 30 points
            int startIndex = allData.length > 30 ? allData.length - 30 : 1;
            dataToPlot = allData.sublist(startIndex);
          }

          for (var point in dataToPlot) {
            // Round to 2 decimal places
            double timeInSeconds = double.parse(point["sec"]);
            // Add data point to the plot
            dataPoints.add(FlSpot(timeInSeconds, point["value"]));
          }
          if (isPlaying) {
            setState(() {
              rightBoundary =
                  350; // dynamically set the rightboundary to be the last acquired point, as per Giorgio's request
            });
          }
          setState(() {
            minY = dataPoints.map((e) => e.y).reduce((a, b) => a < b ? a : b);
            maxY = dataPoints.map((e) => e.y).reduce((a, b) => a > b ? a : b);
            stepSize = calculateStepSize(minY, maxY);
          });
        }
      }
    });
  }

  void togglePlay() {
    setState(() {
      if (playStopCounter == 2) {
        playStopCounter = 1;
      } else {
        playStopCounter += 1;
      }
      isPlaying = !isPlaying;
      if (isPlaying) {
        collectedData.clear();
      }
    });

    // Send commands for each connected device.
    if (!isPlaying) {
      // When stopping play: send openAC and setPumpStatus commands.
      for (var device in connectedDevices) {
        sendCommand(device, Guid("2a3c"), 1); // openAC
        sendCommand(device, Guid("2a3e"), 0); // setPumpStatus
      }
      setState(() {
        showSaveButton = true;
      });
    } else {
      // When starting play: send closeAC and setPumpStatus commands.
      for (var device in connectedDevices) {
        sendCommand(device, Guid("2a3d"), 1); // closeAC
        sendCommand(device, Guid("2a3e"), 1); // setPumpStatus
      }
      setState(() {
        showSaveButton = false;
      });
    }
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
      slope =
          double.parse(m.toStringAsFixed(selectedParameter == "CH4" ? 4 : 2));
      rSquared = double.parse(rSquaredCalculated.toStringAsFixed(2));
      flux = selectedParameter == "CH4"
          ? (86400 * avgPressure * 100 * slope * chamberHeight) /
              (1000000 * gasConstant * (avgTemp + 273.15))
          : double.parse(((86400 * avgPressure * 100 * slope * chamberHeight) /
                  (1000000 * gasConstant * (avgTemp + 273.15)))
              .toStringAsFixed(3));
      indexLeftBoundary = startIndex;
      indexRightBoundary = endIndex;

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
    });
    saveParameterValues(deviceName);
    print("Slope: $slope, R²: $rSquared, FluxError: $fluxError Flux: $flux");
  }

  void showNewAcquisitionDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // backgroundColor:
          //     Color.fromRGBO(64, 75, 96, 1), // Set background color
          title: Text(
            "Confirm New Acquisition",
            style:
                TextStyle(color: Colors.white), // Set title text color to white
          ),
          content: Text(
            "Are you sure you want to proceed with a new acquisition?\nAll previous data will be deleted.",
            style: TextStyle(
                color: Colors.white), // Set content text color to white
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                    color: Colors.white), // Set button text color to white
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  collectedData.clear(); // Reset collectedData
                  deviceR2SlopeMap.forEach((outerKey, innerMap) {
                    innerMap.forEach((innerKey, list) {
                      innerMap[innerKey] = [];
                    });
                  });
                  // deviceR2SlopeMap.clear(); // Clear r2SlopeMap if needed
                  // isPlaying = true;
                  // playStopCounter = 1;
                  // dataPoints.clear();
                  // showSaveButton = false;
                }); // Execute the action (e.g., clearing data)
                togglePlay();
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                "Proceed",
                style: TextStyle(
                    color: Color(0xFFAEEA00)), // Red color for "Proceed" button
              ),
            ),
          ],
        );
      },
    );
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

  @override
  void dispose() {
    // Cancel all active device state subscriptions
    for (var subscription in deviceStateSubscriptions.values) {
      subscription.cancel();
    }
    deviceStateSubscriptions.clear();

    // Disconnect all connected devices
    for (var device in connectedDevices) {
      device.disconnect();
    }
    connectedDevices.clear();

    // Clear all data
    dataPoints.clear();
    collectedData.clear();
    showSaveButton = false;
    isPlaying = false;
    proceedToAcquire = false;
    playStopCounter = 0;
    savedDeviceNames.clear();
    deviceServices.clear();
    readValues.clear();
    deviceParametersMap.clear();
    deviceR2SlopeMap.clear();
    deviceCommandsMap.clear();
    deviceFlxParamsMap.clear();
    uuidMap.clear();
    notifyParamsMap.clear();
    unitMap.clear();
    formatMap.clear();
    tempValues.clear();
    pressValues.clear();
    userLocation.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
        appBar: AppBar(
          // backgroundColor: const Color.fromRGBO(58, 66, 86, 1.0),
          title: CustomAppBar(
              title: connectedDevices.isEmpty
                  ? 'Connect to Devices'
                  : isPlaying
                      ? 'Acquiring State: ON'
                      : !isPlaying
                          ? 'Acquiring State: OFF'
                          : 'Connected: ${connectedDevices.length} device(s)' // Use data when available, or default title
              ),
        ),
        body: !proceedToAcquire
            ? Column(
                children: [
                  SizedBox(
                      height: 16.0), // Add spacing between AppBar and button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 176, 237, 70)),
                    onPressed: startScan,
                    child:
                        Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableDevices.length,
                      itemBuilder: (context, index) {
                        final device = availableDevices[index];
                        // Check if the device is connected by comparing the remoteId string.
                        final isConnected = connectedDevices
                            .any((d) => d.remoteId.str == device.remoteId.str);
                        return ListTile(
                          title: Text(device.platformName),
                          textColor: Colors.white,
                          subtitle: Text(device.remoteId.str),
                          trailing: ElevatedButton(
                            onPressed: () {
                              if (isConnected) {
                                // Call a function to disconnect the device
                                disconnectDevice(device);
                              } else {
                                // Call the connect function
                                connectToDevice(device);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected
                                    ? const Color.fromARGB(255, 113, 15, 15)
                                    : const Color.fromARGB(
                                        255, 176, 237, 70) //Color(0xFFC6FF00),
                                ),
                            child: Text(
                              isConnected ? 'Disconnect' : 'Connect',
                              style: TextStyle(
                                  // fontSize: 20, // match the stroke text size
                                  // color: Colors.white,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // "Proceed" button to navigate to the alternative screen after connections.
                  if (connectedDevices.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            proceedToAcquire = true;
                          });
                        },
                        child: Text('Proceed'),
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
                        isDeviceFound
                            ? PopupMenuButton<String>(
                                icon: Icon(Icons.menu_open,
                                    color: Colors.white), // Menu icon
                                onSelected: (value) {
                                  if (value == "Co2") {
                                    showDialog(
                                      context: context,
                                      builder: (context) => CommandsPopup(
                                        // connectedDevice: connectedDevice,
                                        services: deviceServices[
                                                "Terratrace-SSD-MBU"] ??
                                            [],
                                        command: "co2",
                                      ),
                                    );
                                  } else if (value == "Filter") {
                                    showDialog(
                                      context: context,
                                      builder: (context) => CommandsPopup(
                                          // connectedDevice: connectedDevice,
                                          services: deviceServices[
                                                  "Terratrace-SSD-MBU"] ??
                                              [],
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
                          child: ParameterDropdown(
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
                                  dataPoints.clear();
                                  leftBoundary =
                                      deviceR2SlopeMap[selectedParamDevice]![
                                              selectedParameter]![
                                          0]; // Saved left boundary
                                  rightBoundary =
                                      deviceR2SlopeMap[selectedParamDevice]![
                                              selectedParameter]![
                                          1]; // Saved right boundary
                                  slope =
                                      deviceR2SlopeMap[selectedParamDevice]![
                                          selectedParameter]![2];
                                  rSquared =
                                      deviceR2SlopeMap[selectedParamDevice]![
                                          selectedParameter]![3];
                                  indexLeftBoundary =
                                      deviceR2SlopeMap[selectedParamDevice]![
                                              selectedParameter]![4]
                                          .toInt();
                                  indexRightBoundary =
                                      deviceR2SlopeMap[selectedParamDevice]![
                                              selectedParameter]![5]
                                          .toInt();
                                  flux = deviceR2SlopeMap[selectedParamDevice]![
                                      selectedParameter]![6];
                                  fluxError =
                                      deviceR2SlopeMap[selectedParamDevice]![
                                          selectedParameter]![7];
                                });
                              }
                            },
                            formatMap: formatMap,
                          ),
                        ),
                        IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white),
                          onPressed: playStopCounter == 2
                              ? () => showNewAcquisitionDialog(context, () {})
                              : togglePlay,
                        ),
                        if (showSaveButton)
                          Consumer(
                            builder: (context, ref, child) {
                              return IconButton(
                                  onPressed: () async {
                                    // Check and set default boundaries for any parameter with empty boundaries
                                    if (deviceR2SlopeMap
                                        .containsKey(selectedParamDevice)) {
                                      deviceR2SlopeMap[selectedParamDevice]!
                                          .forEach((key, list) {
                                        if (list.isEmpty) {
                                          String deviceParam =
                                              "$key${selectedParamDevice.replaceAll('Terratrace', '')}";
                                          final data =
                                              collectedData[deviceParam];
                                          if (data != null && data.isNotEmpty) {
                                            // Set default boundaries (40.0 and 350.0)
                                            final slopeRsquared =
                                                calculateSlopeAndRSquared(data);
                                            final error =
                                                calculateSlopesAndStdDev(
                                                    data, 0, data.length - 1);

                                            deviceR2SlopeMap[
                                                selectedParamDevice]![key] = [
                                              40.0, // Default left boundary
                                              350.0, // Default right boundary
                                              double.parse(
                                                  slopeRsquared["slope"]!
                                                      .toStringAsFixed(2)),
                                              double.parse(
                                                  slopeRsquared["rSquared"]!
                                                      .toStringAsFixed(2)),
                                              0,
                                              data.length.toDouble() - 1,
                                              key == "CH4"
                                                  ? (86400 *
                                                          avgPressure *
                                                          100 *
                                                          slope *
                                                          chamberHeight) /
                                                      (1000000 *
                                                          gasConstant *
                                                          (avgTemp + 273.15))
                                                  : double.parse(((86400 *
                                                              avgPressure *
                                                              100 *
                                                              slopeRsquared[
                                                                  "slope"]! *
                                                              chamberHeight) /
                                                          (1000000 *
                                                              gasConstant *
                                                              (avgTemp +
                                                                  273.15)))
                                                      .toStringAsFixed(3)),
                                              double.parse(slopeRsquared[
                                                              "slope"]!
                                                          .toStringAsFixed(
                                                              2)) ==
                                                      0
                                                  ? 0
                                                  : double.parse(
                                                      ((error["stdDeviation"]! /
                                                                  slopeRsquared[
                                                                      "slope"]!) *
                                                              100)
                                                          .toStringAsFixed(1))
                                            ];
                                          }
                                        }
                                      });
                                    }

                                    final bool? didSave =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return SaveDataPopup(
                                          collectedData: collectedData,
                                          ref: ref,
                                          r2SlopeMap: deviceR2SlopeMap,
                                          userLocation: Position(
                                            longitude: userLocation.fold(
                                                    0.0,
                                                    (sum, pos) =>
                                                        sum + pos.longitude) /
                                                userLocation.length,
                                            latitude: userLocation.fold(
                                                    0.0,
                                                    (sum, pos) =>
                                                        sum + pos.latitude) /
                                                userLocation.length,
                                            timestamp: DateTime.now(),
                                            accuracy: userLocation
                                                .map((pos) => pos.accuracy)
                                                .reduce(min),
                                            altitude: 0,
                                            altitudeAccuracy: 0,
                                            heading: 0,
                                            headingAccuracy: 0,
                                            speed: 0.0,
                                            speedAccuracy: 0.0,
                                          ),
                                        );
                                      },
                                    );
                                    // If the user saved successfully, clear the data
                                    if (didSave == true) {
                                      setState(() {
                                        collectedData
                                            .clear(); // Reset collectedData
                                        deviceR2SlopeMap
                                            .forEach((outerKey, innerMap) {
                                          innerMap.forEach((innerKey, list) {
                                            innerMap[innerKey] = [];
                                          });
                                        }); // Clear r2SlopeMap if needed
                                        isPlaying = false;
                                        playStopCounter = 0;
                                        dataPoints.clear();
                                        showSaveButton = false;
                                        leftBoundary = 40.0;
                                        rightBoundary = 350.0;
                                        userLocation = [];
                                      });
                                    }
                                  },
                                  icon:
                                      Icon(Icons.save_as, color: Colors.white));
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.power_off, color: Colors.white),
                          onPressed: () {
                            for (var device in connectedDevices) {
                              device.disconnect();
                            }

                            for (var subscription
                                in deviceStateSubscriptions.values) {
                              subscription.cancel();
                            }

                            setState(() {
                              connectedDevices.clear();
                              deviceStateSubscriptions.clear();
                              dataPoints.clear();
                              collectedData.clear();
                              showSaveButton = false;
                              isPlaying = false;
                              proceedToAcquire = false;
                              playStopCounter = 0;
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

                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Stack(
                          children: [
                            // The line chart.
                            Positioned.fill(
                              child: CustomLineChart(
                                dataPoints: dataPoints,
                                slopeLinePoints: slopeLinePoints,
                                minY: minY - (maxY - minY) * 0.05,
                                maxY: maxY + (maxY - minY) * 0.05,
                                stepSize: stepSize,
                                selectedParameter: selectedParameter,
                                showSlopeLine: (playStopCounter == 1 ||
                                        playStopCounter == 2) &&
                                    deviceFlxParamsMap[selectedParamDevice]!
                                        .contains(selectedParameter),
                                chartWidth: chartWidth,
                              ),
                            ),

                            // Interactive selection overlay.
                            if ((playStopCounter == 1 ||
                                    playStopCounter == 2) &&
                                deviceFlxParamsMap[selectedParamDevice]!
                                    .contains(selectedParameter))
                              Positioned.fill(
                                child: ChartOverlay(
                                  leftBoundary: leftBoundary,
                                  rightBoundary: rightBoundary,
                                  chartWidth: chartWidth,
                                  minHandleSeparation: minHandleSeparation,
                                  onCalculateSlope: dynamicSlopeAndRSquared,
                                  selectedParamDevice: selectedParamDevice,
                                  showSelection: (playStopCounter == 1 ||
                                          playStopCounter == 2) &&
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

                            // Left draggable boundary handle
                            if ((playStopCounter == 1 ||
                                    playStopCounter == 2) &&
                                deviceFlxParamsMap[selectedParamDevice]!
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
                                  onPanEnd: () => dynamicSlopeAndRSquared(
                                      selectedParamDevice),
                                  showHandle: true,
                                ),
                              ),

                            // Right draggable boundary handle
                            if ((playStopCounter == 1 ||
                                    playStopCounter == 2) &&
                                deviceFlxParamsMap[selectedParamDevice]!
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
                                  onPanEnd: () => dynamicSlopeAndRSquared(
                                      selectedParamDevice),
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

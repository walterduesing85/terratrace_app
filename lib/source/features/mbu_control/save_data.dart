import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:terratrace/source/features/data/data/sand_box.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SaveDataPopup extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> collectedData;
  final WidgetRef ref;
  const SaveDataPopup({
    required this.collectedData,
    required this.ref,
    Key? key,
  }) : super(key: key);

  @override
  _SaveDataPopupState createState() => _SaveDataPopupState();
}

class _SaveDataPopupState extends State<SaveDataPopup> {
  final TextEditingController siteController = TextEditingController();
  final TextEditingController samplingPointController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  Position? _userLocation;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  void _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
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

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _userLocation = position;
    });
  }

  void _saveData() async {
    String site = siteController.text.trim();
    String samplingPoint = samplingPointController.text.trim();
    String note = noteController.text.trim();

    if (widget.collectedData.isEmpty ||
        _userLocation == null ||
        site.isEmpty ||
        samplingPoint.isEmpty) {
      print("Incomplete data");
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$site/${samplingPoint}_ble_data.txt';
    final file = File(filePath);
    print("FILEPATH: $filePath");

    // Header
    String header = """
TIME:\t${DateTime.now().toString()}
SITE:\t$site
POINT:\t$samplingPoint
LONGITUDE:\t${_userLocation!.longitude}
LATITUDE:\t${_userLocation!.latitude}
NOTE:\t$note

FLUX RECORD TRACKS
#\tsec\tCO2\tAirHumidity\tBatteryVoltage\tAirTemp\tBarometricPressure
""";
//  \tCH4\tVOC

    // Determine the maximum length of any parameter's data list
    int maxLength = widget.collectedData.values
        .map((list) => list.length)
        .reduce((a, b) => a > b ? a : b);

    // Initialize rows
    List<String> rows = [];

    // Populate rows with data
    for (int i = 0; i < maxLength; i++) {
      // Calculate elapsed time in seconds
      double elapsedTime = i.toDouble();
      int point = i + 1;
      // Start building the row
      String row = "$point\t${elapsedTime.toStringAsFixed(1)}";

      // Add values for each parameter (repeat the last value if not enough data points)
      row += "\t${_getRepeatedValue(widget.collectedData, "CO2", i)}";
      // row += "\t${_getRepeatedValue(widget.collectedData, "CH4", i)}";
      // row += "\t${_getRepeatedValue(widget.collectedData, "VOC", i)}";
      row += "\t${_getRepeatedValue(widget.collectedData, "Air Humidity", i)}";
      row +=
          "\t${_getRepeatedValue(widget.collectedData, "Battery Voltage", i)}";
      row +=
          "\t${_getRepeatedValue(widget.collectedData, "Air Temperature", i)}";
      row +=
          "\t${_getRepeatedValue(widget.collectedData, "Barometric Pressure", i)}";

      rows.add(row);
    }

    // Write the content to the file
    String content = header + rows.join("\n");
    await file.writeAsString(content);
    final _auth = FirebaseAuth.instance;
    User? user = _auth.currentUser;

    if (_auth.currentUser != null) {
      final db = FirebaseFirestore.instance;
      DocumentSnapshot ds = await db.collection('projects').doc(site).get();
      if (ds.exists == false) {
        db.collection('projects').doc(site).set(
          {
            'name': site,
            'members': {user?.uid: 'owner'},
          },
        );

        Map? projectMember;
        FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get()
            .then((DocumentSnapshot documentSnapshot) {
          projectMember = documentSnapshot.get('projects');
          if (projectMember != null) {
            projectMember![site] = 'owner';
            db
                .collection('users')
                .doc(user?.uid)
                .update({'projects': projectMember});
          } else {
            projectMember![site] = 'owner';
            db
                .collection('users')
                .doc(user?.uid)
                .set({'projects': projectMember});
          }
        });
      }
    }
    // final sandbox = SandBox();
    final sandBox = widget.ref.read(sandBoxProvider);
    await sandBox.makeSingleDataPoint(
        "${directory.path}/$site/${samplingPoint}_ble_data.txt", site);
    print('Data saved to $filePath');
    widget.collectedData.clear();
    Navigator.of(context).pop();
  }

  String _getRepeatedValue(
      Map<String, List<Map<String, dynamic>>> collectedData,
      String parameter,
      int index) {
    List<Map<String, dynamic>> dataList = collectedData[parameter] ?? [];

    // If no data, return default
    if (dataList.isEmpty) {
      return "0.00";
    }

    // If index is out of bounds, use the last available value
    int safeIndex = index < dataList.length ? index : dataList.length - 1;

    print("$parameter: ${dataList.length} values, accessing index: $safeIndex");

    return (dataList[safeIndex]["value"] as double).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Save acquired data"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: siteController,
              decoration: InputDecoration(labelText: "Site*"),
            ),
            TextField(
              controller: samplingPointController,
              decoration: InputDecoration(labelText: "Sampling point*"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: noteController,
              decoration: InputDecoration(labelText: "Note"),
            ),
            SizedBox(height: 10),
            if (_userLocation != null)
              Text(
                "Lon: ${_userLocation!.longitude.toStringAsFixed(8)} Lat: ${_userLocation!.latitude.toStringAsFixed(8)}",
              )
            else
              Text("Fetching location..."),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _saveData,
          child: Text("Save"),
        ),
      ],
    );
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});
}

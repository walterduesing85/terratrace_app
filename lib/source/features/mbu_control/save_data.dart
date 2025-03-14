import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:terratrace/source/features/data/data/sand_box.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:utm/utm.dart';
// import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:terratrace/source/constants/constants.dart';
import 'stats_func.dart';
import 'utils.dart';

class SaveDataPopup extends ConsumerStatefulWidget {
  final Map<String, List<Map<String, dynamic>>> collectedData;
  final WidgetRef ref;
  final Map<String, Map<String, List<double>>> r2SlopeMap;
  const SaveDataPopup({
    required this.collectedData,
    required this.ref,
    required this.r2SlopeMap,
    Key? key,
  }) : super(key: key);

  @override
  _SaveDataPopupState createState() => _SaveDataPopupState();
}

class _SaveDataPopupState extends ConsumerState<SaveDataPopup> {
  late final TextEditingController siteController;
  late final TextEditingController samplingPointController;
  final TextEditingController noteController = TextEditingController();
  final List<String> flxParams = ["CO2HiFs", "VOC", "CH4", "H2O", "CO2"];
  Position? _userLocation;
  var utmResult;
  bool _isLoading = false;
  double chamberDiameter = 200;
  double chamberHeight = 100;
  String project = "";

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    final pointCount = ref.read(dataPointCountProvider);
    final projectName = ref.read(projectNameProvider);
    setState(() {
      project = projectName;
      siteController = TextEditingController(text: projectName.toString());
      samplingPointController =
          TextEditingController(text: pointCount.toString());
    });
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

    Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      forceLocationManager: true, // Forces use of the Android location manager
      intervalDuration:
          const Duration(milliseconds: 500), // More frequent updates
    ));

    setState(() {
      _userLocation = position;
      utmResult =
          UTM.fromLatLon(lat: position.latitude, lon: position.longitude);
    });
  }

  Future<String> _saveData() async {
    String site = siteController.text.trim();
    String samplingPoint = samplingPointController.text.trim();
    String note = noteController.text.trim();
    // double chamberArea = pi * pow(chamberDiameter / 2, 2) / 1e6;
    // double chamberVolume =
    //     pi * pow(chamberDiameter / 2, 2) * chamberHeight / 1e9;
    // double avgPressure = 1013.15;
    // double avgTemp = 20;

    if (widget.collectedData.isEmpty ||
        _userLocation == null ||
        site.isEmpty ||
        samplingPoint.isEmpty) {
      print("Incomplete data");
      return "";
    }

    // final directory = await getApplicationDocumentsDirectory();
    Directory directory = Directory('/storage/emulated/0/Documents');
    final filePath = '${directory.path}/${site}_${samplingPoint}_ble_data.txt';
    final file = File(filePath);
    print("FILEPATH: $filePath");

    // Determine hemisphere manually based on latitude
    String hemisphere = _userLocation!.latitude >= 0 ? "N" : "S";

    // EPSG Code (WGS 84 UTM zone-based)
    int epsg = utmResult.zoneNumber + (hemisphere == "N" ? 32600 : 32700);
    String dataDate = DateTime.now().toString();
    String projectId = samplingPoint == '1'
        ? '${site.replaceAll(' ', '')}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}'
        : site;

    // Build the dataMap with all the required fields.
    Map<String, dynamic> dataMap = {
      'dataDate': dataDate, // TIME
      'dataSite': samplingPoint == '1' ? site : site.split('_')[0], // SITE
      'dataPoint': samplingPoint, // POINT
      'dataLong': _userLocation!.longitude, // LONGITUDE
      'dataLat': _userLocation!.latitude, // LATITUDE
      'dataEasting': utmResult.easting, // EASTING
      'dataNorthing': utmResult.northing, // NORTHING
      'dataZone':
          '${utmResult.zoneNumber}${utmResult.zoneLetter}', // ZONE NUMBER
      // 'dataZoneLetter': , // ZONE LETTER
      'dataHemisphere': hemisphere, // HEMISPHERE
      'dataEPSG': epsg, // EPSG
      'dataLocationAccuracy':
          _userLocation!.accuracy.toStringAsFixed(1), // LOCATION ACCURACY
      'dataNote': note, // NOTE

      // Additional fields (initialized to null if not provided yet)
      // 'dataKey': null,
      'dataInstrument': widget.r2SlopeMap.keys
    };

    // Header
    String header = """
TIME:\t$dataDate
SITE:\t$site
POINT:\t$samplingPoint
LONGITUDE:\t${_userLocation!.longitude}
LATITUDE:\t${_userLocation!.latitude}
EASTING:\t${utmResult.easting}
NORTHING:\t${utmResult.northing}
ZONE:\t'${utmResult.zoneNumber}${utmResult.zoneLetter}'
HEMISPHERE:\t$hemisphere
EPSG:\t$epsg
LOCATION ACCURACY:\t${_userLocation!.accuracy.toStringAsFixed(1)} meters

NOTE:\t$note

PARAMETER ANALYSIS
""";

    late DocumentReference projectDoc;

    final _auth = FirebaseAuth.instance;
    User? user = _auth.currentUser;

    // Initialize rows
    List<String> rows = [];

    if (_auth.currentUser != null) {
      final db = FirebaseFirestore.instance;
// Query for project documents with the given site name.
      QuerySnapshot querySnapshot =
          await db.collection('projects').where('name', isEqualTo: site).get();

      bool userHasAccess = false;

      // Check if the current user is listed in any of the project's members.
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> members = doc['members'] as Map<String, dynamic>;
        if (members.containsKey(user?.uid)) {
          projectDoc = doc.reference;
          userHasAccess = true;
          break;
        }
      }

      // If no accessible project document exists, create one with the current user as owner.
      if (!userHasAccess) {
        projectDoc = db.collection('projects').doc(projectId);
        await projectDoc.set({
          'name': site,
          'members': {user?.uid: 'owner'},
          'mbus': widget.r2SlopeMap.keys
        });

        DocumentReference userDocRef = db.collection('users').doc(user?.uid);

        userDocRef.get().then((DocumentSnapshot documentSnapshot) {
          Map<String, dynamic> projectMember = {};

          if (documentSnapshot.exists) {
            var projectsField = documentSnapshot.get('projects');
            if (projectsField != null && projectsField is Map) {
              projectMember = Map<String, dynamic>.from(projectsField);
            }
          }

          // Now add your new project
          projectMember[projectId] = 'owner';

          // Write the updated map to Firestore
          userDocRef.set({'projects': projectMember}, SetOptions(merge: true));
        });
        ref.read(dataPointCountProvider.notifier).setDataPointCount(1);
      }

      // Loop through each parameter in collectedData
      await Future.forEach(widget.collectedData.entries,
          (MapEntry<String, List<Map<String, dynamic>>> entry) async {
        final param = entry.key;
        final data = entry.value;
        // Create a reference to the subcollection for the current parameter
        CollectionReference paramCollection = projectDoc
            .collection('time-series')
            .doc(param) // a document representing this parameter
            .collection(samplingPoint); // its data points

        // Add parameter-specific table header
        String paramHeader = "\n$param:\n#\tTIME (sec)\t$param\n";

        // Initialize statistics using the first value.
        double firstValue = data.first["value"].toDouble();
        double minVal = firstValue;
        double maxVal = firstValue;
        double mean = 0.0;
        double M2 = 0.0;
        int count = 0;

        // Populate rows for this parameter
        await Future.wait(data.asMap().entries.map((mapEntry) async {
          final i = mapEntry.key;
          double value = data[i]["value"].toDouble();

          // Build row for the parameter
          String row = "${i + 1}\t${data[i]["sec"]}\t${data[i]["value"]}";
          paramHeader += row + "\n";

          if (!flxParams.contains(param.split("-")[0])) {
            if (value < minVal) minVal = value;
            if (value > maxVal) maxVal = value;
          }

          count++;
          // Welford's algorithm: update mean and M2
          double delta = value - mean;
          mean += delta / count;
          double delta2 = value - mean;
          M2 += delta * delta2;

          // Use the index as the document ID (as a string).
          await paramCollection.doc(i.toString()).set({
            'timestamp': data[i]["timestamp"].toIso8601String(),
            'elapsedTime': data[i]["sec"],
            'value': data[i]["value"],
          });
        })); //.toList());

        if (!flxParams.contains(param.split("-")[0])) {
          // Calculate average and standard deviation
          double avg = mean;
          double variance = count > 1
              ? M2 / count
              : 0.0; // use count - 1 for sample variance if needed
          double stdDev = sqrt(variance);

          dataMap['${param}Max'] = maxVal.toStringAsFixed(2);
          dataMap['${param}Min'] = minVal.toStringAsFixed(2);
          dataMap['${param}Avg'] = avg.toStringAsFixed(2);
          dataMap['${param}Std'] = stdDev.toStringAsFixed(2);

          header += "$param:\n";
          header += "  MIN: ${minVal.toStringAsFixed(2)}\n";
          header += "  MAX: ${maxVal.toStringAsFixed(2)}\n";
          header += "  AVG: ${avg.toStringAsFixed(2)}\n";
          header += "  STD.DEV.: ${stdDev.toStringAsFixed(2)}\n\n";
        }

        // Add the parameter table to the content
        rows.add(paramHeader);
      });

      // Adding R² and slope for each parameter in r2SlopeMap
      widget.r2SlopeMap.forEach((device, parameters) {
        parameters.forEach((param, values) {
          if (values.length >= 4) {
            double leftBound = values[0];
            double rightBound = values[1];
            double rSquared = values[3];
            double slope = values[2];
            int leftIndex = values[4].toInt();
            int rightIndex = values[5].toInt();
            var dataForIndex = widget
                .collectedData["$param${device.replaceAll("Terratrace", "")}"];
            // double constGas = 8.314;

            // double k = (86400 * avgPressure * (chamberHeight / 1000)) /
            //     (1000000 * gasConstant * avgTemp);
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
            header +=
                "  Flux [g/(m2*day)]: ${fluxInGrams.toStringAsFixed(2)}\n";
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
      DocumentReference dataDocRef =
          projectDoc.collection('data').doc(samplingPoint);
      // Save the entire dataMap to the document in the 'data' subcollection.
      await dataDocRef.set(dataMap);
    }

    header += "FLUX RECORD TRACKS\n";

// Combine header and all rows (separate tables for each parameter)
    String content = header + rows.join("\n");

// Write the content to the file
    await file.writeAsString(content);
    ref.watch(projectNameProvider.notifier).setProjectName(projectId);
    ref
        .watch(dataPointCountProvider.notifier)
        .setDataPointCount(int.parse(samplingPoint) + 1);
    print('Data saved to $filePath');
    widget.collectedData.clear();
    return filePath;
    // Navigator.pop(context, true);
    // Navigator.of(context).pop();
  }

  @override
  void dispose() {
    siteController.dispose();
    samplingPointController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Save acquired data"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _isLoading
              ? [
                  Container(
                    // Semi-transparent dark background
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Card(
                        color: Colors.black.withOpacity(0.6),
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFFAEEA00),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Processing data...",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFAEEA00)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                ]
              : [
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
          onPressed: () => Navigator.pop(context, false),
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            setState(() {
              _isLoading = true;
            });
            try {
              String filepath = await _saveData();
              setState(() {
                _isLoading = false;
              });

              // Notify the user that the file has been downloaded
              showDownloadMessage(context);
              Navigator.pop(context, true);
              return showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Share BLE txt file'),
                    content: Text('Do you want to share the txt file?'),
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
            } catch (e) {
              print(e);
              // Handle error (if necessary)
              final errorSnackBar = SnackBar(
                content: Text('Failed to download the file. Please try again!'),
                duration: Duration(seconds: 2),
              );
              ScaffoldMessenger.of(context).showSnackBar(errorSnackBar);
            }
          },
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

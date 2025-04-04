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
import 'package:flutter/foundation.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'utils.dart';

class SaveDataPopup extends ConsumerStatefulWidget {
  final Map<String, List<Map<String, dynamic>>> collectedData;
  final WidgetRef ref;
  final Map<String, Map<String, List<double>>> r2SlopeMap;
  final Position userLocation;
  const SaveDataPopup({
    required this.collectedData,
    required this.ref,
    required this.r2SlopeMap,
    required this.userLocation,
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
  // Position? userLocation;
  var utmResult;
  bool _isLoading = false;
  double chamberDiameter = 200;
  double chamberHeight = 100;
  String project = "";
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final pointCount = ref.read(dataPointCountProvider);
    final projectName = ref.read(projectNameProvider);
    setState(() {
      project = projectName;
      siteController = TextEditingController(text: projectName.toString());
      samplingPointController =
          TextEditingController(text: pointCount.toString());
      utmResult = UTM.fromLatLon(
          lat: widget.userLocation.latitude,
          lon: widget.userLocation.longitude);
    });
  }

  Future<String> _saveData() async {
    String site = siteController.text.trim();
    String samplingPoint = samplingPointController.text.trim();
    String note = noteController.text.trim();

    if (widget.collectedData.isEmpty ||
        widget.userLocation == null ||
        site.isEmpty ||
        samplingPoint.isEmpty) {
      print("Incomplete data");
      return "";
    }

    Directory directory = Directory('/storage/emulated/0/Documents');

    String hemisphere = widget.userLocation!.latitude >= 0 ? "N" : "S";
    int epsg = utmResult.zoneNumber + (hemisphere == "N" ? 32600 : 32700);
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String dataDate = formatter.format(DateTime.now());

    String projectId = samplingPoint == '1'
        ? '${site.replaceAll(' ', '')}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}'
        : site;
    final filePath =
        '${directory.path}/${projectId}_Sampling#${samplingPoint}.txt';
    final file = File(filePath);
    print("FILEPATH: $filePath");

    // Build the dataMap with all the required fields.
    Map<String, dynamic> dataMap = {
      'dataDate': dataDate,
      'dataSite': samplingPoint == '1' ? site : site.split('_')[0],
      'dataPoint': samplingPoint,
      'dataLong': widget.userLocation!.longitude,
      'dataLat': widget.userLocation!.latitude,
      'dataEasting': utmResult.easting,
      'dataNorthing': utmResult.northing,
      'dataZone': '${utmResult.zoneNumber}${utmResult.zoneLetter}',
      'dataHemisphere': hemisphere,
      'dataEPSG': epsg,
      'dataLocationAccuracy': widget.userLocation!.accuracy.toStringAsFixed(1),
      'dataNote': note,
      'dataInstrument': widget.r2SlopeMap.keys
    };

    // Header
    String header = """
TIME:\t$dataDate
SITE:\t$site
POINT:\t$samplingPoint
LONGITUDE:\t${widget.userLocation!.longitude}
LATITUDE:\t${widget.userLocation!.latitude}
EASTING:\t${utmResult.easting}
NORTHING:\t${utmResult.northing}
ZONE:\t'${utmResult.zoneNumber}${utmResult.zoneLetter}'
HEMISPHERE:\t$hemisphere
EPSG:\t$epsg
LOCATION ACCURACY:\t${widget.userLocation!.accuracy.toStringAsFixed(1)} meters

NOTE:\t$note

PARAMETER ANALYSIS
""";

    late DocumentReference projectDoc;
    final _auth = FirebaseAuth.instance;
    User? user = _auth.currentUser;
    List<String> rows = [];

    if (_auth.currentUser != null) {
      final db = FirebaseFirestore.instance;
      var doc = await db.collection('projects').doc(projectId).get();

      bool userHasAccess = false;

      if (doc.exists) {
        Map<String, dynamic> members = doc['members'] as Map<String, dynamic>;
        if (members.containsKey(user?.uid)) {
          projectDoc = doc.reference;
          userHasAccess = true;
        }
      }

      if (!userHasAccess) {
        projectDoc = db.collection('projects').doc(projectId);
        await projectDoc.set({
          'name': site,
          'members': {user?.uid: 'owner'},
          'mbus': widget.r2SlopeMap.keys
        });

        DocumentReference userDocRef = db.collection('users').doc(user?.uid);
        await userDocRef.get().then((DocumentSnapshot documentSnapshot) {
          Map<String, dynamic> projectMember = {};
          if (documentSnapshot.exists) {
            var projectsField = documentSnapshot.get('projects');
            if (projectsField != null && projectsField is Map) {
              projectMember = Map<String, dynamic>.from(projectsField);
            }
          }
          projectMember[projectId] = 'owner';
          userDocRef.set({'projects': projectMember}, SetOptions(merge: true));
        });
        ref.read(dataPointCountProvider.notifier).setDataPointCount(1);
      }

      // Process all parameters in parallel
      await Future.wait(widget.collectedData.entries.map((entry) async {
        final param = entry.key;
        final data = entry.value;

        // Create a batch for this parameter
        WriteBatch batch = db.batch();
        CollectionReference paramCollection = projectDoc
            .collection('time-series')
            .doc(param)
            .collection(samplingPoint);

        // Process statistics in parallel
        final statsFuture = compute(
          (Map<String, dynamic> params) {
            final data = params['data'] as List<Map<String, dynamic>>;
            final param = params['param'] as String;
            final flxParams = params['flxParams'] as List<String>;

            if (!flxParams.contains(param.split("-")[0])) {
              double minVal = double.infinity;
              double maxVal = double.negativeInfinity;
              double sum = 0.0;
              double sumSquared = 0.0;

              for (var point in data) {
                double value = point["value"].toDouble();
                minVal = min(minVal, value);
                maxVal = max(maxVal, value);
                sum += value;
                sumSquared += value * value;
              }

              double mean = sum / data.length;
              double variance = (sumSquared / data.length) - (mean * mean);
              double stdDev = sqrt(variance);

              return {
                'min': minVal,
                'max': maxVal,
                'mean': mean,
                'stdDev': stdDev,
                'isFlx': false
              };
            }
            return {'isFlx': true};
          },
          {
            'data': data,
            'param': param,
            'flxParams': flxParams,
          },
        );

        // Build parameter header and rows
        String paramHeader = "\n$param:\n#\tTIME (sec)\t$param\n";
        List<String> paramRows = [];

        // Process data points in chunks for better performance
        const chunkSize = 500;
        for (var i = 0; i < data.length; i += chunkSize) {
          final chunk = data.skip(i).take(chunkSize);
          final chunkRows = chunk.map((point) {
            final index = i + data.indexOf(point);
            return "${index + 1}\t${point["sec"]}\t${point["value"]}";
          }).toList();
          paramRows.addAll(chunkRows);

          // Add documents to batch
          for (var point in chunk) {
            final docRef = paramCollection.doc(data.indexOf(point).toString());
            batch.set(docRef, {
              'timestamp': point["timestamp"].toIso8601String(),
              'elapsedTime': point["sec"],
              'value': point["value"],
            });
          }
        }

        // Commit the batch
        await batch.commit();

        // Add parameter header and rows
        paramHeader += paramRows.join('\n');
        rows.add(paramHeader);

        // Process statistics
        final stats = await statsFuture;
        if (stats['isFlx'] == false) {
          final minVal = stats['min'] as double;
          final maxVal = stats['max'] as double;
          final mean = stats['mean'] as double;
          final stdDev = stats['stdDev'] as double;

          dataMap['${param}Max'] = maxVal.toStringAsFixed(2);
          dataMap['${param}Min'] = minVal.toStringAsFixed(2);
          dataMap['${param}Avg'] = mean.toStringAsFixed(2);
          dataMap['${param}Std'] = stdDev.toStringAsFixed(2);

          header += "$param:\n";
          header += "  MIN: ${minVal.toStringAsFixed(2)}\n";
          header += "  MAX: ${maxVal.toStringAsFixed(2)}\n";
          header += "  AVG: ${mean.toStringAsFixed(2)}\n";
          header += "  STD.DEV.: ${stdDev.toStringAsFixed(2)}\n\n";
        }
      }));

      // Process R² and slope data
      widget.r2SlopeMap.forEach((device, parameters) {
        parameters.forEach((param, values) {
          if (values.length >= 4) {
            double leftBound = values[0];
            double rightBound = values[1];
            double rSquared = values[3];
            double slope = values[2];
            int leftIndex = values[4].toInt();
            int rightIndex = values[5].toInt();
            double fluxInMoles = values[6];
            double fluxInGrams = fluxInMoles * molarMassCO2;
            String prefix = "$param-${device.replaceAll("Terratrace-", "")}";
            double fluxError = values[7];

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

      // Save the dataMap to Firestore
      DocumentReference dataDocRef =
          projectDoc.collection('data').doc(samplingPoint);
      await dataDocRef.set(dataMap);
    }

    header += "FLUX RECORD TRACKS\n";
    String content = header + rows.join("\n");
    await file.writeAsString(content);

    ref.watch(projectNameProvider.notifier).setProjectName(projectId);
    ref
        .watch(dataPointCountProvider.notifier)
        .setDataPointCount(int.parse(samplingPoint) + 1);
    print('Data saved to $filePath');
    widget.collectedData.clear();
    return filePath;
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _isLoading
                ? [
                    Container(
                      decoration: BoxDecoration(
                          // color: Colors.white,
                          ),
                      child: Center(
                        child: Card(
                          // color: Colors.black.withOpacity(0.6),
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
                    TextFormField(
                      controller: siteController,
                      decoration: InputDecoration(labelText: "Site*"),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Site is required';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: samplingPointController,
                      decoration: InputDecoration(labelText: "Sampling point*"),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Sampling point is required';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: noteController,
                      decoration: InputDecoration(labelText: "Note"),
                    ),
                    SizedBox(height: 10),
                    if (widget.userLocation != null)
                      Text(
                        "Lon: ${widget.userLocation!.longitude.toStringAsFixed(8)}  Lat: ${widget.userLocation!.latitude.toStringAsFixed(8)}",
                      )
                    else
                      Text("Fetching location...Please wait."),
                  ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            "Cancel",
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            // Validate the form fields first.
            if (!_formKey.currentState!.validate()) {
              return; // Don't proceed if validation fails.
            }
            setState(() {
              _isLoading = true;
            });
            try {
              // String filepath =
              await _saveData();
              setState(() {
                _isLoading = false;
              });

              // Notify the user that the file has been downloaded
              showDownloadMessage(context, 'File has been downloaded!');
              Navigator.pop(context, true);
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

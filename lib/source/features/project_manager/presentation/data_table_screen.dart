import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:terratrace/source/routing/app_router.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/mbu_control/save_csv.dart';

class DataTableScreen extends StatefulWidget {
  final String? project;
  const DataTableScreen({Key? key, required this.project}) : super(key: key);

  @override
  _DataTableScreenState createState() => _DataTableScreenState();
}

class _DataTableScreenState extends State<DataTableScreen> {
  bool isLoading = true;
  List<String> headers = [];
  List<List<dynamic>> rows = [];
  late CustomDataGridSource _dataGridSource;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    NumberFormat formatter = NumberFormat("0.000E+0", "en_US");
    try {
      // Load the JSON definitions
      String jsonString = await rootBundle.loadString('assets/mbus.json');
      Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // Get the project document to get the mbus list
      final mbusDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project)
          .get();
      final mbus = mbusDoc.data()!['mbus'];

      // Build headers based on JSON definitions
      headers = [
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

      // Add FLX and EPV parameter headers
      for (var deviceName in mbus) {
        if (jsonData.containsKey(deviceName)) {
          var parameters = jsonData[deviceName];
          for (var param in parameters) {
            final paramFirestore =
                '${param["Name"]}${deviceName.replaceAll("Terratrace", "")}';
            if (param['Class'] == 'FLX') {
              headers.add('${param["Name"]} Flux [moles/(m2*day)]');
              headers.add('${param["Name"]} Slope [ppm/sec]');
              headers.add('${param["Name"]} r2');
              headers.add('${param["Name"]} Flux error [%]');
            }
            if (param['Class'] == 'EPV') {
              headers.add('${param["Name"]} Average [${param["Unit"]}]');
              headers.add('${param["Name"]} Max [${param["Unit"]}]');
              headers.add('${param["Name"]} Min [${param["Unit"]}]');
              headers.add('${param["Name"]} Std.Dev. [${param["Unit"]}]');
            }
          }
        }
      }

      // Query Firestore collection "data" under the project
      final collectionSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project)
          .collection("data")
          .get();
      final docs = collectionSnapshot.docs;

      // Sort the documents based on 'dataPoint' field
      docs.sort((a, b) {
        int dataPointA = int.tryParse(a.data()['dataPoint'] ?? '0') ?? 0;
        int dataPointB = int.tryParse(b.data()['dataPoint'] ?? '0') ?? 0;
        return dataPointA.compareTo(dataPointB);
      });

      // Build rows for each document
      for (var doc in docs) {
        Map<String, dynamic> data = doc.data();
        List<dynamic> row = [];

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

        // Add basic fields
        row.addAll([
          formattedDate,
          formattedTime,
          widget.project,
          data['dataSite'] ?? '',
          data['dataPoint'] ?? '',
          data['dataLat'] ?? '',
          data['dataLong'] ?? '',
          data['dataEasting'] ?? '',
          data['dataNorthing'] ?? '',
          data['dataZone'] ?? '',
          data['dataEPSG'] ?? '',
          data['dataLocationAccuracy'] ?? '',
        ]);

        // Add FLX and EPV parameter values
        for (var deviceName in mbus) {
          if (jsonData.containsKey(deviceName)) {
            var parameters = jsonData[deviceName];
            for (var param in parameters) {
              final paramFirestore =
                  '${param["Name"]}${deviceName.replaceAll("Terratrace", "")}';
              if (param['Class'] == 'FLX') {
                row.addAll([
                  param["Name"] == "CH4"
                      ? formatter.format(data['${paramFirestore}FluxMoles'])
                      : data['${paramFirestore}FluxMoles'] ?? '',
                  param["Name"] == "CH4"
                      ? formatter.format(data['${paramFirestore}Slope'])
                      : data['${paramFirestore}Slope'] ?? '',
                  data['${paramFirestore}RSquared'] ?? '',
                  data['${paramFirestore}FluxError'] ?? '',
                ]);
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
        rows.add(row);
      }

      // Create data grid source
      _dataGridSource = CustomDataGridSource(rows: rows, headers: headers);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Loading Data")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Build grid columns
    List<GridColumn> gridColumns = headers.map((header) {
      return GridColumn(
        columnName: header,
        label: Container(
          color: const Color.fromARGB(255, 31, 32, 31),
          padding: EdgeInsets.all(8),
          alignment: Alignment.center,
          child: Text(
            header,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choose Sampling Point",
              style: TextStyle(
                color: kGreenFluxColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Click on any cell to adjust boundaries within a corresponding Sampling # row.",
              style: TextStyle(color: Colors.white70, fontSize: 12),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
      ),
      body: SfDataGrid(
        source: _dataGridSource,
        columns: gridColumns,
        frozenRowsCount: 1, // Freeze the first row (headers)
        columnWidthMode: ColumnWidthMode.auto,
        onCellTap: (DataGridCellTapDetails details) {
          if (details.rowColumnIndex.rowIndex > 0) {
            // Skip header row
            context.pushNamed(
              AppRoute.reselectScreen.name,
              pathParameters: {
                'project': widget.project!,
                'samplingPoint':
                    rows[details.rowColumnIndex.rowIndex - 1][4].toString(),
              },
            );
          }
        },
      ),
    );
  }
}

class CustomDataGridSource extends DataGridSource {
  final List<String> headers;
  List<DataGridRow> _dataGridRows = [];

  CustomDataGridSource({
    required List<List<dynamic>> rows,
    required this.headers,
  }) : super() {
    _dataGridRows = rows.map<DataGridRow>((row) {
      return DataGridRow(
        cells: row.asMap().entries.map<DataGridCell<dynamic>>((entry) {
          return DataGridCell<dynamic>(
            columnName: headers[entry.key],
            value: entry.value,
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 75, 78, 85),
            border: Border.all(color: const Color.fromARGB(255, 173, 172, 172)),
          ),
          child: Text(
            cell.value.toString(),
            style: TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
    );
  }
}

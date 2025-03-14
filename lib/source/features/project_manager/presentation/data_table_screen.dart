import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:terratrace/source/routing/app_router.dart'; // Adjust the import path as needed

class DataTableScreen extends StatefulWidget {
  final String? project;
  const DataTableScreen({Key? key, required this.project}) : super(key: key);

  @override
  _DataTableScreenState createState() => _DataTableScreenState();
}

class _DataTableScreenState extends State<DataTableScreen> {
  bool isLoading = true;
  // Base friendly headers & corresponding Firestore field names.
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
  List<String> headersFirestore = [
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

  // Original table: one row per document; each row is a list of values
  List<List<dynamic>> rows = [];
  // Transposed table: each row corresponds to one field (first element is the friendly name, then one value per document)
  List<List<dynamic>> transposedData = [];

  late TransposedDataGridSource _dataGridSource;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load the JSON definitions.
    String jsonString = await rootBundle.loadString('assets/mbus.json');
    Map<String, dynamic> jsonData = jsonDecode(jsonString);

    // Query Firestore collection "data" under the project.
    final collectionSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.project)
        .collection("data")
        .get();
    final docs = collectionSnapshot.docs;

    // Sort the documents based on 'dataPoint' field after converting it to integer
    docs.sort((a, b) {
      // Convert 'dataPoint' to integer for sorting
      int dataPointA = int.tryParse(a.data()['dataPoint'] ?? '0') ?? 0;
      int dataPointB = int.tryParse(b.data()['dataPoint'] ?? '0') ?? 0;
      return dataPointA.compareTo(dataPointB);
    });

    // Retrieve the project document to get the mbus list.
    final mbusDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.project)
        .get();
    final mbus = mbusDoc.data()!['mbus'];

    // Build additional headers based on JSON definitions.
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
            headersFirestore.add('${paramFirestore}FluxMoles');
            headersFirestore.add('${paramFirestore}Slope');
            headersFirestore.add('${paramFirestore}RSquared');
            headersFirestore.add('${paramFirestore}FluxError');
          }
          if (param['Class'] == 'EPV') {
            headers.add('${param["Name"]} Average [${param["Unit"]}]');
            headers.add('${param["Name"]} Max [${param["Unit"]}]');
            headers.add('${param["Name"]} Min [${param["Unit"]}]');
            headers.add('${param["Name"]} Std.Dev. [${param["Unit"]}]');
            headersFirestore.add('${paramFirestore}Avg');
            headersFirestore.add('${paramFirestore}Max');
            headersFirestore.add('${paramFirestore}Min');
            headersFirestore.add('${paramFirestore}Std');
          }
        }
      }
    }

    // Build rows for each document.
    for (var doc in docs) {
      Map<String, dynamic> data = doc.data();
      List<dynamic> row = [];
      // For each field name (from headersFirestore), get the value.
      for (var field in headersFirestore) {
        row.add(data[field] ?? '');
      }
      // Process date/time:
      // Assume row[0] contains the date string.
      String tempDateStr = row[0];
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
      // Set the Project ID column (index 2) to widget.project.
      row[2] = widget.project;
      rows.add(row);
    }

    // Transpose the table.
    int numFields = headers.length;
    int numDocs = rows.length;
    transposedData = List.generate(numFields, (_) => []);
    for (int i = 0; i < numFields; i++) {
      // The first cell is the friendly header.
      transposedData[i].add(headers[i]);
      for (int j = 0; j < numDocs; j++) {
        transposedData[i].add(rows[j][i]);
      }
    }

    // Create data rows for the data grid source.
    List<TransposedDataRow> dataRows = transposedData.map((row) {
      return TransposedDataRow(
        field: row[0].toString(),
        values: row.sublist(1).map((e) => e.toString()).toList(),
      );
    }).toList();
    _dataGridSource = TransposedDataGridSource(
      data: dataRows,
    );

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
          appBar: AppBar(title: Text("Loading Data")),
          body: Center(child: CircularProgressIndicator()));
    }

    // Build grid columns: first column for field names, then one column per document.
    int numDocColumns =
        transposedData.isNotEmpty ? transposedData[0].length - 1 : 0;
    List<GridColumn> gridColumns = [];
    // First column (frozen) with field names.
    gridColumns.add(GridColumn(
      width: 130,
      columnName: 'Field',
      label: Container(
        color: Color(0xFFAEEA00),
        padding: EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text("Field", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ));
    for (int i = 0; i < numDocColumns; i++) {
      gridColumns.add(GridColumn(
        columnName: 'Doc${i + 1}',
        label: Container(
          color: Color(0xFFAEEA00),
          padding: EdgeInsets.all(8),
          alignment: Alignment.center,
          child: Text("Sampling #${i + 1}",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align text to the left
          mainAxisSize:
              MainAxisSize.min, // Ensures the column takes minimal height
          children: [
            Text(
              "Choose Sampling Point",
              style: TextStyle(
                  color: Color(0xFFAEEA00),
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2), // Small spacing between title and subtitle
            Text(
              "Click on any cell to adjust boundaries within a corresponding Sampling # column.",
              style: TextStyle(color: Colors.white70, fontSize: 12),
              softWrap: true,
              maxLines: 2, // Limits to 2 lines
              overflow: TextOverflow.visible, // Allows text to wrap
            ),
          ],
        ),
      ),
      body: SfDataGrid(
        source: _dataGridSource,
        columns: gridColumns,
        frozenColumnsCount: 1, // Freeze the first column (field names)
        columnWidthMode: ColumnWidthMode.auto,
        onCellTap: (DataGridCellTapDetails details) {
          // int samplingRowIndex =
          //     headers.indexOf("Sampling #"); // Find row for "Sampling #"

          // Ensure the tap is on a valid cell (not the headers)
          if (details.rowColumnIndex.columnIndex > 0) {
            context.pushNamed(
              AppRoute.reselectScreen.name,
              pathParameters: {
                'project': widget.project!,
                'samplingPoint': details.rowColumnIndex.columnIndex.toString(),
              },
            );
          }
        },
      ),
    );
  }
}

class TransposedDataRow {
  final String field;
  final List<String> values;
  TransposedDataRow({required this.field, required this.values});
}

class TransposedDataGridSource extends DataGridSource {
  List<DataGridRow> _dataGridRows = [];

  TransposedDataGridSource({required List<TransposedDataRow> data}) {
    _dataGridRows = data.map<DataGridRow>((TransposedDataRow row) {
      List<DataGridCell<dynamic>> cells = [];
      cells.add(DataGridCell<String>(columnName: 'Field', value: row.field));
      for (int i = 0; i < row.values.length; i++) {
        cells.add(DataGridCell<String>(
            columnName: 'Doc${i + 1}', value: row.values[i]));
      }
      return DataGridRow(cells: cells);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    // int rowIndex = _dataGridRows.indexOf(row); // Get row index

    return DataGridRowAdapter(
      cells: row.getCells().asMap().entries.map<Widget>((entry) {
        int columnIndex = entry.key;
        // bool isHeaderRow = rowIndex == 0;
        bool isFirstColumn = columnIndex == 0;

        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isFirstColumn
                ? Color(0xFFD4FF80) // First column color
                : Colors.white), // Default color
            border: Border.all(color: Colors.grey.shade300), // Add border
          ),
          child: Text(
            entry.value.value.toString(),
            // style: TextStyle(
            //   fontWeight: isFirstColumn
            //       ? FontWeight.bold
            //       : FontWeight.normal, // Bold text for headers/fields
            //   color: Colors.black,
            // ),
          ),
        );
      }).toList(),
    );
  }
}

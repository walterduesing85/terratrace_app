import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';

class CommandsPopup extends StatefulWidget {
  // final List<BluetoothDevice> connectedDevices;
  final List<BluetoothService> services;
  final String command;

  const CommandsPopup({
    // required this.connectedDevices,
    required this.services,
    required this.command,
    Key? key,
  }) : super(key: key);

  @override
  _CommandsPopupState createState() => _CommandsPopupState();
}

class _CommandsPopupState extends State<CommandsPopup> {
  // final TextEditingController co2Controller = TextEditingController();
  final TextEditingController filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> sendCommand(Guid uuid, int value) async {
    // if (widget.connectedDevices.isEmpty) {
    //   print("Device not connected.");
    //   return;
    // }
    // Convert int to 4-byte Uint8List
    ByteData byteData = ByteData(4)..setInt32(0, value, Endian.little);
    Uint8List bytes = byteData.buffer.asUint8List();

    for (var service in widget.services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid == uuid && characteristic.properties.write) {
          print("WRITING THE COMMAND");
          await characteristic.write(bytes);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Send command"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ElevatedButton(
            //   onPressed: () {
            //     sendCommand(Guid("2a40"), 0);
            //   },
            //   child: Text('Set CO2 To 0'),
            // ),
            TextField(
              controller: filterController,
              decoration: InputDecoration(
                labelText: widget.command == "filter"
                    ? "Set Filter Value"
                    : "Set CO2 To Zero",
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            int value = int.parse(filterController.text.trim());
            sendCommand(
                Guid(widget.command == "filter" ? "2a3f" : "2a40"), value);
            Navigator.of(context).pop();
          },
          child: Text("Send"),
        ),
      ],
    );
  }
}

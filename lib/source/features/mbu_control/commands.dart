import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class CommandsPopup extends StatefulWidget {
  final BluetoothDevice? connectedDevice;
  final List<BluetoothService> services;
  final String command;

  const CommandsPopup({
    required this.connectedDevice,
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
    if (widget.connectedDevice == null) {
      print("Device not connected.");
      return;
    }

    for (var service in widget.services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid == uuid && characteristic.properties.write) {
          print("WRITING THE COMMAND");
          await characteristic.write([value]);
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

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

void showDownloadMessage(BuildContext context) {
  final snackBar = SnackBar(
    content: Text('File has been downloaded!'),
    duration: Duration(seconds: 2),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

Future<void> shareCSVFile(String filePath) async {
  final file = XFile(filePath);
  await Share.shareXFiles(
    [file],
    text: "Here's the file.",
    subject: "BLE Data",
  );
}

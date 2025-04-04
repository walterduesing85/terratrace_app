import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

void showDownloadMessage(BuildContext context, String text) {
  final snackBar = SnackBar(
    content: Text(text),
    duration: Duration(seconds: 2),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

Future<void> shareFile(String filePath) async {
  final file = XFile(filePath);
  await Share.shareXFiles(
    [file],
    text: "Here's the file.",
    subject: "BLE Data",
  );
}

Future<void> showCustomDialog({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmButtonText,
  required VoidCallback onConfirm,
  String cancelButtonText = 'Cancel',
}) async {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () async {
              onConfirm();
              Navigator.of(context).pop(); // Close the dialog after confirming
            },
            child: Text(confirmButtonText),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context)
                  .pop(); // Close the dialog without confirming
            },
            child: Text(
              cancelButtonText,
              style: TextStyle(color: Colors.white10),
            ),
          ),
        ],
      );
    },
  );
}

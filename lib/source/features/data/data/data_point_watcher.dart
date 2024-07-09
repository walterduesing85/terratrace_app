import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:terra_trace/source/constants/constants.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/data/data/sand_box.dart';
import 'package:watcher/watcher.dart';

class DataPointWatcher {
  static final DataPointWatcher _instance = DataPointWatcher._internal();
  factory DataPointWatcher(WidgetRef ref) {
    _instance.ref = ref;
    return _instance;
  }

  DataPointWatcher._internal();

  late WidgetRef ref;
  StreamSubscription<WatchEvent>? _subscription;

  void watchForFiles() async {
    print('hello from watchForFiles -__-_-_-_-_-_-_-_-_');
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('Storage permission not granted');
    }

    final watcher = DirectoryWatcher(directory);
    _subscription = watcher.events.listen((event) async {
      print('new event detected lets rock and roll');
      if (event.type == ChangeType.ADD) {
        final String filePath = event.path;
        await handleFile(filePath);
      }
    });
  }

  Future<void> handleFile(String filePath) async {
    print('new event detected lets rock and roll12');

    final project = ref.read(projectNameProvider);
    print('Project: $project');
    final sandBox = ref.read(sandBoxProvider);

    // Fetch hive box asynchronously

    if (project.isNotEmpty) {
      await sandBox.makeSingleDataPoint(filePath, project);
    } else {
      print('Project name is empty, cannot proceed');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

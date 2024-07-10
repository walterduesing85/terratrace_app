import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:terra_trace/source/features/data/data/data_point_watcher.dart';
import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';
import 'package:terra_trace/source/routing/app_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  // Ensure that the Flutter bindings are initialized in the same zone
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions
  final storageStatus = await Permission.storage.request();
  await Permission.location.request();

  if (storageStatus == PermissionStatus.granted) {
    print('Storage permission granted');
  } else if (storageStatus == PermissionStatus.denied) {
    print('Storage permission denied');
  } else if (storageStatus == PermissionStatus.permanentlyDenied) {
    print('Storage permission permanently denied, opening app settings');
    openAppSettings();
  }

  // Initialize Firebase
  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Run the app in the same zone
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  //static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          // Initialize the DataPointWatcher singleton with the ref
          final dataPointWatcher = DataPointWatcher(ref);

          // Initialize directly here
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              dataPointWatcher.watchForFiles();
            });
            _initialized = true;
          }

          ref.watch(remoteStreamingProvider);
          return MaterialApp.router(
            routerConfig: goRouter,
            // routeInformationParser: goRouter.routeInformationParser,
            // debugShowCheckedModeBanner: false,
            // routerDelegate: goRouter.routerDelegate,
          );
        },
      ),
    );
  }

  static bool _initialized = false;
}

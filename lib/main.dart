import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/data/data/data_point_watcher.dart';
import 'package:terra_trace/source/features/data/data/sand_box.dart';

import 'package:terra_trace/source/features/data/domain/flux_data.dart';
import 'package:terra_trace/source/features/project_manager/data/project_managment.dart';
import 'package:terra_trace/source/features/project_manager/domain/project_data.dart';

import 'package:terra_trace/source/routing/app_router.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    WidgetsFlutterBinding.ensureInitialized();

    final storageStatus = await Permission.storage.request();
    await Permission.location.request();

    if (storageStatus == PermissionStatus.granted) {
      var dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      await Hive.registerAdapter(FluxDataAdapter());
      await Hive.registerAdapter(ProjectDataAdapter());

      // Start watching the folder for changes as soon as the app launches
      // Initialize DataPointWatcher
      // Create the main ProviderContainer

// Use project or an empty string if null
    }
    if (storageStatus == PermissionStatus.denied) {}
    if (storageStatus == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }

    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    runApp(MyApp());
  }, (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });
}

class MyApp extends StatelessWidget {
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          // Initialize the DataPointWatcher singleton with the ref
          final dataPointWatcher = DataPointWatcher(ref);

          // Initialisierung direkt hier
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              dataPointWatcher.watchForFiles();
            });
            _initialized = true;
          }

          ref.watch(remoteStreamingProvider);
          return MaterialApp.router(
            routerDelegate: goRouter.routerDelegate,
            routeInformationParser: goRouter.routeInformationParser,
          );
        },
      ),
    );
  }

  static bool _initialized = false;
}






// class MyApp extends StatelessWidget {
//   static final navigatorKey = GlobalKey<NavigatorState>();

//   @override
//   Widget build(BuildContext context) {
//     return ProviderScope(
//       child: MaterialApp.router(
//         routerDelegate: goRouter.routerDelegate, // Provide the router delegate
//         routeInformationParser:
//             goRouter.routeInformationParser, // Provide the parser),
//       ),
//     );
//   }
// }

// class MyApp extends StatelessWidget {
//   static final navigatorKey = GlobalKey<NavigatorState>();

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       navigatorKey: navigatorKey,
//       theme: ThemeData(fontFamily: 'Barlow'),
//       home: FirstScreen(),
//     );
//   }
// }


import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/features/project_manager/presentation/remote_project_card.dart';
import 'package:terratrace/source/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle permissions (only for non-web platforms)
  if (!kIsWeb) {
    await _requestPermissions();
  }

  // Ensure Firebase initializes only once
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // Enable Crashlytics and capture Flutter errors
  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  runZonedGuarded(
    () => runApp(const ProviderScope(child: MyApp())),
    (error, stackTrace) =>
        FirebaseCrashlytics.instance.recordError(error, stackTrace),
  );
}

Future<void> _requestPermissions() async {
  final permissions = [
    Permission.storage,
    Permission.location,
    Permission.bluetooth,
    Permission.manageExternalStorage,
    Permission.photos,
    Permission.mediaLibrary,
  ];

  for (var permission in permissions) {
    final status = await permission.request();
    if (status.isPermanentlyDenied) {
      print(
          '${permission.toString()} permanently denied, opening app settings');
      await openAppSettings();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData appTheme = ThemeData(
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF0F172A), // Dark navy blue
        secondary: const Color(0xFFC6FF00), // Green accent
        onSecondary: Colors.black, // Text color on secondary
        onBackground: const Color(0xFF1E293B), // Dark gray for text
        onSurface: const Color(0xFF475569), // Lighter gray for text
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFAEEA00),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );

    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(remoteProjectsCardStreamProvider);

          // Ensure DataPointWatcher initializes only once
          ref.listen<AsyncValue<List<RemoteProjectCard>>>(
              remoteProjectsCardStreamProvider, (_, value) {});
          return MaterialApp.router(
            routerConfig: goRouter,
            debugShowCheckedModeBanner: false,
            theme: appTheme,
          );
        },
      ),
    );
  }
}

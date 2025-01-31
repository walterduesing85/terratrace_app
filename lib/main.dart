import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:terratrace/source/features/data/data/data_point_watcher.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';
import 'package:terratrace/source/routing/app_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<void> main() async {
  // Ensure that the Flutter bindings are initialized in the same zone
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Conditionally request permissions on mobile platforms
    if (!kIsWeb) {
      await requestPermissions();
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    // WidgetsFlutterBinding.ensureInitialized();
    // final prefs = await SharedPreferences.getInstance();
    // List<String> savedDevices = prefs.getStringList('savedDevices') ?? [];

    // for (var deviceId in savedDevices) {
    //   BluetoothDevice device = BluetoothDevice.fromId(deviceId);
    //   try {
    //     await device.connect(autoConnect: true);
    //   } catch (e) {
    //     print('Failed to auto-connect to $deviceId: $e');
    //   }
    // }

    // Run the app in the same zone
    runApp(ProviderScope(child: MyApp()));
  }, (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });
}

Future<void> requestPermissions() async {
  final storageStatus = await Permission.storage.request();
  final locationStatus = await Permission.location.request();
  try {
    await Permission.bluetooth.request();
  } catch (e) {
    print(e.toString());
  }
  if (locationStatus == PermissionStatus.granted) {
    print('Location permission granted');
  } else if (locationStatus == PermissionStatus.denied) {
    print('Location permission denied');
  } else if (locationStatus == PermissionStatus.permanentlyDenied) {
    print('Location permission permanently denied, opening app settings');
    openAppSettings();
  }
  if (storageStatus == PermissionStatus.granted) {
    print('Storage permission granted');
  } else if (storageStatus == PermissionStatus.denied) {
    print('Storage permission denied');
  } else if (storageStatus == PermissionStatus.permanentlyDenied) {
    print('Storage permission permanently denied, opening app settings');
    openAppSettings();
  }

  if (await Permission.manageExternalStorage.isDenied) {
    // Request MANAGE_EXTERNAL_STORAGE for Android 11+
    final manageStorageStatus =
        await Permission.manageExternalStorage.request();
    if (!manageStorageStatus.isGranted) {
      print('Manage External Storage permission denied, opening app settings');
      openAppSettings();
    }
  }

  // Handle iOS-specific permissions for storage-like functionality
  if (await Permission.photos.isGranted) {
    final photosStatus = await Permission.photos.request();
    if (photosStatus == PermissionStatus.granted) {
      print('Photos permission granted');
    } else if (photosStatus == PermissionStatus.denied) {
      print('Photos permission denied');
    } else if (photosStatus == PermissionStatus.permanentlyDenied) {
      print('Photos permission permanently denied, opening app settings');
      await openAppSettings();
    }
  }

  if (await Permission.mediaLibrary.isGranted) {
    final mediaLibraryStatus = await Permission.mediaLibrary.request();
    if (mediaLibraryStatus == PermissionStatus.granted) {
      print('Media Library permission granted');
    } else if (mediaLibraryStatus == PermissionStatus.denied) {
      print('Media Library permission denied');
    } else if (mediaLibraryStatus == PermissionStatus.permanentlyDenied) {
      print(
          'Media Library permission permanently denied, opening app settings');
      await openAppSettings();
    }
  }
}

class MyApp extends StatelessWidget {
  static bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    // Define the color theme for the app
    final ThemeData appTheme = ThemeData(
      colorScheme: ColorScheme.light(
        primary: Color(0xFF0F172A), // Dark navy blue
        secondary: Color(0xFFC6FF00), // Green accent
        // background: Color(0xFFF8FAFC), // Light gray
        // surface: Colors.white, // Surface background for cards, dialogs
        // onPrimary: Colors.white, // Text color on primary
        onSecondary: Colors.black, // Text color on secondary
        onBackground: Color(0xFF1E293B), // Dark gray for text
        onSurface: Color(0xFF475569), // Lighter gray for text
      ),
      // scaffoldBackgroundColor: Color(0xFFF8FAFC), // Light gray
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF0F172A), // Dark navy blue
        // foregroundColor: Colors.white, // White text
        elevation: 0,
      ),
      // textTheme: TextTheme(
      //   displayLarge: TextStyle(
      //     color: Color(0xFF1E293B), // Dark gray
      //     fontWeight: FontWeight.bold,
      //     fontSize: 24,
      //   ),
      //   bodyLarge: TextStyle(
      //     color: Color(0xFF1E293B), // Dark gray
      //     fontSize: 16,
      //   ),
      //   bodyMedium: TextStyle(
      //     color: Color(0xFF475569), // Lighter gray for secondary text
      //     fontSize: 14,
      //   ),
      // ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFAEEA00), // Green accent
          // foregroundColor: Colors.white, // Text color on the button
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );

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

          ref.watch(remoteProjectsCardStreamProvider2);
          return MaterialApp.router(
            routerConfig: goRouter,
            debugShowCheckedModeBanner: false,
            theme: appTheme, // Apply the theme
          );
        },
      ),
    );
  }
}

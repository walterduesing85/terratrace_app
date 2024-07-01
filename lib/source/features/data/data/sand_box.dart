import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:terra_trace/source/constants/constants.dart';

import 'package:terra_trace/source/features/data/data/flux_reg_exp.dart';
import 'package:terra_trace/source/features/data/domain/flux_data.dart';

class SandBox {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String dataOrigin;
  File pathLoad;
  List<FileSystemEntity> fileList;
  double findPressureValues(FluxData allData) {
    double pressure;

    if (allData.dataPress == 'n.a.') {
      pressure = defaultPressure;
      dataOrigin = 'default value';
    } else {
      pressure = double.parse(allData.dataPress);
      dataOrigin = 'true value';
    }

    return pressure;
  }

  double findTemperatureValues(FluxData data) {
    double temperature;

    if (data.dataTemp == 'n.a.') {
      temperature = defaultTemperature;
      dataOrigin = 'default value';
    } else {
      temperature = double.parse(data.dataTemp);
      dataOrigin = 'true value';
    }

    return temperature + 273.15; //adding 273.15 to convert to Kelvin
  }

  String findDataPointValue(data, RegExp exp) {
    return exp.firstMatch(data) == null
        ? 'No Data Found'
        : exp.firstMatch(data).group(1);
  }

  Notifications _notifications;

  double calculateFlux(FluxData allData) {
    double k = (86400 * findPressureValues(allData) * chamberVolume) /
        (1000000 * gasConstant * findTemperatureValues(allData) * chamberArea);
    double fluxInGrams = double.parse(allData.dataCflux) * k * molarMassCO2;
    return fluxInGrams;
  }

  void _pushNotification(Box box, String boxKey) {
    _notifications = Notifications(box: box, boxKey: boxKey);
    this._notifications.initNotifications();
    this._notifications.pushNotification(); // display notification
  }

  Future<void> makeSingleDataPoint(
      String dataFile, String projectName, bool isRemote, Box box) async {
    print('hello from makeSingleDataPoint');

    try {
      String data;
      FluxRegExp fluxRegExp = FluxRegExp();
      File file = File(dataFile);

      final pathLoad = file;

      data = await pathLoad.readAsString();

      String dataInstrument =
          findDataPointValue(data, fluxRegExp.expInstrument);
      String dataDate = findDataPointValue(data, fluxRegExp.expDate);
      String boxKey = '$dataDate$dataInstrument';

      FluxData allData = FluxData(
          dataSite: findDataPointValue(data, fluxRegExp.expSite),
          dataLat: findDataPointValue(data, fluxRegExp.expLat),
          dataLong: findDataPointValue(data, fluxRegExp.expLong),
          dataPress: findDataPointValue(data, fluxRegExp.expPress),
          dataTemp: findDataPointValue(data, fluxRegExp.expTemp),
          dataCflux: getCo2Data(data),
          dataDate: findDataPointValue(data, fluxRegExp.expDate),
          dataNote: findDataPointValue(data, fluxRegExp.expNote),
          dataInstrument: findDataPointValue(data, fluxRegExp.expInstrument),
          dataKey: boxKey);

      allData.dataCfluxGram = calculateFlux(allData).toStringAsFixed(2);
      allData.dataOrigin = dataOrigin;

      if (isRemote) {
        await _firestore
            .collection('projects')
            .doc(box.name)
            .collection('data')
            .doc(boxKey)
            .set({
          'dataCflux': allData.dataCflux,
          'dataDate': allData.dataDate,
          'dataInstrument': allData.dataInstrument,
          'dataKey': allData.dataKey,
          'dataLat': allData.dataLat,
          'dataLong': allData.dataLong,
          'dataNote': allData.dataNote,
          'dataPress': allData.dataPress,
          'dataSite': allData.dataSite,
          'dataSoilTemp': allData.dataSoilTemp,
          'dataTemp': allData.dataTemp,
          'dataCfluxGram': allData.dataCfluxGram,
          'dataOrigin': allData.dataOrigin,
        });
        _pushNotification(box, boxKey);
      } else {
        print('hello from makeSingleDataPoint remote not true');
        await box.put(allData.dataKey, allData);
        _pushNotification(box, boxKey);
      }
    } catch (e) {
      print('Error in makeSingleDataPoint: $e');
    }
  }

//Method that takes extracts the data from Fluxmanager file
  String getCo2Data(data) {
    LineSplitter ls = new LineSplitter();
    List<String> _lines;

    _lines = ls.convert(data);

    for (var i = 0, j = _lines.length; i < j; i++) {
      RegExp exp7 = new RegExp(r"CO2", multiLine: true);
      double flux;
      double finalFlux;

      if (exp7.hasMatch(_lines[i]) == true && i < kMaxLineToFindCo2) {
        RegExp exp8 = new RegExp(r"[0-9.]{3,12}", multiLine: true);
        RegExp exp9 = new RegExp(r"E\s*(.*)$", multiLine: true);
        // RegExp exp8 = new RegExp(r"NOTE:\s*(.*)$", multiLine: true);

        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E-01') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux / 10;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E-02') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux / 100;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E-03') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux / 1000;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E-04') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux / 10000;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E-05') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux / 100000;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E00') {
          finalFlux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
        }

        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E01') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux * 10;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E02') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux * 100;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E03') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux * 1000;
        }
        if (exp9.firstMatch(_lines[i + 12]).group(0).toString() == 'E04') {
          flux = double.parse(exp8.firstMatch(_lines[i + 12]).group(0));
          finalFlux = flux * 10000;
        }
        return finalFlux.toStringAsFixed(3);
      }
    }

    return 'no CO2 bla';
  }

  Future<void> getFileList() async {
    fileList = Directory("storage/emulated/0/fluxmanager/data/").listSync();
  }

  Future<void> browseAllFiles(
      bool isRemote, String projectName, Box box) async {
    String data;
    FluxRegExp fluxRegExp = FluxRegExp();
    await getFileList();

    for (var k = 0; k < fileList.length; k++) {
      pathLoad = fileList[k];

      data = await pathLoad.readAsString();

      String dataInstrument =
          findDataPointValue(data, fluxRegExp.expInstrument);
      String dataDate = findDataPointValue(data, fluxRegExp.expDate);
      String boxKey = '$dataDate$dataInstrument';
      if (box.get(boxKey) == null) {
        FluxData allData = FluxData(
            dataSite: findDataPointValue(data, fluxRegExp.expSite),
            dataLong: findDataPointValue(data, fluxRegExp.expLong),
            dataLat: findDataPointValue(data, fluxRegExp.expLat),
            dataPress: findDataPointValue(data, fluxRegExp.expPress),
            dataTemp: findDataPointValue(data, fluxRegExp.expTemp),
            dataDate: findDataPointValue(data, fluxRegExp.expDate),
            dataNote: findDataPointValue(data, fluxRegExp.expNote),
            dataInstrument: findDataPointValue(data, fluxRegExp.expInstrument),
            dataCflux: getCo2Data(data),
            dataKey: boxKey);
        allData.dataCfluxGram = calculateFlux(allData).toStringAsFixed(2);
        allData.dataOrigin = dataOrigin;

        if (isRemote == true) {
          _firestore
              .collection('projects')
              .doc(box.name)
              .collection('data')
              .doc(boxKey)
              .set({
            'dataCflux': allData.dataCflux,
            'dataDate': allData.dataDate,
            'dataInstrument': allData.dataInstrument,
            'dataKey': allData.dataKey,
            'dataLat': allData.dataLat,
            'dataLong': allData.dataLong,
            'dataNote': allData.dataNote,
            'dataPress': allData.dataPress,
            'dataSite': allData.dataSite,
            'dataSoilTemp': allData.dataSoilTemp,
            'dataCfluxGram': allData.dataCfluxGram,
            'dataOrigin': allData.dataOrigin,
            'dataTemp': allData.dataTemp
          });
        }

        box.put(boxKey, allData);
      }
    }
  }
}

final sandBoxProvider = Provider<SandBox>((ref) {
  return SandBox();
});

class Notifications {
  Notifications({this.box, this.boxKey});
  Box box;
  String boxKey;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  void initNotifications() async {
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');
    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings(onDidReceiveLocalNotification: null);
    final MacOSInitializationSettings initializationSettingsMacOS =
        MacOSInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
            macOS: initializationSettingsMacOS);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: selectNotification);
  }

  Future<void> pushNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'push_messages: 0',
      'push_messages: push_messages',
      'push_messages: A new Flutter project',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      ongoing: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0,
        'New Flux Manager file detected',
        'Tap to edit',
        platformChannelSpecifics,
        payload: 'item x');
  }

  Future selectNotification(String payload) async {
    //TODO go to EditDataScreen

    // some action...
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
//import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/common_widgets/custom_drawer.dart';

// import 'package:terratrace/source/features/bar_chart/presentation/bar_chart_container.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';

import 'package:terratrace/source/features/map/data/map_data.dart';
import 'package:terratrace/source/features/map/presentation/tab_data.dart';
import 'package:terratrace/source/features/map/presentation/tab_user.dart';

final panelDraggableProvider = StateProvider<bool>((ref) => true);

class HeatMapScreen extends ConsumerStatefulWidget {
  const HeatMapScreen({super.key});

  @override
  _HeatMapScreenState createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends ConsumerState<HeatMapScreen>
    with SingleTickerProviderStateMixin {
  late final PanelController _panelController = PanelController();

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupPositionTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Trigger geoJsonProvider fetch early
      ref.read(geoJsonProvider);
    });
  }

  mp.MapboxMap? mapboxMapController;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  StreamSubscription? userPositionStream;

  @override
  Widget build(BuildContext context) {
    // final cameraPosition = ref.watch(initialCameraPositionProvider);
    // final markers = ref.watch(mapStateProvider).heatmaps;

    return Scaffold(
      drawer: CustomDrawer(),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(58, 66, 86, 1),
        title: CustomAppBar(title: ref.read(projectNameProvider)),
      ),
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: 60,
        color: Colors.transparent,
        panelBuilder: _buildPanelContent,
        body: _buildMap(),
      ),
    );
  }

  Widget _buildPanelContent() {
    return Column(
      children: [
        _buildPanelHandle(),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Map Settings'),
                    Tab(text: 'Data'),
                    Tab(text: 'User'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMapSettingsTab(),
                      TabData(),
                      TabUser(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelHandle() {
    return GestureDetector(
      onTap: () {
        if (_panelController.isPanelOpen) {
          _panelController.close();
        } else {
          _panelController.open();
        }
      },
      child: Container(
        height: 20,
        color: Colors.grey[300],
        child: Center(
          child: Container(width: 50, height: 5, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildMapSettingsTab() {
    final radius = ref.watch(radiusProvider);
    final opacity = ref.watch(layerOpacityProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSlider(
            label: 'Point Radius',
            value: radius,
            min: 10,
            max: 50,
            onChanged: (newValue) {
              ref.read(radiusProvider.notifier).state = newValue;
              ref.read(mapStateProvider.notifier).setRadius(newValue);
            },
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Map Opacity',
            value: opacity,
            min: 0.1,
            max: 1.0,
            divisions: 10,
            onChanged: (newValue) {
              ref.read(layerOpacityProvider.notifier).state = newValue;
              ref.read(mapStateProvider.notifier).setLayerOpacity(newValue);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildMap() {
    return mp.MapWidget(
        styleUri: "mapbox://styles/mapbox/dark-v10",
        onMapCreated: _onMapCreated);
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      mapboxMapController = controller;
    });

    await mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(enabled: true, pulsingEnabled: true));

    // Ensure the style is loaded before adding heatmap
    String? styleURI = await mapboxMapController?.style.getStyleURI();
    if (styleURI != null) {
      _addHeatmapLayer(ref);
    }
  }

  Future<void> _setupPositionTracking() async {
    gl.LocationSettings locationSettings = gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high, distanceFilter: 1);
    userPositionStream?.cancel();
    userPositionStream =
        gl.Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((gl.Position? position) {
      if (position != null && mapboxMapController != null) {
        mapboxMapController?.setCamera(
          mp.CameraOptions(
              zoom: 5,
              center: mp.Point(coordinates: mp.Position(12.46811, 50.20735))),
          // mp.Position(position.longitude, position.latitude))),
        );
      }
    });
  }

  Future<void> _addHeatmapLayer(WidgetRef ref) async {
    try {
      final geoJsonData = ref.watch(geoJsonProvider).maybeWhen(
            data: (data) => data,
            orElse: () => null,
          );

      if (geoJsonData == null || geoJsonData.isEmpty) {
        print("🚨 No GeoJSON data available.");
        return;
      }

      print("✅ Adding GeoJSON Source: $geoJsonData");

      await mapboxMapController?.style.addSource(mp.GeoJsonSource(
        id: "heatmap-source",
        data: geoJsonData,
      ));

      print("✅ GeoJSON Source added successfully");

      mp.HeatmapLayer heatmapLayer = mp.HeatmapLayer(
        id: "heatmap-layer",
        sourceId: "heatmap-source",
        heatmapWeightExpression: [
          "interpolate",
          ["linear"],
          ["get", "weight"],
          0.0, 0.05, // Very low weight → very weak effect
          0.1, 0.2, // Low weight → slightly visible
          0.3, 0.4, // Medium-low weight → more visible
          0.5, 0.6, // Medium weight → stronger contribution
          0.7, 0.8, // Medium-high weight → near peak effect
          1.0, 1.0 // Maximum weight → full intensity
        ],
        heatmapColorExpression: [
          "interpolate",
          ["linear"],
          ["heatmap-density"],
          0,
          "rgba(0, 0, 255, 0)",
          0.1,
          "royalblue",
          0.3,
          "cyan",
          0.5,
          "lime",
          0.7,
          "yellow",
          1,
          "red"
        ],
        heatmapRadius: 20,
        heatmapIntensity: 4,
        heatmapOpacity: 0.9,
      );

      await mapboxMapController?.style.addLayer(heatmapLayer);
      print("✅ Heatmap Layer added successfully");
    } catch (e) {
      print("❌ Error updating heatmap: $e");
    }
  }
}

class PanelControllerSingleton {
  static final PanelController _instance = PanelController();
  static PanelController get instance => _instance;
}

final showOnPositionProvider = StateProvider<bool>((ref) => false);

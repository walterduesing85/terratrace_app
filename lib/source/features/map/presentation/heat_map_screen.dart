import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
//import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/common_widgets/custom_drawer.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_state_notifier.dart';
import 'package:terratrace/source/features/bar_chart/prensentation/histogram_chart.dart';

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
    // _setupPositionTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapStateProvider.notifier).initHeatmap(ref);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  mp.MapboxMap? mapboxMapController;

  StreamSubscription? userPositionStream;

  @override
  Widget build(BuildContext context) {
    ref.listen(mapStateProvider, (previous, next) {
      _updateHeatmapLayer(ref, next);
    });
    // final cameraPosition = ref.watch(initialCameraPositionProvider);

    ref.watch(radiusProvider);
    ref.watch(layerOpacityProvider);
    ref.watch(geoJsonProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.watch(chartStateProvider.notifier).setNumEdges(5);
        },
        child: const Icon(Icons.settings),
      ),
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
    return Consumer(
      builder: (context, ref, child) {
        final rangeValues = ref.watch(rangeValuesProvider);
        final minMaxValues =
            ref.watch(minMaxGramProvider); // ✅ Watch dynamically

        final validMin = minMaxValues.minV;
        final validMax = minMaxValues.maxV;
        final start = rangeValues.minV.clamp(validMin, validMax);
        final end = rangeValues.maxV.clamp(validMin, validMax);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HistogramChart(),
              RangeSlider(
                min: validMin, // ✅ Now dynamic
                max: validMax, // ✅ Now dynamic
                values: RangeValues(start, end),
                onChanged: (values) {
                  print(
                      "📏 Range Slider Changed: ${values.start} - ${values.end}");

                  final newRange =
                      MinMaxValues(minV: values.start, maxV: values.end);

                  ref.read(rangeValuesProvider.notifier).state = newRange;

                  // ✅ Ensure heatmap updates by modifying mapStateProvider
                  ref
                      .read(mapStateProvider.notifier)
                      .updateRangeValues(newRange, ref);
                },
              ),
              _buildSlider(
                label: 'Point Radius',
                value: ref.watch(radiusProvider),
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
                value: ref.watch(layerOpacityProvider),
                min: 0.1,
                max: 1.0,
                divisions: 10,
                onChanged: (newValue) {
                  ref.read(layerOpacityProvider.notifier).state = newValue;
                  ref.read(mapStateProvider.notifier).setOpacity(newValue);
                },
              ),
            ],
          ),
        );
      },
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
      onMapCreated: (mapboxMap) => _onMapCreated(mapboxMap, ref),
    );
  }

  void _onMapCreated(mp.MapboxMap mapboxMap, WidgetRef ref) {
    setState(() {
      mapboxMapController = mapboxMap; // ✅ Store the controller
    });

    mapboxMap.setCamera(
      mp.CameraOptions(
          zoom: 13,
          center: mp.Point(
              coordinates: mp.Position(
                  12.46811, 50.20735))), //TODO add cameraPostionProvider
    );

    print("✅ MapboxMap Controller Initialized!");

    // ✅ Ensure the controller is not null before calling heatmap update
    Future.delayed(Duration(milliseconds: 500), () {
      if (mapboxMapController != null) {
        _updateHeatmapLayer(ref, ref.read(mapStateProvider));
      } else {
        print("🚨 ERROR: MapboxMap Controller still NULL after delay!");
      }
    });
  }

  Future<void> _updateHeatmapLayer(WidgetRef ref, MapState mapState) async {
    if (mapboxMapController == null) {
      print("🚨 ERROR: MapboxMap Controller is NULL! Aborting heatmap update.");
      return;
    }

    try {
      final geoJsonData = mapState.geoJson;

      if (geoJsonData.isEmpty || geoJsonData.contains('"features": []')) {
        print("🚨 ERROR: No valid features in GeoJSON!");
        return;
      }

      final style = mapboxMapController!.style;

      // ✅ Step 1: Check if the heatmap source exists
      final sources = await style.getStyleSources();
      final hasHeatmapSource = sources.any((s) => s?.id == "heatmap-source");

      if (hasHeatmapSource) {
        // ✅ Step 2: Update the existing GeoJSON source
        final List<mp.Feature> features = _parseGeoJsonFeatures(geoJsonData);

        if (features.isNotEmpty) {
          await style.updateGeoJSONSourceFeatures(
            "heatmap-source",
            "features",
            features,
          );
          print("✅ GeoJSON Source updated successfully");
        } else {
          print("🚨 ERROR: No valid features found to update in GeoJSON!");
        }
      } else {
        // ✅ Step 3: Add a new GeoJSON source if it doesn't exist
        await style.addSource(mp.GeoJsonSource(
          id: "heatmap-source",
          data: geoJsonData, // ✅ Pass raw JSON string
        ));
        print("✅ GeoJSON Source added successfully");
      }

      // ✅ Step 4: Check if the heatmap layer exists
      final layers = await style.getStyleLayers();
      final hasHeatmapLayer = layers.any((l) => l?.id == "heatmap-layer");
      final globalMinMax = ref.watch(minMaxGramProvider);
      final minMaxWeights = normalizeMinMax(
          mapState.rangeValues, globalMinMax.minV, globalMinMax.maxV);
      print(generateDynamicHeatmapWeightExpression(
          minMaxWeights.minV, minMaxWeights.maxV));

      final heatmapLayer = mp.HeatmapLayer(
        id: "heatmap-layer",
        sourceId: "heatmap-source",
        heatmapWeightExpression: generateDynamicHeatmapWeightExpression(
            minMaxWeights.minV, minMaxWeights.maxV),

        // Get min/max from range slider state

        // Generate the new weight expression dynamically

        heatmapColorExpression: [
          "interpolate", ["linear"], ["heatmap-density"],
          0, "rgba(0, 0, 255, 0)", // Transparent at low density
          0.2, "royalblue",
          0.4, "cyan",
          0.6, "lime",
          0.8, "yellow",
          1.0, "red" // High density → red
        ],
        heatmapRadius: mapState.radius, // ✅ Uses mapState radius
        heatmapOpacity: mapState.opacity,

        // ✅ Uses mapState opacity
      );

      if (!hasHeatmapLayer) {
        // ✅ Only add the heatmap layer if it does not exist
        await style.addLayer(heatmapLayer);
        print("✅ Heatmap Layer added successfully");
      } else {
        print(
            "🔍 Heatmap Weight Expression: ${await style.getLayer("heatmap-layer")}");
        print(
            "🔍 Heatmap Weight Expression: ${heatmapLayer.heatmapWeightExpression}");
        // ✅ Update the existing heatmap layer properties
        await style.updateLayer(heatmapLayer);
        print("✅ Heatmap Layer updated successfully");
      }
    } catch (e) {
      print("❌ Error updating heatmap: $e");
    }
  }

  MinMaxValues normalizeMinMax(
      MinMaxValues input, double globalMin, double globalMax) {
    // Prevent division by zero
    if (globalMax == globalMin) {
      return MinMaxValues(minV: 0, maxV: 1);
    }

    double normalizedMin = (input.minV - globalMin) / (globalMax - globalMin);
    double normalizedMax = (input.maxV - globalMin) / (globalMax - globalMin);

    // Ensure values are within [0,1] range
    return MinMaxValues(
      minV: normalizedMin.clamp(0.0, 1.0),
      maxV: normalizedMax.clamp(0.0, 1.0),
    );
  }

  List<Object> generateDynamicHeatmapWeightExpression(
      double minWeight, double maxWeight) {
    // Ensure minWeight < maxWeight, otherwise adjust
    if (minWeight >= maxWeight) {
      maxWeight = minWeight + 0.01; // Prevents identical values
    }

    return [
      "interpolate", ["linear"], ["get", "weight"],

      // Any weight below minWeight → intensity = 1
      minWeight, 1,

      // Linearly interpolate between minWeight and maxWeight
      (minWeight + maxWeight) / 2, 5, // Midpoint gets moderate intensity
      maxWeight, 10, // Max weight gets highest intensity

      // Ensures all values above maxWeight get full intensity
      maxWeight + 0.01, 10
    ];
  }

  List<mp.Feature> _parseGeoJsonFeatures(String geoJsonString) {
    try {
      final geoJsonMap = jsonDecode(geoJsonString);
      if (geoJsonMap['features'] is List) {
        return (geoJsonMap['features'] as List).map((feature) {
          return mp.Feature(
            geometry: mp.GeoJSONObject.fromJson(feature['geometry'])
                as mp.GeometryObject,
            id: feature['properties']?['id'] ??
                "feature-${DateTime.now().millisecondsSinceEpoch}",
            properties: feature['properties'] ?? {},
          );
        }).toList();
      }
    } catch (e) {
      print("❌ Error parsing GeoJSON: $e");
    }
    return [];
  }
}

class PanelControllerSingleton {
  static final PanelController _instance = PanelController();
  static PanelController get instance => _instance;
}

final showOnPositionProvider = StateProvider<bool>((ref) => false);





  // Future<void> _setupPositionTracking() async {
  //   gl.LocationSettings locationSettings = gl.LocationSettings(
  //       accuracy: gl.LocationAccuracy.high, distanceFilter: 1);
  //   userPositionStream?.cancel();
  //   userPositionStream =
  //       gl.Geolocator.getPositionStream(locationSettings: locationSettings)
  //           .listen((gl.Position? position) {
  //     if (position != null && mapboxMapController != null) {
  //       mapboxMapController?.setCamera(
  //         mp.CameraOptions(
  //             zoom: 13,
  //             center: mp.Point(coordinates: mp.Position(12.46811, 50.20735))),
  //         // mp.Position(position.longitude, position.latitude))),
  //       );
  //     }
  //   });
  // }
//  Future<void> _updateHeatmapLayer(WidgetRef ref, MapState mapState) async {
//     if (mapboxMapController == null) {
//       print("🚨 ERROR: MapboxMap Controller is NULL! Aborting heatmap update.");
//       return;
//     }

//     try {
//       final style = mapboxMapController!.style;

//       // ✅ Ensure heatmap-source exists
//       final sources = await style.getStyleSources();
//       final hasHeatmapSource = sources.any((s) => s?.id == "heatmap-source");

//       if (!hasHeatmapSource) {
//         print("🚨 ERROR: Heatmap source missing! Re-adding source...");
//         await style.addSource(mp.GeoJsonSource(
//           id: "heatmap-source",
//           data: mapState.geoJson, // ✅ Get latest geoJSON data
//         ));
//       }

//       // ✅ Ensure heatmap-layer exists
//       final layers = await style.getStyleLayers();
//       final hasHeatmapLayer = layers.any((l) => l?.id == "heatmap-layer");

//       // ✅ Get min/max from range slider state
//       final newMinWeight = ref.read(rangeValuesProvider).minV;
//       final newMaxWeight = ref.read(rangeValuesProvider).maxV;

//       // ✅ Generate the new weight expression dynamically
//       final newWeightExpression =
//           generateHeatmapWeightExpression(newMinWeight, newMaxWeight);

//       if (!hasHeatmapLayer) {
//         print("🚨 Heatmap layer missing! Creating new heatmap layer...");
//         await style.addLayer(mp.HeatmapLayer(
//           id: "heatmap-layer",
//           sourceId: "heatmap-source",
//           heatmapWeightExpression: newWeightExpression,
//           heatmapRadius: mapState.radius, // Ensure radius is set
//           heatmapOpacity: mapState.opacity, 
//        // Ensure opacity is set
//         ));
//         print("✅ Heatmap Layer created successfully!");
//       } else {
//         print("♻️ Updating existing heatmap layer...");
//         await style.updateLayer(mp.HeatmapLayer(
//           id: "heatmap-layer",
//           sourceId: "heatmap-source",
//           heatmapWeightExpression: newWeightExpression,
//           heatmapRadius: mapState.radius, // Ensure radius is set
//           heatmapOpacity: mapState.opacity, 
//         ));
//         print("✅ Heatmap Layer updated successfully!");
//       }
//     } catch (e) {
//       print("❌ Error updating heatmap: $e");
//     }
//   }
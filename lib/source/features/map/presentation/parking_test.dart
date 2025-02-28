import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
//import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/common_widgets/custom_drawer.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_state_notifier.dart';
import 'package:terratrace/source/features/bar_chart/prensentation/histogram_chart.dart';

// import 'package:terratrace/source/features/bar_chart/presentation/bar_chart_container.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';

import 'package:terratrace/source/features/map/data/map_data.dart';
import 'package:terratrace/source/features/map/presentation/map_style_dropdown.dart';
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
  Timer? _debounce;

  late final PanelController _panelController = PanelController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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
    // 🔄 Listen for range slider updates and update only the heatmap source
    ref.listen(mapStateProvider.select((state) => state.rangeValues),
        (previous, next) {
      print("🎛 Range slider updated...");
      _debounceUpdateHeatmap(ref, ref.read(mapStateProvider));
    });

    ref.listen(mapStateProvider.select((state) => state.mapStyle),
        (previous, next) {
      print("🎛 Range slider updated...");
      _debounceUpdateHeatmap(ref, ref.read(mapStateProvider));
    });

    ref.listen(mapStateProvider.select((state) => state.radius),
        (previous, next) {
      print("🎛 Radius updated...");
      _debounceUpdateHeatmap(ref, ref.read(mapStateProvider));
    });

    ref.listen(mapStateProvider.select((state) => state.opacity),
        (previous, next) {
      print("🎛 Opacity updated...");
      _debounceUpdateHeatmap(ref, ref.read(mapStateProvider));
    });

    // final cameraPosition = ref.watch(initialCameraPositionProvider);

    // ref.watch(radiusProvider);
    // ref.watch(layerOpacityProvider);
    // ref.watch(rangeValuesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          print("🔍 Debugging heatmap layers...");
          final mapState = ref.read(mapStateProvider);

          await _updateHeatmapSource(ref, mapState);
          await _updateHeatmapLayer(
              ref, mapState); // 🔄 Ensure layer is updated after source
        },
        child: const Icon(Icons.refresh), // Changed icon to refresh for clarity
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
        body: _buildMap(ref),
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
                      _buildMapSettingsTab(context, ref),
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

  Widget _buildMapSettingsTab(BuildContext context, WidgetRef ref) {
    final useLogNormalization = ref.watch(mapStateProvider).useLogNormalization;
    final rangeValues = ref.watch(rangeValuesProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildSlider(
                    label: 'Point Radius',
                    value: ref.watch(radiusProvider),
                    min: 1,
                    max: 30,
                    onChanged: (newValue) {
                      ref.read(radiusProvider.notifier).state = newValue;
                      ref.read(mapStateProvider.notifier).setRadius(newValue);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSlider(
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
                ),
              ],
            ),
            HistogramChart(),
            RangeSlider(
              activeColor: Color(0xFFAEEA00),
              inactiveColor: Colors.grey,
              values: useLogNormalization
                  ? RangeValues(
                      log(rangeValues.minV + 1) /
                          log(ref.watch(minMaxGramProvider).maxV + 1),
                      log(rangeValues.maxV + 1) /
                          log(ref.watch(minMaxGramProvider).maxV + 1),
                    )
                  : RangeValues(rangeValues.minV, rangeValues.maxV),
              min: useLogNormalization ? 0.0 : 0,
              max: useLogNormalization
                  ? 1.0
                  : ref.watch(minMaxGramProvider).maxV,
              divisions: 100,
              labels: RangeLabels(
                rangeValues.minV.toStringAsFixed(2),
                rangeValues.maxV.toStringAsFixed(2),
              ),
              onChanged: (RangeValues values) async {
                print("🎚 Range slider updated: $values");
                double newMin = useLogNormalization
                    ? exp(values.start *
                            log(ref.watch(minMaxGramProvider).maxV + 1)) -
                        1
                    : values.start;
                double newMax = useLogNormalization
                    ? exp(values.end *
                            log(ref.watch(minMaxGramProvider).maxV + 1)) -
                        1
                    : values.end;

                ref.read(rangeValuesProvider.notifier).state =
                    MinMaxValues(minV: newMin, maxV: newMax);
                ref.watch(mapStateProvider.notifier).updateRangeValues(
                    MinMaxValues(minV: newMin, maxV: newMax), ref);
              },
            ),
            Column(
              children: [
                Switch(
                  hoverColor: Colors.white,
                  value: useLogNormalization,
                  onChanged: (value) {
                    ref
                        .read(mapStateProvider.notifier)
                        .toggleLogNormalization(ref);
                  },
                ),
                MapStyleDropdown(
                  onStyleChanged: (value) {
                    print('HELLO HELLO MapStyleDropdown: $value');
                    _setMapStyle(value, ref);
                  },
                ),
                Text(
                  ref.watch(mapStateProvider).useLogNormalization
                      ? "log norm: on"
                      : "log norm: off",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
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
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
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

  Widget _buildMap(WidgetRef ref) {
    final mapStyle = ref.watch(mapStateProvider).mapStyle;

    // ✅ If the map is already initialized, update its style manually
    if (mapboxMapController != null) {
      mapboxMapController?.loadStyleURI(mapStyle);
    }

    return mp.MapWidget(
      styleUri: mapStyle, // ✅ This will still be used on first build
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
    // ✅ Ensure the controller is not null before calling heatmap update
    Future.delayed(Duration(milliseconds: 500), () async {
      final currentStyle = await mapboxMapController!.style.getStyleURI();
      if (currentStyle == ref.read(mapStateProvider).mapStyle) {
        _updateHeatmapLayer(ref, ref.read(mapStateProvider));
      }
    });
  }

  void _setMapStyle(String style, WidgetRef ref) async {
    if (mapboxMapController != null) {
      await mapboxMapController!.loadStyleURI(style);

      print("🕒 Waiting for Mapbox style to fully load...");

      // ✅ Wait for the new style to be fully loaded before updating the heatmap
      Future.delayed(Duration(milliseconds: 500), () async {
        final currentStyle = await mapboxMapController!.style.getStyleURI();
        if (currentStyle == style) {
          print("✅ New Mapbox style applied: $currentStyle");

          // ✅ Ensure the heatmap source & layer are added again
          _updateHeatmapLayer(ref, ref.read(mapStateProvider));
        }
      });
    }
  }

  Future<void> debugHeatmapLayers() async {
    if (mapboxMapController == null) {
      print("🚨 MapboxMap Controller is NULL!");
      return;
    }

    final style = mapboxMapController!.style;
    final layers = await style.getStyleLayers();
    print("📌 Current layers in the map:");
    for (var layer in layers) {
      print("👉 Layer ID: ${layer?.id}");
    }
  }

  Future<void> _updateHeatmapSource(WidgetRef ref, MapState mapState) async {
    if (mapboxMapController == null) {
      debugPrint(
          "🚨 MapboxMap Controller is NULL! Aborting heatmap source update.");
      return;
    }

    final style = mapboxMapController!.style;
    final sources = await style.getStyleSources();
    final hasHeatmapSource = sources.any((s) => s?.id == "heatmap-source");

    if (!hasHeatmapSource) {
      print("🆕 Adding heatmap source...");
      await style.addSource(mp.GeoJsonSource(
        id: "heatmap-source",
        data: mapState.geoJson,
      ));
    } else {
      print("♻️ Updating existing heatmap source...");
      final List<mp.Feature> features = _parseGeoJsonFeatures(mapState.geoJson);
      if (features.isNotEmpty) {
        await style.updateGeoJSONSourceFeatures(
          "heatmap-source",
          "features",
          features,
        );
      } else {
        debugPrint("❌ Error parsing GeoJSON features");
      }
    }
  }

  void _debounceUpdateHeatmap(WidgetRef ref, MapState mapState) {
    _debounce?.cancel(); // Cancel any previous pending updates

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      print("🔥 Debounced heatmap update triggered...");

      await _updateHeatmapSource(ref, mapState);
      await _updateHeatmapLayer(ref, mapState);

      print("✅ Heatmap updated after debounce.");
    });
  }

  Future<void> _updateHeatmapLayer(WidgetRef ref, MapState mapState) async {
    if (mapboxMapController == null) {
      debugPrint(
          "🚨 MapboxMap Controller is NULL! Aborting heatmap layer update.");
      return;
    }

    final style = mapboxMapController!.style;

    // ✅ Ensure the heatmap source exists before updating
    final sources = await style.getStyleSources();
    final hasHeatmapSource = sources.any((s) => s?.id == "heatmap-source");

    if (!hasHeatmapSource) {
      print("🚨 Heatmap source is missing! Re-adding source...");
      await _updateHeatmapSource(ref, mapState);
    }

    // ✅ Check if the heatmap layer exists
    final layers = await style.getStyleLayers();
    final hasHeatmapLayer = layers.any((l) => l?.id == "heatmap-layer");

    final globalMinMax = ref.watch(minMaxGramProvider);
    final rangeValues = ref.watch(mapStateProvider).rangeValues;
    final minMaxWeights =
        normalizeMinMax(rangeValues, globalMinMax.minV, globalMinMax.maxV);

    final heatmapLayer = mp.HeatmapLayer(
      id: "heatmap-layer",
      sourceId: "heatmap-source",
      heatmapWeightExpression: generateDynamicHeatmapWeightExpression(
          minMaxWeights.minV, minMaxWeights.maxV),
      heatmapColorExpression: [
        "interpolate",
        ["linear"],
        ["heatmap-density"],
        0,
        "rgba(0, 0, 255, 0)",
        0.2,
        "royalblue",
        0.4,
        "cyan",
        0.6,
        "lime",
        0.8,
        "yellow",
        1.0,
        "red"
      ],
      heatmapRadius: mapState.radius,
      heatmapOpacity: mapState.opacity,
    

    if (!hasHeatmapLayer) {
      print("🆕 Adding heatmap layer...");
      await style.addLayer(heatmapLayer);
    } else {
      print("🔄 Updating existing heatmap layer...");
      await style.updateLayer(heatmapLayer);
    }

    print("✅ Heatmap successfully updated!");
  }

  Future<void> _updateMapStyle(String styleUri, WidgetRef ref) async {
    if (mapboxMapController == null) {
      debugPrint("🚨 MapboxMap Controller is NULL! Aborting map style update.");
      return;
    }

    print("🎨 Changing map style to: $styleUri");
    await mapboxMapController!.loadStyleURI(styleUri);

    Future.delayed(const Duration(milliseconds: 500), () async {
      final currentStyle = await mapboxMapController!.style.getStyleURI();
      if (currentStyle == styleUri) {
        print("✅ Map style successfully applied: $currentStyle");

        final mapState = ref.read(mapStateProvider);

        // ✅ Re-add the heatmap source **before** updating the layer
        await _updateHeatmapSource(ref, mapState);

        print("♻️ Heatmap successfully restored after style change!");
      } else {
        print(
            "❌ Warning: Style mismatch! Expected $styleUri but got $currentStyle");
      }
    });
  }

//Method to normalize the min and max values to be used in dynamic heatmap weight expression
  MinMaxValues normalizeMinMax(
      MinMaxValues input, double globalMin, double globalMax) {
    if (globalMax == globalMin) {
      return MinMaxValues(minV: 0, maxV: 1);
    }

    // Ensure input values are within valid range
    double adjustedMin = input.minV.clamp(globalMin, globalMax);
    double adjustedMax = input.maxV.clamp(globalMin, globalMax);

    // Normalize using range slider values
    double normalizedMin = (adjustedMin - globalMin) / (globalMax - globalMin);
    double normalizedMax = (adjustedMax - globalMin) / (globalMax - globalMin);

    // Ensure there's always a valid range
    if ((normalizedMax - normalizedMin).abs() < 0.01) {
      normalizedMax = (normalizedMin + 0.01).clamp(0.0, 1.0);
    }

    return MinMaxValues(
      minV: normalizedMin,
      maxV: normalizedMax,
    );
  }

//Method to generate dynamic heatmap weight expression
  List<Object> generateDynamicHeatmapWeightExpression(
      double minWeight, double maxWeight) {
    // Ensure minWeight < maxWeight, otherwise adjust
    if (minWeight >= maxWeight) {
      maxWeight = minWeight + 0.01; // Prevents identical values
    }

    return [
      "interpolate", ["linear"],

      // Use heatmap-weight based directly on "weight" property
      [
        "coalesce",
        ["get", "weight"],
        1
      ], // Fallback to 1 if weight is missing

      minWeight, 0.5, // Minimum weight → low intensity
      (minWeight + maxWeight) / 2, 2, // Mid-range weight → moderate intensity
      maxWeight, 5 // Maximum weight → highest intensity
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
    } catch (e) {}
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
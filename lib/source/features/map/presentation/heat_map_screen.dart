import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:latlong2/latlong.dart';
import 'package:terra_trace/source/common_widgets/async_value_widget.dart';
import 'package:terra_trace/source/common_widgets/custom_appbar.dart';
import 'package:terra_trace/source/common_widgets/custom_drawer.dart';
import 'package:terra_trace/source/constants/text_styles.dart';
import 'package:terra_trace/source/features/bar_chart/presentation/bar_chart_container.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/data/data/map_provider.dart';

import 'package:terra_trace/source/features/map/data/map_data.dart';
import 'package:terra_trace/source/features/map/presentation/tab_data.dart';
import 'package:terra_trace/source/features/map/presentation/tab_user.dart';

class HeatMapScreen extends ConsumerStatefulWidget {
  @override
  _HeatMapScreenState createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends ConsumerState<HeatMapScreen> {
  late PanelController _panelController;
  final mapController = MapController();

  @override
  void initState() {
    super.initState();
    _panelController = PanelControllerSingleton.instance;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapStateProvider.notifier).initHeatmap(ref);
    });
  }

  void updateHeatmap() async {
    try {
      final weightedLatLngList =
          await ref.read(weightedLatLngListProvider.future);
      if (weightedLatLngList.isNotEmpty) {
        ref.read(mapStateProvider.notifier).updateHeatmap(weightedLatLngList,
            ref.read(radiusProvider), ref.read(layerOpacityProvider));
      } else {
        print("Error: weightedLatLngList is empty updateHeatMap");
      }
    } catch (e) {
      print("Error updating heatmap: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeSliderValuesInitial = ref.watch(minMaxGramProvider);
    final rangeSliderValuesChanged = ref.watch(rangeSliderNotifierProvider);
    final minValue = rangeSliderValuesChanged.minV.toStringAsFixed(2);
    final maxValue = rangeSliderValuesChanged.maxV.toStringAsFixed(2);
    final opacity = ref.watch(layerOpacityProvider);
    final radius = ref.watch(radiusProvider);
    final cameraPosition = ref.watch(initialCameraPositionProvider);
    final heatmaps = ref.watch(weightedLatLngListProvider);
    final markers = ref.watch(markersProvider2);

    // Listen to changes in relevant providers and update heatmap accordingly
    ref.listen<double>(radiusProvider, (previous, next) {
      updateHeatmap();
    });

    ref.listen<double>(layerOpacityProvider, (previous, next) {
      updateHeatmap();
    });

    ref.listen<MinMaxValues>(rangeSliderNotifierProvider, (previous, next) {
      updateHeatmap();
    });

    return Scaffold(
      drawer: CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(58, 66, 86, 1),
        title: CustomAppBar(title: ref.read(projectNameProvider)),
      ),
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: 60,
        color: Color.fromRGBO(255, 255, 255, 0.3),
        panelBuilder: () {
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  labelStyle: tabLabels,
                  tabs: [
                    Tab(
                      text: 'Map Settings',
                    ),
                    Tab(text: 'Data'),
                    Tab(text: 'User'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Point Radius: ${radius.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Slider(
                                        min: 10,
                                        max: 50,
                                        value: radius,
                                        onChanged: (newValue) {
                                          ref
                                              .read(radiusProvider.notifier)
                                              .state = newValue;
                                          ref
                                              .read(mapStateProvider.notifier)
                                              .setRadius(newValue);
                                        },
                                        onChangeEnd: (newValue) {
                                          ref
                                              .read(radiusProvider.notifier)
                                              .state = newValue;
                                          ref
                                              .read(mapStateProvider.notifier)
                                              .setRadius(newValue);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Map Opacity: $opacity',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Slider(
                                        divisions: 20,
                                        min: 0,
                                        max: 1,
                                        value: opacity,
                                        onChanged: (newValue) {
                                          ref
                                              .read(
                                                  layerOpacityProvider.notifier)
                                              .state = newValue;
                                          ref
                                              .read(mapStateProvider.notifier)
                                              .setLayerOpacity(newValue);
                                        },
                                        onChangeEnd: (newValue) {
                                          ref
                                              .read(
                                                  layerOpacityProvider.notifier)
                                              .state = newValue;
                                          ref
                                              .read(mapStateProvider.notifier)
                                              .setLayerOpacity(newValue);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  SizedBox(width: 20),
                                  RotatedBox(
                                    quarterTurns: 1,
                                    child: RangeSlider(
                                      values: RangeValues(
                                        double.parse(rangeSliderValuesChanged
                                            .minV
                                            .toStringAsFixed(2)),
                                        double.parse(rangeSliderValuesChanged
                                            .maxV
                                            .toStringAsFixed(2)),
                                      ),
                                      min: double.parse(rangeSliderValuesInitial
                                          .minV
                                          .toStringAsFixed(2)),
                                      max: double.parse(rangeSliderValuesInitial
                                          .maxV
                                          .toStringAsFixed(2)),
                                      onChanged: (values) {
                                        // Round the start and end values to two decimal places
                                        final roundedStart = double.parse(
                                            values.start.toStringAsFixed(2));
                                        final roundedEnd = double.parse(
                                            values.end.toStringAsFixed(2));

                                        // Update the values in the notifier
                                        ref
                                            .read(rangeSliderNotifierProvider
                                                .notifier)
                                            .updateMinMaxValues(
                                                roundedStart, roundedEnd);
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(20.0),
                                      child: BarChartContainer(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      child: Text(
                                        'min: $minValue flux [g/m2/d]',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18.0),
                                      ),
                                    ),
                                    Container(
                                      child: Text(
                                        'max: $maxValue flux [g/m2/d]',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18.0),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SafeArea(child: TabData()),
                      SafeArea(child: TabUser()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        body: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: cameraPosition,
                initialZoom: 14.0,
                onMapReady: () {
                  ref
                      .read(mapControllerProvider.notifier)
                      .setController(mapController);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                ),
                Consumer(builder: (context, ref, child) {
                  return AsyncValueWidget<MapSettings>(
                    value: ref.watch(mapSettingsProvider),
                    data: (mapSettings) {
                      return HeatMapLayer(
                        heatMapDataSource: InMemoryHeatMapDataSource(
                            data: mapSettings.weightedLatLngList),
                        heatMapOptions: HeatMapOptions(
                          gradient: HeatMapOptions.defaultGradient,
                          minOpacity: 0,
                          layerOpacity: mapSettings.mapOpacity,
                          radius: mapSettings.pointRadius,
                        ),
                      );
                    },
                  );
                }),
                MarkerLayer(
                  markers: markers.toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PanelControllerSingleton {
  static final PanelController _instance = PanelController();

  static PanelController get instance => _instance;
}

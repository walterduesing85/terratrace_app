import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_maps_flutter_heatmap/google_maps_flutter_heatmap.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:terra_trace/source/common_widgets/custom_appbar.dart';
import 'package:terra_trace/source/common_widgets/custom_drawer.dart';
import 'package:terra_trace/source/constants/text_styles.dart';
import 'package:terra_trace/source/features/bar_chart/presentation/bar_chart_container.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/map/data/map_data.dart';
import 'package:terra_trace/source/features/map/presentation/tab_data.dart';
import 'package:terra_trace/source/features/map/presentation/tab_user.dart';

import '../../data/data/map_provider.dart';

class HeatMapScreen extends ConsumerStatefulWidget {
  @override
  _HeatMapScreenState createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends ConsumerState<HeatMapScreen> {
  late PanelController _panelController;

  @override
  void initState() {
    super.initState();
    _panelController = PanelControllerSingleton.instance;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(heatmapControllerProvider.notifier).initHeatmap(ref);
    });
  }

  void updateHeatmap() async {
    try {
      final weightedLatLngList =
          await ref.read(weightedLatLngListProvider.future);
      if (weightedLatLngList.isNotEmpty) {
        ref.read(heatmapControllerProvider.notifier).updateHeatmap(
            weightedLatLngList,
            ref.read(radiusProvider),
            ref.read(layerOpacityProvider));
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
    final heatmaps = ref.watch(heatmapControllerProvider);
    final markers = ref.watch(markersProvider);

    // Listen to changes in relevant providers and update heatmap accordingly
    ref.listen<int>(radiusProvider, (previous, next) {
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
                                        'Point Radius: $radius',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Slider(
                                        min: 10,
                                        max: 50,
                                        value: radius.toDouble(),
                                        onChanged: (newValue) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setRadius(newValue.toInt());
                                        },
                                        onChangeEnd: (newValue) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setRadius(newValue.toInt());
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
                                              .read(mapProvider.notifier)
                                              .setLayerOpacity(newValue);
                                        },
                                        onChangeEnd: (newValue) {
                                          ref
                                              .read(mapProvider.notifier)
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
                                          rangeSliderValuesChanged.minV,
                                          rangeSliderValuesChanged.maxV),
                                      min: rangeSliderValuesInitial.minV,
                                      max: rangeSliderValuesInitial.maxV,
                                      onChanged: (values) {
                                        ref
                                            .read(rangeSliderNotifierProvider
                                                .notifier)
                                            .updateMinMaxValues(
                                                values.start, values.end);
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
        // body: GoogleMap(
        //   myLocationEnabled: true,
        //   mapType: MapType.satellite,
        //   initialCameraPosition: CameraPosition(
        //     target: cameraPosition,
        //     zoom: 14,
        //     tilt: 10,
        //   ),
        //   onMapCreated: (GoogleMapController controller) {
        //     ref.read(mapControllerProvider.notifier).setController(controller);
        //   },
        //   markers: markers,
        //   heatmaps: heatmaps,
        // ),
      ),
    );
  }
}

class PanelControllerSingleton {
  static final PanelController _instance = PanelController();

  static PanelController get instance => _instance;
}

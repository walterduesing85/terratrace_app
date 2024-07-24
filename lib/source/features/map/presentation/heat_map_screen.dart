import 'package:flutter/material.dart';
//import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

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

final panelDraggableProvider = StateProvider<bool>((ref) => true);

class HeatMapScreen extends ConsumerStatefulWidget {
  @override
  _HeatMapScreenState createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends ConsumerState<HeatMapScreen>
    with SingleTickerProviderStateMixin {
  late PanelController _panelController;
  final mapController = MapController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _panelController = PanelControllerSingleton.instance;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapStateProvider.notifier).initHeatmap(ref);
    });

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final markers = ref.watch(markersProvider2);

    return Scaffold(
      drawer: CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(58, 66, 86, 1),
        title: CustomAppBar(title: ref.read(projectNameProvider)),
      ),
      body: SlidingUpPanel(
        controller: _panelController,
        disableDraggableOnScrolling: true,
        minHeight: 60,
        color: Color.fromRGBO(255, 255, 255, 0.3),
        panelBuilder: () {
          return GestureDetector(
            onVerticalDragUpdate: (details) {
              // Calculate the new panel position
              double newPosition = _panelController.panelPosition +
                  details.primaryDelta! / MediaQuery.of(context).size.height;

              // Clamp the value between 0.0 and 1.0
              newPosition = newPosition.clamp(0.0, 1.0);

              // Update the panel position
              _panelController.panelPosition = newPosition;
            },
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_panelController.isPanelOpen) {
                        _panelController.close();
                      } else {
                        _panelController.open();
                      }
                    },
                    child: Container(
                      height: 20,
                      color: Colors.grey[300], // Handle color
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          color: Colors.grey, // Actual handle
                        ),
                      ),
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
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
                      controller: _tabController,
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
                                                .read(layerOpacityProvider
                                                    .notifier)
                                                .state = newValue;
                                            ref
                                                .read(mapStateProvider.notifier)
                                                .setLayerOpacity(newValue);
                                          },
                                          onChangeEnd: (newValue) {
                                            ref
                                                .read(layerOpacityProvider
                                                    .notifier)
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
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.all(20.0),
                                        child: BarChartContainer(),
                                      ),
                                    ),
                                    RangeSlider(
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
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                        SafeArea(
                          child: TabData(),
                        ),
                        SafeArea(
                          child: TabUser(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                          gradient: {
                            0: Colors.green,
                            0.1: Colors.lime,
                            0.55: Colors.yellow,
                            0.9: Colors.red,
                            1.0: Colors.red
                          },
                          minOpacity: 0,
                          blurFactor: 0.1,
                          layerOpacity: mapSettings.mapOpacity,
                          radius: mapSettings.pointRadius,
                        ),
                      ); //TODO find a better HeatMap maybe MapBox?
                    },
                  );
                }),
                MarkerLayer(
                  markers: markers.toList(),
                ),//TODO add another Marker LAyer wit small black dots 
                //CurrentLocationLayer(),
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

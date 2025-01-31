import 'package:flutter/material.dart';
//import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

import 'package:terratrace/source/common_widgets/async_value_widget.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/common_widgets/custom_drawer.dart';
import 'package:terratrace/source/constants/text_styles.dart';
// import 'package:terratrace/source/features/bar_chart/presentation/bar_chart_container.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';

import 'package:terratrace/source/features/map/data/map_data.dart';
import 'package:terratrace/source/features/map/presentation/tab_data.dart';
import 'package:terratrace/source/features/map/presentation/tab_user.dart';
import 'package:latlong2/latlong.dart';

final panelDraggableProvider = StateProvider<bool>((ref) => true);

class HeatMapScreen extends ConsumerStatefulWidget {
  @override
  _HeatMapScreenState createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends ConsumerState<HeatMapScreen>
    with SingleTickerProviderStateMixin {
  late final PanelController _panelController = PanelController();
  late final MapController _mapController = MapController();
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

  @override
  Widget build(BuildContext context) {
    final cameraPosition = ref.watch(initialCameraPositionProvider);
    final markers = ref.watch(mapStateProvider).heatmaps;

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
        body: _buildMap(cameraPosition, markers.toList()),
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

  Widget _buildMap(LatLng cameraPosition, List<WeightedLatLng> heatmapData) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
          initialCenter: cameraPosition,
          initialZoom: 14.0,
          onMapReady: () {
            ref
                .read(mapStateProvider.notifier)
                .setWeightedLatLngList(heatmapData);
          },
          onPositionChanged: (position, hasGesture) {
            final zoom = position.zoom;
            final newRadius =
                (70 / zoom).clamp(15.0, 60.0).toDouble(); // Ensure double
            final newOpacity = (zoom / 14)
                .clamp(0.5, 1.0)
                .toDouble(); // Ensure double// Ensure double

            ref.read(mapStateProvider.notifier).setRadius(newRadius);
            ref.read(mapStateProvider.notifier).setLayerOpacity(newOpacity);
            ref.read(showMarkersProvider.notifier).state = zoom > 15;
          }),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        ),
        Consumer(builder: (context, ref, child) {
          return AsyncValueWidget<MapSettings>(
            value: ref.watch(mapSettingsProvider),
            data: (mapSettings) {
              return Stack(
                children: [
                  // Heatmap Layer
                  HeatMapLayer(
                    heatMapDataSource: InMemoryHeatMapDataSource(
                      data: mapSettings.weightedLatLngList,
                    ),
                    heatMapOptions: HeatMapOptions(
                      gradient: {
                        0.0: Colors.green,
                        0.3: Colors.yellow,
                        0.6: Colors.orange,
                        0.8: Colors.red,
                        1.0: Colors.purple,
                      },
                      minOpacity: 0.3, // Adjusted minimum opacity
                      blurFactor: (mapSettings.pointRadius / 12)
                          .clamp(0.1, 0.8), // Adjust blur
                      layerOpacity: mapSettings.mapOpacity,
                      radius: mapSettings.pointRadius,
                    ),
                  ),
                  //Show flag markers only when zoom > 15
                  if (mapSettings.showMarkers)
                    MarkerLayer(
                      markers: heatmapData.map((data) {
                        return Marker(
                          point: data.latLng,
                          width: 30,
                          height: 30,
                          // The `child` parameter is the widget that represents the marker.
                          child: GestureDetector(
                            onTap: () {
                              // Show dialog when the marker is tapped
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text("Marker Info"),
                                    content: Text(
                                        "Value: ${data.intensity.toStringAsFixed(2)}"),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text('Close'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey[800],
                              size: 30,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          );
        }),
      ],
    );
  }
}

class PanelControllerSingleton {
  static final PanelController _instance = PanelController();
  static PanelController get instance => _instance;
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/common_widgets/custom_drawer.dart';
import 'package:terratrace/source/constants/app_colors.dart';

import 'package:terratrace/source/constants/text_styles.dart';
import 'package:terratrace/source/features/bar_chart/prensentation/histogram_chart.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';
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

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapStateProvider);
    final heatmapNotifier = ref.read(heatmapProvider.notifier);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("🔍 Debugging heatmap layers...");
          heatmapNotifier.updateHeatmap(mapState);
        },
        child: const Icon(Icons.refresh),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
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
        _panelController.isPanelOpen
            ? _panelController.close()
            : _panelController.open();
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

                final minMaxGram = ref.watch(minMaxGramProvider);

                double newMin = useLogNormalization
                    ? (exp(values.start * log(minMaxGram.maxV + 1)) - 1)
                        .clamp(0.0, minMaxGram.maxV)
                    : values.start.clamp(0.0, minMaxGram.maxV);

                double newMax = useLogNormalization
                    ? (exp(values.end * log(minMaxGram.maxV + 1)) - 1)
                        .clamp(0.0, minMaxGram.maxV)
                    : values.end.clamp(0.0, minMaxGram.maxV);

                final minMaxValues = MinMaxValues(minV: newMin, maxV: newMax);

                // ✅ First, update the state
                ref.read(rangeValuesProvider.notifier).state = minMaxValues;
                ref
                    .read(mapStateProvider.notifier)
                    .updateRangeValues(minMaxValues, ref);

                // ✅ Force heatmap update after change
                ref
                    .read(heatmapProvider.notifier)
                    .updateHeatmap(ref.read(mapStateProvider));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment
                  .spaceEvenly, // ✅ Evenly distributes the columns
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Map Style", style: kMapSetting),
                      MapStyleDropdown(
                        onStyleChanged: (value) {
                          print('HELLO HELLO MapStyleDropdown: $value');
                          ref
                              .read(mapStateProvider.notifier)
                              .setMapStyle(value);

                          // ✅ Ensure the map itself updates
                          final mapboxController = ref
                              .read(heatmapProvider.notifier)
                              .getMapboxController();
                          if (mapboxController != null) {
                            mapboxController.loadStyleURI(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.watch(mapStateProvider).useLogNormalization
                            ? "log norm: on"
                            : "log norm: off",
                        style: kMapSetting,
                      ),
                      Switch(
                        hoverColor: Colors.white,
                        value: useLogNormalization,
                        onChanged: (value) {
                          ref
                              .read(mapStateProvider.notifier)
                              .toggleLogNormalization(ref);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Data type", style: kMapSetting),
                      MapStyleDropdown(
                        onStyleChanged: (value) {
                          print('HELLO HELLO MapStyleDropdown: $value');
                          ref
                              .read(mapStateProvider.notifier)
                              .setMapStyle(value);

                          // ✅ Ensure the map itself updates
                          final mapboxController = ref
                              .read(heatmapProvider.notifier)
                              .getMapboxController();
                          if (mapboxController != null) {
                            mapboxController.loadStyleURI(value);
                          }
                        },
                      ),
                    ],
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
          activeColor: sliderActiveColor,
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
    return mp.MapWidget(
      styleUri: ref.watch(mapStateProvider).mapStyle,
      onMapCreated: (mapboxMap) {
        print("🗺️ Mapbox map created. Initializing...");

        // ✅ Set the controller inside the HeatmapProvider
        ref.read(heatmapProvider.notifier).setMapboxController(mapboxMap);

        // ✅ Ensure camera is set up correctly
        mapboxMap.setCamera(
          mp.CameraOptions(
            zoom: 13,
            center: mp.Point(
              coordinates: mp.Position(12.46811, 50.20735),
            ),
          ),
        );

        // ✅ Trigger heatmap update
        final mapState = ref.read(mapStateProvider);
        ref.read(heatmapProvider.notifier).updateHeatmap(mapState);
      },
      onStyleLoadedListener: (styleData) {
        print("🎨 Map style fully loaded. Ensuring heatmap is displayed...");

        //final mapState = ref.read(mapStateProvider);
        Future.delayed(Duration(milliseconds: 500), () {
          ref
              .read(heatmapProvider.notifier)
              .updateHeatmap(ref.read(mapStateProvider));
        });
      },
    );
  }
}

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
import 'package:terratrace/source/features/map/data/active_button_notifier.dart';
import 'package:terratrace/source/features/map/data/camera_position_notifier.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';
import 'package:terratrace/source/features/map/data/marker_popup_provider.dart';
import 'package:terratrace/source/features/map/presentation/floating_icon_button.dart';
import 'package:terratrace/source/features/map/presentation/flux_type_dropdown.dart';
import 'package:terratrace/source/features/map/presentation/map_style_dropdown.dart';
import 'package:terratrace/source/features/map/presentation/marker_popup_panel.dart';
import 'package:terratrace/source/features/map/presentation/tab_data.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';

import '../../data/data/data_management.dart';

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
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      //ref.read(heatmapProvider.notifier).initHeatmap();
      ref.read(cameraPositionProvider.notifier).initializeCamera();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // ✅ Manually dispose heatmapProvider when leaving
    ref.read(heatmapProvider.notifier).disposeNotifier();
    // Clear any remaining annotations
    ref.read(mapStateProvider.notifier).clearAnnotations();
    super.dispose();
  }

  bool isSimulating = false; // Track simulation state

  @override
  Widget build(BuildContext context) {
    final activeButton = ref.watch(activeButtonProvider);
    final projectManager = ref.watch(projectManagementProvider.notifier);
    return PopScope(
      canPop: false,
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            if (isSimulating) {
              projectManager.stopFluxSimulation();
            } else {
              projectManager.startFluxSimulation();
            }
            setState(() {
              isSimulating = !isSimulating;
            });
          },
          child: Icon(isSimulating ? Icons.stop : Icons.play_arrow),
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
          body: Stack(children: [
            _buildMap(ref),
            Positioned(
              top: 50,
              left: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FloatingIconButton(
                      icon: Icons.my_location,
                      label: "User Position",
                      isActive: activeButton == "ownPosition",
                      onTap: () {
                        ref
                            .read(cameraPositionProvider.notifier)
                            .toggleCameraMode('ownPosition');
                        ref
                            .read(activeButtonProvider.notifier)
                            .setActiveButton('ownPosition');
                      }),
                  const SizedBox(height: 10), // Space between icons
                  FloatingIconButton(
                    icon: Icons.place,
                    label: "Last Data Point",
                    isActive: activeButton == "latestPoint",
                    onTap: () {
                      ref
                          .read(cameraPositionProvider.notifier)
                          .toggleCameraMode('latestPoint');
                      ref
                          .read(activeButtonProvider.notifier)
                          .setActiveButton('latestPoint');
                    },
                  ),
                ],
              ),
            ),

            /// ✅ Add the marker popup panel here
            MarkerPopupPanel(),
          ]),
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    return Column(
      children: [
        _buildPanelHandle(),
        Expanded(
          child: DefaultTabController(
            length: 2,
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
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMapSettingsTab(context, ref),
                      TabData(),
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
                    max: 15,
                    onChanged: (newValue) {
                      ref.read(radiusProvider.notifier).state = newValue;
                      ref.read(mapStateProvider.notifier).setRadius(newValue);
                      ref
                          .read(heatmapProvider.notifier)
                          .updateHeatmapLayer(ref.read(heatmapLayerProvider));
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
                      ref
                          .read(heatmapProvider.notifier)
                          .updateHeatmapLayer(ref.read(heatmapLayerProvider));
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
              min: useLogNormalization
                  ? log(ref.watch(minMaxGramProvider).minV + 1) /
                      log(ref.watch(minMaxGramProvider).maxV + 1)
                  : ref
                      .read(minMaxGramProvider)
                      .minV, // Ensure min is set to 0 or actual data min
              max:
                  useLogNormalization ? 1.0 : ref.read(minMaxGramProvider).maxV,
              divisions: 100,
              labels: RangeLabels(
                rangeValues.minV.toStringAsFixed(2),
                rangeValues.maxV.toStringAsFixed(2),
              ),
              onChanged: (RangeValues values) async {
                print(
                    "🎚 Range slider updated: ${values.start} - ${values.end}");

                final minMaxGram = ref.watch(minMaxGramProvider);

                // If using log normalization, we need to reverse the transformation to get the actual values.
                double newMin = useLogNormalization
                    ? (exp(values.start * log(minMaxGram.maxV + 1)) - 1).clamp(
                        minMaxGram.minV,
                        minMaxGram.maxV) // Keep min clamped to the data's min
                    : values.start.clamp(minMaxGram.minV, minMaxGram.maxV);

                double newMax = useLogNormalization
                    ? (exp(values.end * log(minMaxGram.maxV + 1)) - 1).clamp(
                        minMaxGram.minV,
                        minMaxGram.maxV) // Keep max within data's max
                    : values.end.clamp(minMaxGram.minV, minMaxGram.maxV);

                final minMaxValues = MinMaxValues(minV: newMin, maxV: newMax);

                print(
                    "🟢 New Min/Max Values: ${minMaxValues.minV} : ${minMaxValues.maxV}");

                // ✅ First, update the state
                ref.read(rangeValuesProvider.notifier).state = minMaxValues;
                print(
                    "🟢 rangeValuesProvider updated: ${ref.read(rangeValuesProvider)}");

                // ✅ Then update the map state
                ref
                    .read(mapStateProvider.notifier)
                    .updateRangeValues(minMaxValues, ref);

                // ✅ Finally, update the heatmap
                print("🔥 Calling updateHeatmapLayer()...");
                ref
                    .read(heatmapProvider.notifier)
                    .updateHeatmapLayer(ref.read(heatmapLayerProvider));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment:
                  CrossAxisAlignment.start, // ✅ Evenly distributes the columns
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
                      Text("Data type:", style: kMapSetting),
                      FluxTypeDropdown()
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
    final cameraOptions = ref.watch(cameraPositionProvider).cameraOptions;
    final mapStyle = ref.watch(mapStateProvider).mapStyle;

    return mp.MapWidget(
      styleUri: mapStyle,
      onTapListener: (mapContentGestureContext) {
        ref
            .read(heatmapProvider.notifier)
            .onMapTap(mapContentGestureContext); // Call the notifier method
        // _onMapTap(mapContentGestureContext);
      },
      onMapCreated: (mapboxMap) {
        mapboxMap.location.updateSettings(
          mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
        );
        print("🗺️ Mapbox map created. Initializing...");

        // Set the controller without triggering updates
        ref.read(heatmapProvider.notifier).setMapboxController(mapboxMap);

        // Set the initial camera position
        mapboxMap.setCamera(cameraOptions);
      },
      onStyleLoadedListener: (styleData) async {
        final fluxDataList = await ref.read(fluxDataListProvider.future);
        print("🎨 Map style data loaded. Initializing heatmap...");
        // Ensure annotations are updated
        await ref.read(mapStateProvider.notifier).updateSelectedAnnotations();
        await ref
            .read(heatmapProvider.notifier)
            .updateHeatmapSource(fluxDataList);
        await ref.read(heatmapProvider.notifier).updateMarkerLayer();
        await ref.read(heatmapProvider.notifier).updateTransparentMarkerLayer();
        
        // Set up layer ordering
        await ref.read(heatmapProvider.notifier).setupLayerOrder();

        // Set the style-loaded state to true
        Future.delayed(Duration(seconds: 5), () {
          ref.read(isStyleLoadedProvider.notifier).state = true;
          print("🎨 Map style loaded. isStyleLoadedProvider: true");
        });
      },
    );
  }

  
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

import 'package:terratrace/source/common_widgets/custom_appbar.dart';
import 'package:terratrace/source/common_widgets/custom_drawer.dart';
import 'package:terratrace/source/constants/text_styles.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/data/map_provider.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';
import 'package:terratrace/source/features/map/presentation/tab_data.dart';
import 'package:terratrace/source/features/map/presentation/tab_user.dart';

final panelDraggableProvider = StateProvider<bool>((ref) => true);

class MarkerMapScreen extends ConsumerStatefulWidget {
  final PanelController? panelController;

  MarkerMapScreen({this.panelController});

  @override
  _MarkerMapScreenState createState() => _MarkerMapScreenState();
}

class _MarkerMapScreenState extends ConsumerState<MarkerMapScreen>
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
      _tabController.animateTo(0); // Switch to the "Data" tab initially
    });

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final cameraPosition = ref.watch(initialCameraPositionProvider);
    final markers = ref.watch(markersProvider2); // Watch the markers provider

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
              length: 2,
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
                      Tab(text: 'Data'),
                      Tab(text: 'User'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SafeArea(child: TabData()),
                        SafeArea(child: TabUser()),
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
                //initialCenter: cameraPosition,
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

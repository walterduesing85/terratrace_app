import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_maps_flutter_heatmap/google_maps_flutter_heatmap.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

import 'package:terra_trace/source/common_widgets/custom_appbar.dart';
import 'package:terra_trace/source/common_widgets/custom_drawer.dart';

import 'package:terra_trace/source/constants/text_styles.dart';

import 'package:terra_trace/source/features/data/data/data_management.dart';

import 'package:terra_trace/source/features/map/data/map_data.dart';
import 'package:terra_trace/source/features/map/presentation/tab_data.dart';

import '../../data/data/map_provider.dart';

class MarkerMapScreen extends ConsumerStatefulWidget {
  final PanelController? panelController;

  MarkerMapScreen({this.panelController});

  @override
  _MarkerMapScreenState createState() => _MarkerMapScreenState();
}

class _MarkerMapScreenState extends ConsumerState<MarkerMapScreen> {
  @override
  Widget build(BuildContext context) {
    final cameraPosition = ref.watch(initialCameraPositionProvider2);
    final markers = ref.watch(markersProvider2); // Watch the markers provider

    return Scaffold(
      drawer: CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(58, 66, 86, 1),
        title: CustomAppBar(title: 'Heat Map'),
      ),
      body: SlidingUpPanel(
        controller: widget.panelController,
        minHeight: 60,
        color: Color.fromRGBO(255, 255, 255, 0.3),
        panelBuilder: () {
          return DefaultTabController(
            length: 1,
            child: Column(
              children: [
                TabBar(
                  labelStyle: tabLabels,
                  tabs: [
                    Tab(text: 'Data'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      TabData(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        body: GoogleMap(
          myLocationEnabled: true,
          mapType: MapType.satellite,
          initialCameraPosition: CameraPosition(
            target: cameraPosition,
            zoom: 14,
            tilt: 10,
          ),
          onMapCreated: (GoogleMapController controller) {
            ref.read(mapControllerProvider.notifier).setController(controller);
          },
          markers: markers,
        ),
      ),
    );
  }
}

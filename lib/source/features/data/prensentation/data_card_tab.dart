import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:terra_trace/source/constants/constants.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/data/data/map_provider.dart';

import 'package:terra_trace/source/features/data/domain/flux_data.dart';
import 'package:terra_trace/source/routing/app_router.dart';

class DataCardTab extends ConsumerStatefulWidget {
  const DataCardTab({
    Key? key,
    required this.fluxData,
  }) : super(key: key);

  final FluxData fluxData;

  @override
  _DataCardTabState createState() => _DataCardTabState();
}

class _DataCardTabState extends ConsumerState<DataCardTab> {
  String truncateWithEllipsis(String str, int maxLength) {
    return (str.length <= maxLength)
        ? str
        : '${str.substring(0, maxLength - 3)}...';
  }

  void showEditDialog(BuildContext context, FluxData fluxData) {
    Alert(
      context: context,
      title: 'Edit Data?',
      buttons: [
        DialogButton(
          child: Text('No'),
          onPressed: () {
            Navigator.of(context).pop(); // Dismiss the dialog
          },
          color: Colors.red,
        ),
        DialogButton(
          child: Text('Yes'),
          onPressed: () {
            context.pushNamed(AppRoute.editDataScreen.name,
                pathParameters: {'projectName': ref.read(projectNameProvider)},
                extra: fluxData); // Dismiss the dialog
            //Navigator.pushNamed(); // Navigate to edit screen
          },
          color: Colors.green,
        ),
      ],
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected =
        ref.watch(selectedFluxDataProvider).contains(widget.fluxData);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.0),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(width: 1.0, color: Colors.white24),
                    ),
                  ),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      ref
                          .read(selectedFluxDataProvider.notifier)
                          .toggleFluxData(widget
                              .fluxData); //TODO Implement when checked Marker is out on the map
                    },
                    activeColor: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: MaterialButton(
                    onLongPress: () => showEditDialog(context, widget.fluxData),
                    onPressed: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          truncateWithEllipsis(widget.fluxData.dataSite!, 20),
                          style: kCardHeadeTextStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          widget.fluxData.dataDate!,
                          style: kCardSubtitleTextStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(width: 1.0, color: Colors.black38),
                    ),
                  ),
                  child: MaterialButton(
                    child: const Icon(
                      Icons.gps_fixed,
                      color: Colors.black,
                      size: 25.0,
                    ),
                    onPressed: () {
                      print('Pressed');
                      final mapController =
                          ref.read(mapControllerProvider.notifier);
                      final target = LatLng(
                          double.parse(widget.fluxData.dataLat!),
                          double.parse(widget.fluxData.dataLong!));
                      mapController
                          .moveCamera(target); //TODO implement move camera
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

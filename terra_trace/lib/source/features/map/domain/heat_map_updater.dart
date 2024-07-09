import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/features/map/data/map_data.dart';

class HeatmapUpdater extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightedLatLngList = ref.watch(weightedLatLngListProvider);
    final radius = ref.watch(radiusProvider);
    final opacity = ref.watch(layerOpacityProvider);

    weightedLatLngList.when(
      data: (data) {
        final heatmapController = ref.read(heatmapControllerProvider.notifier);
        heatmapController.updateHeatmap(data, radius, opacity);
      },
      loading: () {
        // Handle loading state if needed
      },
      error: (error, stackTrace) {
        // Handle error state if needed
      },
    );

    return Container(); // This widget itself doesn't render anything.
  }
}

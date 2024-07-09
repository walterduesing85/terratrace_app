import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/features/bar_chart/domain/bin_data.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class ChartDataUpdater extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<charts.Series<BinData, String>>>>(chartsSeriesListProvider, (previous, next) {
      next.when(
        data: (dataSeriesList) {
          ref.read(chartDataProvider.notifier).updateData(dataSeriesList);
        },
        loading: () {},
        error: (error, stackTrace) {},
      );
    });

    return Container(); // Return an empty container as this widget doesn't need to display anything.
  }
}

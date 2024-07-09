import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/features/bar_chart/domain/bin_data.dart';

class ChartDisplay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSeriesList = ref.watch(chartDataProvider);

    return charts.BarChart(
      dataSeriesList,
      animate: false,
      vertical: false,
      domainAxis: charts.OrdinalAxisSpec(
        renderSpec: charts.SmallTickRendererSpec(
          labelStyle: charts.TextStyleSpec(
            fontSize: 14,
            color: charts.MaterialPalette.black,
          ),
          lineStyle: charts.LineStyleSpec(
            color: charts.MaterialPalette.black,
          ),
        ),
      ),
      primaryMeasureAxis: charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
          tickLengthPx: 2,
          labelStyle: charts.TextStyleSpec(
            fontSize: 14,
            color: charts.MaterialPalette.black,
          ),
          lineStyle: charts.LineStyleSpec(
            color: charts.MaterialPalette.black,
          ),
        ),
      ),
    );
  }
}

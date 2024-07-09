import 'package:flutter/material.dart';
import 'package:terra_trace/source/features/bar_chart/presentation/chart_display.dart';

import '../domain/char_data_updater.dart';

class BarChartContainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChartDataUpdater(), // This widget will fetch and update the data
        Expanded(
          child: ChartDisplay(), // This widget will display the chart
        ),
      ],
    );
  }
}

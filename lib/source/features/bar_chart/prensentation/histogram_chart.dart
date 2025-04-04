import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/common_widgets/async_value_widget.dart';
import 'package:terratrace/source/features/bar_chart/data/bin_edges.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_data.dart';

class HistogramChart extends ConsumerWidget {
  const HistogramChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binData = ref.watch(binProvider).maybeWhen(
          data: (bins) => bins as List<BinData>,
          orElse: () => <BinData>[],
        );
        final binColors = ref.watch(binColorProvider);

        return AspectRatio(
          aspectRatio: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BarChart(
              BarChartData(
                barGroups: _createBarGroups(binData, binColors),
                titlesData: FlTitlesData(
              rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false, reservedSize: 40),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= 0 && value.toInt() < binData.length) {
                          return Padding(
                        padding: const EdgeInsets.only(top: 10, left: 6),
                            child: RotationTransition(
                          turns: AlwaysStoppedAnimation(70 / 360),
                              child: Text(
                            binData[value.toInt()].binValue.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
            ),
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups(
      List<BinData> binData, List<Color> binColors) {
    return binData.asMap().entries.map((entry) {
      int index = entry.key;
      BinData bin = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: bin.binCounts.toDouble(),
            color: binColors.isNotEmpty && index < binColors.length
                ? binColors[index]
                : Colors.grey,
            width: 20,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    }).toList();
  }
}

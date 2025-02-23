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
    return AsyncValueWidget<List<BinData>>(
      value: ref.watch(binProvider),
      data: (binData) {
        print("📊 Rendering Histogram Chart with ${binData.length} bins");

        if (binData.isEmpty) {
          print(
              "⚠️ No bin data available! Histogram will not display anything.");
          return const Center(child: Text("No data available"));
        }
        final binColors = ref.watch(binColorProvider);

        return AspectRatio(
          aspectRatio: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BarChart(
              BarChartData(
                barGroups: _createBarGroups(binData, binColors),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < binData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              top: 6,
                              left: 6,
                            ),
                            child: RotationTransition(
                              turns: AlwaysStoppedAnimation(25 / 360),
                              child: Text(
                                binData[value.toInt()]
                                    .binValue
                                    .toStringAsFixed(1),
                                style: const TextStyle(fontSize: 10),
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
                gridData: FlGridData(show: true),
              ),
            ),
          ),
        );
      },
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
            color: binColors[index],
            width: 20,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    }).toList();
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_data.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_state_notifier.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class BinEdges {
  BinEdges({
    this.numEdges = 10,
    required this.cO2,
    this.rangeValues = const MinMaxValues(minV: 30.0, maxV: 70.0),
    required this.useLogNormalization,
  }) {
    print(
        "🛠 Initializing BinEdges with Log Normalization: $useLogNormalization");

    processedCO2 = getProcessedCO2Values(cO2, useLogNormalization);

    minValue = processedCO2.isNotEmpty
        ? processedCO2.reduce((a, b) => a < b ? a : b)
        : 0.0;
    maxValue = processedCO2.isNotEmpty
        ? processedCO2.reduce((a, b) => a > b ? a : b)
        : 1.0;

    print(
        "📊 Min CO₂: $minValue, Max CO₂: $maxValue, Data points: ${processedCO2.length}");
  }

  final int numEdges;
  late double minValue;
  late double maxValue;
  final List<double> cO2;
  late List<double> processedCO2;
  final MinMaxValues rangeValues;
  final bool useLogNormalization;

  List<double> getProcessedCO2Values(
      List<double> rawCO2, bool useLogNormalization) {
    if (rawCO2.isEmpty) return [];

    if (!useLogNormalization) {
      return rawCO2;
    }

    return rawCO2.map((v) => log(v + 1)).toList();
  }

  List<double> makeBinEdges() {
    List<double> binEdges = [];
    double binSize = (maxValue - minValue) / numEdges;

    print(
        "📊 Calculating Bin Edges with binSize: $binSize, min: $minValue, max: $maxValue");

    for (int i = 0; i <= numEdges; i++) {
      binEdges.add(minValue + i * binSize);
      }

    return binEdges;
  }

  List<BinData> makeBinData() {
    List<double> bins = makeBinEdges();
    double binSize = (maxValue - minValue) / numEdges;
    print("📦 Creating Histogram Data with bin size: $binSize");

    List<BinData> binData = List.generate(numEdges, (i) {
      if (i >= bins.length - 1) {
        return BinData(binCounts: 0, binValue: bins[i], binColor: Colors.grey);
      }

      double lowerBound = bins[i];
      double upperBound = bins[i + 1];

      int count;
      if (i == numEdges - 1) {
        // ✅ Include maxValue in the last bin
        count = processedCO2
            .where((value) => value >= lowerBound && value <= upperBound)
            .length;
      } else {
        count = processedCO2
            .where((value) => value >= lowerBound && value < upperBound)
            .length;
      }

      double binLabelValue = useLogNormalization ? exp(bins[i]) - 1 : bins[i];

      return BinData(
        binCounts: count,
        binValue: binLabelValue,
        binColor: _getBinColor(binLabelValue),
      );
    });

    return binData;
  }

  Color _getBinColor(double binValue) {
    if (binValue < rangeValues.minV) return Colors.green;
    if (binValue > rangeValues.maxV) return Colors.red;
    return Colors.yellow;
  }
}

final staticBinEdgesProvider = Provider<BinEdges>((ref) {
  final chartState = ref.watch(chartStateProvider);
  final mapState =
      ref.watch(mapStateProvider.select((state) => state.useLogNormalization));

  return BinEdges(
    numEdges: chartState.numEdges,
    cO2: chartState.cO2,
    rangeValues: chartState.rangeValues,
    useLogNormalization: mapState,
  );
});

final binProvider = FutureProvider<List<BinData>>((ref) {
  final binEdges = ref.watch(staticBinEdgesProvider);
  return Future.value(binEdges.makeBinData());
});

// final binColorProvider = Provider<List<Color>>((ref) {
//   final rangeValues = ref.watch(rangeValuesProvider);
//   final binData = ref.watch(binProvider);

//   return binData.when(
//     data: (bins) => bins.map((bin) {
//       if (bin.binValue < rangeValues.minV) {
//         return Colors.green;
//       } else if (bin.binValue > rangeValues.maxV) {
//         return Colors.red;
//       } else {
//         return Colors.yellow;
//       }
//     }).toList(),
//     loading: () => [],
//     error: (_, __) => [],
//   );
// });

final binColorProvider = Provider<List<Color>>((ref) {
  final rangeValues = ref.watch(rangeValuesProvider);
  final binData = ref.watch(binProvider);

  Color getHeatmapColor(double value, double min, double max) {
    double normalizedValue = (value - min) / (max - min);

    if (normalizedValue <= 0.0) return Color.fromRGBO(0, 0, 255, 0.8);
    if (normalizedValue <= 0.2) return const Color.fromRGBO(65, 105, 225, 1.0);
    if (normalizedValue <= 0.4) return Colors.cyan;
    if (normalizedValue <= 0.6) return Colors.lime;
    if (normalizedValue <= 0.8) return Colors.yellow;
      return Colors.red;
  }

  return binData.when(
    data: (bins) => bins.map((bin) {
      return getHeatmapColor(bin.binValue, rangeValues.minV, rangeValues.maxV);
    }).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

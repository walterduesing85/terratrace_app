import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_data.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_state_notifier.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class BinEdges {
  BinEdges({
    this.numEdges = 10,
    this.minValue = 0.0,
    this.maxValue = 50,
    this.cO2 = const [],
    this.rangeValues = const MinMaxValues(minV: 30.0, maxV: 70.0),
  }) {
    print("🛠 Initializing BinEdges with:");
    print("   - numEdges: $numEdges");
    print("   - minValue: $minValue");
    print("   - maxValue: $maxValue");
    print("   - CO₂ Data: ${cO2.length} values → $cO2");
  }

  final int numEdges;
  final double minValue;
  final double maxValue;
  final List<double> cO2;
  final MinMaxValues rangeValues;

  List<double> makeBinEdges() {
    List<double> binEdges = [];
    double binSize = (maxValue - minValue) / numEdges;
    print("📊 Calculating Bin Edges with binSize: $binSize");
    for (int i = 0; i < numEdges; i++) {
      if (i == 0) {
        binEdges.add(minValue + (binSize / 2));
      } else {
        binEdges.add(binEdges[i - 1] + binSize);
      }
      print("   - Bin $i: ${binEdges[i]}");
    }
    return binEdges;
  }

  List<BinData> makeBinData() {
    List<double> bins = makeBinEdges();
    double binSize = (maxValue - minValue) / numEdges;
    print("📦 Creating Histogram Data with bin size: $binSize");

    List<BinData> binData = List.generate(numEdges, (i) {
      int count = cO2.where((value) {
        double lowerBound = bins[i] - (binSize / 2);
        double upperBound = bins[i] + (binSize / 2);
        return value >= lowerBound && value < upperBound;
      }).length;

      if (i == numEdges - 1) {
        count += cO2.where((value) => value >= bins[i] - (binSize / 2)).length;
      }

      Color binColor;
      if (bins[i] < rangeValues.minV) {
        binColor = Colors.green;
      } else if (bins[i] > rangeValues.maxV) {
        binColor = Colors.red;
      } else {
        binColor = Colors.yellow;
      }

      print(
          "   🏷 Bin $i: ${bins[i].toStringAsFixed(1)}, Count: $count, Color: $binColor");

      return BinData(binCounts: count, binValue: bins[i], binColor: binColor);
    });

    print("✅ Binning Complete. Total bins: ${binData.length}");
    return binData;
  }
}

final binEdgesProvider = Provider<BinEdges>((ref) {
  final chartState = ref.watch(chartStateProvider);
  print(
      "📡 Updating BinEdges from ChartState: min=${chartState.minValue}, max=${chartState.maxValue}");

  return BinEdges(
    numEdges: chartState.numEdges,
    minValue: chartState.minValue,
    maxValue: chartState.maxValue,
    cO2: chartState.cO2, // ✅ Ensure updated CO₂ values are used!
    rangeValues: chartState.rangeValues,
  );
});

final binProvider = FutureProvider<List<BinData>>((ref) {

  final binEdges = ref.watch(binEdgesProvider);
  return Future.value(binEdges.makeBinData());
});

final binStructureProvider = Provider<List<BinData>>((ref) {
  final chartState = ref.watch(chartStateProvider);

  return BinEdges(
    numEdges: chartState.numEdges,
    minValue: chartState.minValue,
    maxValue: chartState.maxValue,
    cO2: chartState.cO2, // ✅ Ensuring CO₂ values are used only for structure
    rangeValues: const MinMaxValues(minV: 30.0, maxV: 70.0), // Placeholder
  ).makeBinData(); // ✅ Structure is generated ONCE
});

final binColorProvider = Provider<List<Color>>((ref) {
  final rangeValues = ref.watch(rangeValuesProvider); // ✅ Listen to range slider
  final binData = ref.watch(binStructureProvider);

  return binData.map((bin) {
    if (bin.binValue < rangeValues.minV) {
      return Colors.green;
    } else if (bin.binValue > rangeValues.maxV) {
      return Colors.red;
    } else {
      return Colors.yellow;
    }
  }).toList();
});

import 'package:flutter/material.dart';
import 'package:terra_trace/source/features/bar_chart/domain/bin_data.dart';
import 'package:charts_flutter/flutter.dart' as charts;

import '../../map/data/map_data.dart';
import 'bin_data.dart';

class BinEdges {
  BinEdges(
      {this.numEdges,
      this.minValue,
      this.maxValue,
      this.cO2,
      this.rangeValues});

  final int numEdges;
  final double minValue;
  final double maxValue;
  final List<double> cO2;
  final MinMaxValues rangeValues;

  List<double> makeBinEdges() {
    List<double> binEdges = [];
    double binSize = (maxValue - minValue) / numEdges;
    for (int i = 0; i < numEdges; i++) {
      if (i == 0) {
        binEdges.add(minValue + (binSize / 2));
      } else if (i > 0) {
        binEdges.add(binEdges[i - 1] + binSize);
      }
    }

    return binEdges;
  }

  List<BinData> makeBinData() {
    List<double> bins = makeBinEdges();
    double binSize = (maxValue - minValue) / numEdges;
    final List<BinData> binData = [];

    int num = cO2.length;
    int count;
    for (int i = 0; i < numEdges; i++) {
      count = 0;
      List<double> range = [bins[i] - (binSize / 2), bins[i] + (binSize / 2)];

      for (int j = 0; j < num; j++) {
        double value = cO2[j];

        if (value >= range[0] && value < range[1]) {
          count++;
        }
        if (i == numEdges - 1 && value >= range[0]) {
          count++;
        }
        charts.Color binColor;
        if (bins[i] < rangeValues.minV) {
          binColor = charts.ColorUtil.fromDartColor(Colors.green);
        } else if (bins[i] > rangeValues.maxV) {
          binColor = charts.ColorUtil.fromDartColor(Colors.red);
        } else {
          binColor = charts.ColorUtil.fromDartColor(Colors.yellow);
        }

        binData.add(
            BinData(binCounts: count, binValue: bins[i], binColor: binColor));
      }
    }
    return binData;
  }
}

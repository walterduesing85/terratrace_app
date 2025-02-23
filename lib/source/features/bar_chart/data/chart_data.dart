import 'package:flutter/material.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class BinData {
  BinData({
    required this.binCounts,
    required this.binValue,
    required this.binColor,
  });

  final int binCounts;
  final double binValue;
  final Color binColor;
}

class ChartState {
  ChartState({
    this.numEdges = 12,
    this.minValue = 0.0,
    this.maxValue = 120,
    this.cO2 = const [],
    this.rangeValues = const MinMaxValues(minV: 30.0, maxV: 70.0),
  });

  final int numEdges;
  final double minValue;
  final double maxValue;
  final List<double> cO2;
  final MinMaxValues rangeValues;

  // ✅ Create a copyWith method for immutability
  ChartState copyWith({
    int? numEdges,
    double? minValue,
    double? maxValue,
    List<double>? cO2,
    MinMaxValues? rangeValues,
  }) {
    return ChartState(
      numEdges: numEdges ?? this.numEdges,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      cO2: cO2 ?? this.cO2,
      rangeValues: rangeValues ?? this.rangeValues,
    );
  }
}
  
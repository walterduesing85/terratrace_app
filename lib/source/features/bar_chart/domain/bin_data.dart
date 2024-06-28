import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'dart:math';

import 'package:terra_trace/source/features/bar_chart/domain/bin_edges.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/data/domain/flux_data.dart';
import 'package:terra_trace/source/features/map/data/map_data.dart';

class BinData {
  BinData({
    this.binCounts,
    this.binValue,
    this.maxValue,
    this.minValue,
    this.binColor,
  });

  final binColor;
  final int binCounts;
  final double binValue;

  final double maxValue;
  final double minValue;

  List<charts.Series<BinData, String>> createBins(
      List<FluxData> fluxDataList, MinMaxValues rangeValues) {
    final List<double> cO2 = [];
    List<BinData> binData = [];
    final int num = fluxDataList.length;

    final List<charts.Color> binColors = [];

    List<double> binEdges;

    for (int i = 0; i < num; i++) {
      cO2.add(double.parse(fluxDataList[i].dataCfluxGram));

      // Add more colors as needed

    }

    final double minData = cO2.reduce(min);
    final double maxData = cO2.reduce(max);

    if (num <= 10) {
      binEdges = [minData, maxData];
      int count = num;
      binData.add(BinData(binCounts: count, binValue: (binEdges[1])));
      binColors.add(charts.ColorUtil.fromDartColor(Colors.blue));
    } else if (num > 10 && num < 50) {
      BinEdges binEdges = BinEdges(
        cO2: cO2,
        minValue: minData,
        maxValue: maxData,
        numEdges: 4,
        rangeValues: rangeValues,
      );

      for (int i = 0; i < 4; i++) {
        binColors.add(charts.ColorUtil.fromDartColor(Colors.green));
      }

      binData = binEdges.makeBinData();
    } else if (num > 50 && num < 100) {
      BinEdges binEdges = BinEdges(
          cO2: cO2,
          minValue: minData,
          maxValue: maxData,
          numEdges: 12,
          rangeValues: rangeValues);
      binData = binEdges.makeBinData();
    } else if (num > 100 && num < 250) {
      BinEdges binEdges = BinEdges(
          cO2: cO2,
          minValue: minData,
          maxValue: maxData,
          numEdges: 12,
          rangeValues: rangeValues);
      binData = binEdges.makeBinData();
    } else if (num > 250) {
      BinEdges binEdges = BinEdges(
          cO2: cO2,
          minValue: minData,
          maxValue: maxData,
          numEdges: 15,
          rangeValues: rangeValues);
      binData = binEdges.makeBinData();

      for (int i = 0; i < 15; i++) {
        if (binData[i].binValue < rangeValues.minV) {
          binColors.add(charts.ColorUtil.fromDartColor(Colors.red));
        } else {
          binColors.add(charts.ColorUtil.fromDartColor(Colors.yellow));
        }
      }
    }

    return [
      charts.Series<BinData, String>(
        id: 'Data',
        domainFn: (BinData binData, _) => binData.binValue.round().toString(),
        measureFn: (BinData binData, _) => binData.binCounts,
        colorFn: (BinData binData, _) => binData.binColor,
        // Get the color for this bin based on its index

        // Apply custom colors
        data: binData,
      )
    ];
  }
}

// final chartsSeriesListProvider =
//     FutureProvider.autoDispose<List<charts.Series<BinData, String>>>(
//         (ref) async {
//   final rangeSliderValues = ref.watch(rangeSliderNotifierProvider);
//   final fluxDataListAsyncValue = ref.watch(fluxDataListProvider);

//   final fluxDataList = await fluxDataListAsyncValue.when(
//     data: (dataList) => dataList,
//     loading: () => [],
//     error: (error, stackTrace) => [],
//   );

//   final binData = BinData();
//   final seriesList = binData.createBins(fluxDataList, rangeSliderValues);

//   return seriesList;
// });

// class ChartDataNotifier
//     extends StateNotifier<List<charts.Series<BinData, String>>> {
//   ChartDataNotifier() : super([]);

//   void updateData(List<charts.Series<BinData, String>> newData) {
//     state = newData;
//   }
// }

// final chartDataProvider = StateNotifierProvider<ChartDataNotifier,
//     List<charts.Series<BinData, String>>>((ref) {
//   return ChartDataNotifier();
// });

final chartsSeriesListProvider =
    FutureProvider.autoDispose<List<charts.Series<BinData, String>>>((ref) async {
  final rangeSliderValues = ref.watch(rangeSliderNotifierProvider);
  final fluxDataListAsyncValue = ref.watch(fluxDataListProvider);

  final fluxDataList = await fluxDataListAsyncValue.when(
    data: (dataList) => dataList,
    loading: () => [],
    error: (error, stackTrace) => [],
  );

  final binData = BinData();
  final seriesList = binData.createBins(fluxDataList, rangeSliderValues);

  return seriesList;
});

class ChartDataNotifier extends StateNotifier<List<charts.Series<BinData, String>>> {
  ChartDataNotifier() : super([]);

  void updateData(List<charts.Series<BinData, String>> newData) {
    state = newData;
  }
}

final chartDataProvider = StateNotifierProvider<ChartDataNotifier, List<charts.Series<BinData, String>>>((ref) {
  return ChartDataNotifier();
});




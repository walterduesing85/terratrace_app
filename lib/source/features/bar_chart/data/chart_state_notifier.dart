import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/bar_chart/data/chart_data.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class ChartStateNotifier extends StateNotifier<ChartState> {
  final Ref ref;

  ChartStateNotifier(this.ref) : super(ChartState()) {
    _initialize();
  }

  void _initialize() {
    // ✅ Ensure the initial state is populated
    final fluxDataList = ref.read(fluxDataListProvider);
    _updateCO2Data(fluxDataList);

    // ✅ Listen to changes in fluxDataListProvider
    ref.listen<AsyncValue<List<FluxData>>>(fluxDataListProvider, (_, next) {
      _updateCO2Data(next);
    });

    // // ✅ Listen to changes in rangeValuesProvider to update chart state
    // ref.listen<MinMaxValues>(rangeValuesProvider, (_, next) {
    //   print("🔄 Updating range values in ChartState: min=${next.minV}, max=${next.maxV}");
    //   updateRangeValues(next);
    // });
  }

  // ✅ Extracted CO₂ data update logic
  void _updateCO2Data(AsyncValue<List<FluxData>> asyncData) {
    asyncData.when(
      data: (dataList) {
        final co2Values = dataList
            .map((data) => double.tryParse(data.dataCfluxGram ?? '0.0') ?? 0.0)
            .toList();

        if (co2Values.isNotEmpty) {
          final minValue = co2Values.reduce((a, b) => a < b ? a : b);
          final maxValue = co2Values.reduce((a, b) => a > b ? a : b);
          print(
              "📊 Updating ChartState: Min=$minValue, Max=$maxValue, Data=${co2Values.length} values");

          state = state.copyWith(
            minValue: minValue,
            maxValue: maxValue,
            cO2: co2Values,
          );
        }
      },
      loading: () => print("⏳ Waiting for CO₂ data..."),
      error: (err, stack) => print("❌ Error loading CO₂ data: $err"),
    );
  }

  void setNumEdges(int newEdges) {
    state = state.copyWith(numEdges: newEdges);
  }

  void updateRangeValues(MinMaxValues newRange) {
    state = state.copyWith(rangeValues: newRange);
  }
}

// ✅ Use `autoDispose` to free resources when not in use
final chartStateProvider =
    StateNotifierProvider.autoDispose<ChartStateNotifier, ChartState>((ref) {
  return ChartStateNotifier(ref);
});

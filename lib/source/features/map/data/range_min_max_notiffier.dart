import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class RangeMinMaxValuesNotifier extends StateNotifier<MinMaxValues> {
  RangeMinMaxValuesNotifier() : super(const MinMaxValues(minV: 0.0, maxV: 1.0));

  // Track whether the user has manually adjusted the range
  bool _userAdjustedRange = false;

  // Set a percentage threshold (15%) to decide when a change is significant
  static const double thresholdPercentage = 0.15;

  // Function to update the RangeValues based on MinMaxValues
  void updateRangeValues(MinMaxValues newMinMax, bool userAdjusted) {
    // If the user manually adjusted the range, do not update it
    if (_userAdjustedRange) {
      return; // Keep the current range values as they are
    }

    // Calculate the percentage change in minV and maxV
    final minChangePercentage =
        (newMinMax.minV - state.minV).abs() / state.minV;
    final maxChangePercentage =
        (newMinMax.maxV - state.maxV).abs() / state.maxV;

    // If the change is greater than 15% for either minV or maxV, update the state
    if (minChangePercentage > thresholdPercentage ||
        maxChangePercentage > thresholdPercentage) {
      state = newMinMax; // Update the RangeValues
    }
  }

  // Function to allow the user to manually adjust the range values
  void adjustRangeValues(MinMaxValues newRangeValues) {
    _userAdjustedRange = true;
    state = newRangeValues; // Set the range values to the user-selected ones
  }

  // Function to reset the flag when the user is done adjusting
  void resetUserAdjustment() {
    _userAdjustedRange = false;
  }
}

final rangeMinMaxValuesProvider =
    StateNotifierProvider<RangeMinMaxValuesNotifier, MinMaxValues>((ref) {
  return RangeMinMaxValuesNotifier();
});

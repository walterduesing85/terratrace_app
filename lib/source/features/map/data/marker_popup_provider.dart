import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';

class MarkerPopupNotifier extends StateNotifier<List<FluxData>> {
  MarkerPopupNotifier() : super([]);

  /// ✅ Add a new marker popup to the list
  void addPopup(FluxData data) {
    // Check if the data is already in the list (avoid duplicates)
    if (!state.contains(data)) {
      state = [...state, data]; // Append new popup
      print("Added popup for: ${data.dataSite}");
    } else {
      print("Popup already exists for: ${data.dataSite}");
    }
  }

  /// ✅ Remove a popup from the list
  void removePopup(FluxData data) {
    state = state.where((d) => d != data).toList();
  }
}

// ✅ Provider to manage the marker popups
final markerPopupProvider =
    StateNotifierProvider<MarkerPopupNotifier, List<FluxData>>(
  (ref) => MarkerPopupNotifier(),
);

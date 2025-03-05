import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';

class MarkerPopupNotifier extends StateNotifier<List<FluxData>> {
  MarkerPopupNotifier() : super([]);

  /// ✅ Add a new marker popup to the list
  void addPopup(FluxData data) {
    state = [...state, data]; // Append new popup
  }

  /// ✅ Remove a popup from the list
  void removePopup(FluxData data) {
    state = state.where((d) => d != data).toList();
  }
}

// ✅ Provider to manage the marker popups
final markerPopupProvider = StateNotifierProvider<MarkerPopupNotifier, List<FluxData>>(
  (ref) => MarkerPopupNotifier(),
);

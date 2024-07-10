import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';

class MapState {
  Set<WeightedLatLng> heatmaps;
  double zoom;
  double radius;
  double minOpacity;
  double blurFactor;
  double layerOpacity;

  MapState({
    this.heatmaps = const {},
    this.zoom = 15.0,
    this.radius = 30,
    this.minOpacity = 0.3,
    this.blurFactor = 0.5,
    this.layerOpacity = 0.75,
  });

  MapState copyWith({
    Set<WeightedLatLng>? heatmaps,
    double? zoom,
    double? radius,
    double? minOpacity,
    double? blurFactor,
    double? layerOpacity,
  }) {
    return MapState(
      heatmaps: heatmaps ?? this.heatmaps,
      zoom: zoom ?? this.zoom,
      radius: radius ?? this.radius,
      minOpacity: minOpacity ?? this.minOpacity,
      blurFactor: blurFactor ?? this.blurFactor,
      layerOpacity: layerOpacity ?? this.layerOpacity,
    );
  }
}

class MapStateNotifier extends StateNotifier<MapState> {
  MapStateNotifier() : super(MapState());

  void setWeightedLatLngList(List<WeightedLatLng> list) {
    state = state.copyWith(heatmaps: list.toSet());
  }

  void setZoom(double value) {
    state = state.copyWith(zoom: value);
  }

  void setRadius(double value) {
    state = state.copyWith(radius: value);
  }

  void setMinOpacity(double value) {
    state = state.copyWith(minOpacity: value);
  }

  void setBlurFactor(double value) {
    state = state.copyWith(blurFactor: value);
  }

  void setLayerOpacity(double value) {
    state = state.copyWith(layerOpacity: value);
  }

  void initHeatmap(WidgetRef ref) {
    // Initialize the heatmap with data if necessary
  }

  void updateHeatmap(List<WeightedLatLng> data, double radius, double opacity) {
    state = state.copyWith(
      heatmaps: data.toSet(),
      radius: radius,
      layerOpacity: opacity,
    );
  }
}

final mapStateProvider =
    StateNotifierProvider<MapStateNotifier, MapState>((ref) {
  return MapStateNotifier();
});

final radiusProvider = StateProvider<double>((ref) {
  return 30;
});

final layerOpacityProvider = StateProvider<double>((ref) {
  return 0.75;
});

class RangeSliderNotifier extends StateNotifier<RangeValues> {
  RangeSliderNotifier() : super(RangeValues(0.0, 1.0));

  void updateMinMaxValues(double min, double max) {
    state = RangeValues(min, max);
  }
}

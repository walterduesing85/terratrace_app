import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/map/data/marker_popup_provider.dart';
import 'map_data.dart';

final isStyleLoadedProvider = StateProvider<bool>((ref) => false);

class HeatmapNotifier extends StateNotifier<void> {
  HeatmapNotifier(this.ref) : super(null) {
    // Listen for changes in flux data
    ref.listen<AsyncValue<List<FluxData>>>(fluxDataListProvider, (prev, next) {
      // Ensure that the style has been loaded before executing the heatmap updates
      final isStyleLoaded = ref.read(isStyleLoadedProvider);

      if (isStyleLoaded) {
        print("🔥 Style is loaded. Updating heatmap...");
        Future.delayed(Duration(milliseconds: 500), () {
          print("🔥 Style is loaded. Updating heatmap...");
          next.when(
            data: (fluxDataList) async {
              await updateHeatmapSource(fluxDataList);
              await updateMarkerLayer();
              await updateTransparentMarkerLayer();
            },
            loading: () => print("⏳ Flux data is loading..."),
            error: (err, stack) => print("❌ Error loading flux data: $err"),
          );
        });
      }
    });

    // ✅ Listen to changes in selectedDataSetProvider to update chart state
    ref.listen<AsyncValue<List<String>>>(selectedDataSetProvider,
        (_, next) async {
      // Ensure that the style has been loaded before executing the heatmap updates
      final isStyleLoaded = ref.read(isStyleLoadedProvider);
      if (isStyleLoaded) {
        final fluxDataList = await ref.read(fluxDataListProvider.future);
        Future.delayed(Duration(milliseconds: 500), () {
          print("🔥 Style is loaded. Updating heatmap...");
          next.when(
            data: (datat) async {
              await updateHeatmapSource(fluxDataList);
              await updateMarkerLayer();
              await updateTransparentMarkerLayer();
            },
            loading: () => print("⏳ Flux data is loading..."),
            error: (err, stack) => print("❌ Error loading flux data: $err"),
          );
        });
      }
    });
  }

  final Ref ref;
  mp.MapboxMap? _mapboxMapController;
  mp.PointAnnotationManager? _pointAnnotationManager;
  mp.PointAnnotationManager? _selectedAnnotationManager;

  void setMapboxController(mp.MapboxMap controller) {
    _mapboxMapController = controller;
  }

  void disposeNotifier() {
    print("🗑 Disposing HeatmapNotifier...");

    if (_pointAnnotationManager != null) {
      try {
        print("🗑 Removing all base markers...");
        _pointAnnotationManager!.deleteAll();
      } catch (e) {
        print("⚠️ Error disposing PointAnnotationManager: $e");
      } finally {
        _pointAnnotationManager = null;
      }
    }

    if (_selectedAnnotationManager != null) {
      try {
        print("🗑 Removing all selected annotations...");
        _selectedAnnotationManager!.deleteAll();
      } catch (e) {
        print("⚠️ Error disposing SelectedAnnotationManager: $e");
      } finally {
        _selectedAnnotationManager = null;
      }
    }

    _mapboxMapController = null;
  }

  /// ✅ Get the current Mapbox controller
  mp.MapboxMap? getMapboxController() {
    return _mapboxMapController;
  }

  Future<void> updateHeatmapSource(fluxDataList) async {
    if (_mapboxMapController == null) return;

    final selectedFluxType = ref.read(selectedFluxTypeProvider);
    final style = _mapboxMapController!.style;

    print('🔥 Updating heatmap source with ${fluxDataList.length} points');

    // ✅ Check if the heatmap source already exists
    final hasHeatmapSource =
        (await style.getStyleSources()).any((s) => s?.id == "heatmap-source");

    final geoJsonString =
        _convertFluxDataToGeoJSON(fluxDataList, selectedFluxType);

    if (hasHeatmapSource) {
      // ✅ Update existing source instead of adding a new one
      await style.setStyleSourceProperties(
          "heatmap-source", json.encode({"data": json.decode(geoJsonString)}));
      print("🔥 Updated existing heatmap source.");
    } else {
      // ✅ Add the source only if it does NOT exist
      await style.addSource(
          mp.GeoJsonSource(id: "heatmap-source", data: geoJsonString));
      print("🔥 Added new heatmap source.");
    }

    // ✅ Ensure heatmap layer exists
    final layers = await style.getStyleLayers();
    final hasHeatmapLayer = layers.any((l) => l?.id == "heatmap-layer");

    if (!hasHeatmapLayer) {
      print("🔥 Adding heatmap layer...");
      updateHeatmapLayer(ref.read(heatmapLayerProvider));
    }
  }

  Future<void> updateHeatmapLayer(mp.HeatmapLayer heatmapLayer) async {
    if (_mapboxMapController == null) {
      print("🚨 ERROR: MapboxMapController is NULL! Cannot update heatmap.");
      return;
    }

    final style = _mapboxMapController!.style;
    final layers = await style.getStyleLayers();

    final hasHeatmapLayer = layers.any((l) => l?.id == 'heatmap-layer');

    // ✅ Ensure the heatmap layer exists
    if (!hasHeatmapLayer) {
      await style.addLayer(heatmapLayer);
      print("🔥 Added heatmap layer.");
    } else {
      await style.updateLayer(heatmapLayer);
      print("🔥 Updated heatmap layer.");
    }

    // ✅ Move marker layer below the heatmap layer
    final markerLayerIndex = layers.indexWhere((l) => l?.id == 'marker-layer');
    final heatmapLayerIndex =
        layers.indexWhere((l) => l?.id == 'heatmap-layer');

    if (markerLayerIndex > heatmapLayerIndex) {
      print("📍 Moving marker layer below heatmap layer...");
      await style.moveStyleLayer(
          'marker-layer', mp.LayerPosition(below: 'heatmap-layer'));
    }
  }

  Future<void> updateMarkerLayer() async {
    if (_mapboxMapController == null) {
      print("🚨 ERROR: MapboxMapController is NULL! Cannot update heatmap.");
      return;
    }
    final style = _mapboxMapController!.style;
    final layers = await style.getStyleLayers();

    final hasMarkerLayer = layers.any((l) => l?.id == 'marker-layer');

    // ✅ Ensure the custom image is only added once
    if (!layers.any((l) => l?.id == 'marker-icon')) {
      await addCustomImage(_mapboxMapController!, 'marker-icon');
    }

    // ✅ Define the marker layer
    final markerLayer = mp.SymbolLayer(
      id: 'marker-layer',
      sourceId: 'heatmap-source', // Ensure this matches your existing source ID
      iconImage: 'marker-icon', // The ID of the image added to the style
      iconSize: 0.01,
      iconOpacity: 1,
      iconAllowOverlap: true, // Adjust the size as needed
    );

    // ✅ Ensure the marker layer exists
    if (!hasMarkerLayer) {
      await style.addLayer(markerLayer);
      print("📍 Added marker layer.");
    } else {
      await style.updateLayer(markerLayer);
      print("📍 Updated marker layer.");
    }

    // ✅ Move marker layer below the heatmap layer
    final markerLayerIndex = layers.indexWhere((l) => l?.id == 'marker-layer');
    final heatmapLayerIndex =
        layers.indexWhere((l) => l?.id == 'heatmap-layer');

    if (markerLayerIndex > heatmapLayerIndex) {
      print("📍 Moving marker layer below heatmap layer...");
      await style.moveStyleLayer(
          'marker-layer', mp.LayerPosition(below: 'heatmap-layer'));
    }
  }

// This method is used to update the transparent marker layer used to increase the area of the marker (the small marker size of the marker-layer are not usefull for tapping)
  Future<void> updateTransparentMarkerLayer() async {
    if (_mapboxMapController == null) {
      print(
          "🚨 ERROR: MapboxMapController is NULL! Cannot update transparent marker layer.");
      return;
    }
    final style = _mapboxMapController!.style;
    final layers = await style.getStyleLayers();

    // Check if the transparent marker layer already exists
    final hasTransparentLayer =
        layers.any((l) => l?.id == 'transparent-marker-layer');

    // ✅ Ensure the custom image is only added once
    if (!layers.any((l) => l?.id == 'transparent-marker-icon')) {
      await addCustomImage(_mapboxMapController!, 'transparent-marker-icon');
    }

    // Define the transparent marker layer with increased size
    final transparentMarkerLayer = mp.SymbolLayer(
      id: 'transparent-marker-layer',
      sourceId: 'heatmap-source', // Ensure this matches your existing source ID
      iconImage: 'transparent-marker-icon', // Same icon as the visible markers
      iconSize: 0.1, // Increase the size for interaction
      iconOpacity: 0.0,
      iconAllowOverlap: true, // Allow overlap with other markers

      // Make the markers fully transparent
    );

    if (!hasTransparentLayer) {
      // Add the transparent marker layer if it doesn't exist
      await style.addLayer(transparentMarkerLayer);
      print("📍 Added transparent marker layer.");
    } else {
      // Update the transparent marker layer if it already exists
      await style.updateLayer(transparentMarkerLayer);
      print("📍 Updated transparent marker layer.");
    }

    // Ensure the transparent marker layer is above the heatmap but below the visible marker layer
    final transparentLayerIndex =
        layers.indexWhere((l) => l?.id == 'transparent-marker-layer');
    final markerLayerIndex = layers.indexWhere((l) => l?.id == 'marker-layer');

    if (transparentLayerIndex > markerLayerIndex) {
      print("📍 Moving transparent marker layer below visible marker layer...");
      await style.moveStyleLayer(
          'transparent-marker-layer', mp.LayerPosition(below: 'marker-layer'));
    }
  }

  Future<void> clearHeatmapLayer() async {
    if (_mapboxMapController == null) return;

    final style = _mapboxMapController!.style;

    // ✅ Remove heatmap layer & source
    final layers = await style.getStyleLayers();
    if (layers.any((l) => l?.id == "heatmap-layer")) {
      await style.removeStyleLayer("heatmap-layer");
      print("🔥 Removed heatmap layer.");
    }
    if (layers.any((l) => l?.id == "marker-layer")) {
      await style.removeStyleLayer("marker-layer");
      print("📍 Removed marker layer.");
    }

    final sources = await style.getStyleSources();
    if (sources.any((s) => s?.id == "heatmap-source")) {
      await style.removeStyleSource("heatmap-source");
      print("🔥 Removed heatmap source.");
    }

    // ✅ Clear all point annotations
    if (_selectedAnnotationManager != null) {
      await _selectedAnnotationManager!.deleteAll();
      print("🗑 Cleared all selected annotations.");
    }
    if (_pointAnnotationManager != null) {
      await _pointAnnotationManager!.deleteAll();
      print("🗑 Cleared all point annotations.");
    }
  }

// These methods are used to handle map taps and feature selection
  Future<void> onMapTap(
      mp.MapContentGestureContext mapContentGestureContext) async {
    print('map has been tapped');
    final mapboxController =
        ref.read(heatmapProvider.notifier).getMapboxController();
    if (mapboxController == null) return;

    final touchPosition = mapContentGestureContext.touchPosition;

    // Query features at the tapped position
    final features = await mapboxController.queryRenderedFeatures(
      mp.RenderedQueryGeometry.fromScreenCoordinate(touchPosition),
      mp.RenderedQueryOptions(
        layerIds: [
          'transparent-marker-layer'
        ], // Layer ID you want to check for markers
      ),
    );
    final queriedRenderedFeature = features.firstOrNull;
    if (queriedRenderedFeature == null || !mounted) return;
    print('map has been tapped 2');
    _onFeatureTapped(queriedRenderedFeature, mapboxController);
  }

// This method is used to handle feature taps
  void _onFeatureTapped(
      mp.QueriedRenderedFeature queriedRenderedFeature, mapboxController) {
    print('Feature tapped: ${queriedRenderedFeature.queriedFeature.feature}');

    final properties =
        queriedRenderedFeature.queriedFeature.feature["properties"] as Map?;
    final key = properties?['key'] as String?;

    if (key == null) return;

    print("Tapped feature key: $key");

    final fluxDataState = ref.watch(fluxDataListProvider);

    fluxDataState.when(
      data: (fluxDataList) {
        print("FluxData list size: ${fluxDataList.length}");

        // Check if the key from the feature matches any FluxData's dataKey
        final matchingFluxData = fluxDataList.firstWhere(
          (fluxData) {
            return fluxData.dataKey == key;
          },
          // Return null if no match
        );

        ref.read(markerPopupProvider.notifier).addPopup(matchingFluxData);
      },
      loading: () => print("🖱️ Loading FluxData..."),
      error: (error, stackTrace) => print('🛑 Error fetching FluxData: $error'),
    );
  }

// This method is used to add a custom image to the map style basically the marker icon and the transparent marker icon
  Future<void> addCustomImage(mp.MapboxMap mapboxMap, String iconName) async {
    try {
      // Load the image from assets
      final ByteData byteData = await rootBundle.load('assets/black-dot.png');
      final Uint8List imageData = byteData.buffer.asUint8List();

      // Decode the image to get actual width and height
      final codec = await instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final int imageWidth = frame.image.width;
      final int imageHeight = frame.image.height;

      // Add the image to the style
      await mapboxMap.style.addStyleImage(
        iconName, // Unique ID for the image
        1, // Scale factor
        mp.MbxImage(
          width: imageWidth,
          height: imageHeight,
          data: imageData,
        ),
        false, // SDF (set true if using signed distance fields)
        [], // No horizontal stretching
        [], // No vertical stretching
        null, // No specific content region
      );

      print("✅ Custom image 'marker-icon' added to Mapbox style.");
    } catch (e) {
      print("🚨 ERROR adding custom image: $e");
    }
  }
}

// This provider is used to manage the state of the heatmap notifier
final heatmapProvider = StateNotifierProvider<HeatmapNotifier, void>((ref) {
  final notifier = HeatmapNotifier(ref);

  ref.onDispose(() {
    print("🗑 Disposing HeatmapNotifier manually...");
    notifier.disposeNotifier();
  });

  return notifier;
});

/// ✅ **Provider for HeatmapNotifier**
final heatmapLayerProvider = Provider<mp.HeatmapLayer>((ref) {
  final mapState = ref.watch(mapStateProvider);
  //final globalMinMax = ref.watch(minMaxGramProvider);

  // final normalizedRange = normalizeMinMax(
  //   mapState.rangeValues,
  //   globalMinMax.minV,
  //   globalMinMax.maxV,
  // );

  print(
      "🟢 HeatmapLayerProvider updated: radius=${mapState.radius}, opacity=${mapState.opacity}, rangeValues=${mapState.rangeValues}");

  return mp.HeatmapLayer(
    id: "heatmap-layer",
    sourceId: "heatmap-source",
    heatmapWeightExpression: generateDynamicHeatmapWeightExpression(
        mapState.rangeValues.minV, mapState.rangeValues.maxV),
    heatmapColorExpression: [
      "interpolate",
      ["linear"],
      ["heatmap-density"],
      0,
      "rgba(0, 0, 255, 0)",
      0.2,
      "royalblue",
      0.4,
      "cyan",
      0.6,
      "lime",
      0.8,
      "yellow",
      1.0,
      "red"
    ],
    heatmapRadius: mapState.radius,
    heatmapOpacity: mapState.opacity,
  );
});

//Method to generate dynamic heatmap weight expression
List<Object> generateDynamicHeatmapWeightExpression(
    double minWeight, double maxWeight) {
  print("🔍 Generating Weight Expression with: min=$minWeight, max=$maxWeight");

  final expression = [
    "interpolate",
    ["linear"],
    [
      "coalesce",
      ["get", "weight"],
      1.0
    ],
    minWeight, 0.2, // 🔥 Start with **visible low intensity**
    (minWeight + maxWeight) / 2, 5.0, // 🔥 Increase the middle intensity
    maxWeight, 10.0 // 🔥 Make the highest intensity much stronger
  ];

  print("🔥 Final Generated Heatmap Weight Expression: $expression");
  return expression;
}

/// ✅ Converts FluxDataList to GeoJSON format based on selected flux type and filters out null values
String _convertFluxDataToGeoJSON(
    List<FluxData> fluxDataList, String selectedFluxType) {
  final features = fluxDataList.where((fluxData) {
    // Check if the selected flux type has a valid value, if not, skip the data
    switch (selectedFluxType) {
      case "Methane":
        return fluxData.dataCh4fluxGram != null &&
            fluxData.dataLat != null &&
            fluxData.dataLong != null; // Ensure valid lat/lng
      case "VOC":
        return fluxData.dataVocfluxGram != null &&
            fluxData.dataLat != null &&
            fluxData.dataLong != null; // Ensure valid lat/lng
      case "H2O":
        return fluxData.dataH2ofluxGram != null &&
            fluxData.dataLat != null &&
            fluxData.dataLong != null; // Ensure valid lat/ln
      default: // CO₂ by default
        return fluxData.dataCfluxGram != null &&
            fluxData.dataLat != null &&
            fluxData.dataLong != null; // Ensure valid lat/lng
    }
  }).map((fluxData) {
    // Ensure proper parsing of lat and long values, default to 0.0 if invalid
    final lat = double.tryParse(fluxData.dataLat ?? '0.0') ?? 0.0;
    final lng = double.tryParse(fluxData.dataLong ?? '0.0') ?? 0.0;

    // Determine the flux value based on the selected flux type
    double fluxValue = 0.0;
    switch (selectedFluxType) {
      case "Methane":
        fluxValue = double.tryParse(fluxData.dataCh4fluxGram ?? '0.0') ?? 0.0;
        break;
      case "VOC":
        fluxValue = double.tryParse(fluxData.dataVocfluxGram ?? '0.0') ?? 0.0;
        break;
      case "H2O":
        fluxValue = double.tryParse(fluxData.dataH2ofluxGram ?? '0.0') ?? 0.0;
        break;
      default: // CO₂ by default
        fluxValue = double.tryParse(fluxData.dataCfluxGram ?? '0.0') ?? 0.0;
        break;
    }

    // Constructing the GeoJSON feature
    return {
      "type": "Feature",
      "properties": {
        "weight": fluxValue,
        "key": fluxData.dataKey, // Pass the key for identification
      },
      "geometry": {
        "type": "Point",
        "coordinates": [lng, lat]
      }
    };
  }).toList(); // Collect the valid GeoJSON features

  // Return the full GeoJSON structure
  return json.encode({"type": "FeatureCollection", "features": features});
}

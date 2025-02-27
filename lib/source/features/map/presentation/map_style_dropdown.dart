import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/data/data/map_provider.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class MapStyleDropdown extends ConsumerWidget {
  final Function(String) onStyleChanged;

  const MapStyleDropdown({super.key, required this.onStyleChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapStyle = ref.watch(mapStateProvider).mapStyle;

    const mapStyles = [
      {"name": "Mapbox Streets", "url": "mapbox://styles/mapbox/streets-v12"},
      {"name": "Mapbox Outdoors", "url": "mapbox://styles/mapbox/outdoors-v12"},
      {"name": "Mapbox Light", "url": "mapbox://styles/mapbox/light-v11"},
      {"name": "Mapbox Dark", "url": "mapbox://styles/mapbox/dark-v11"},
      {
        "name": "Mapbox Satellite",
        "url": "mapbox://styles/mapbox/satellite-v9"
      },
    ];

    return DropdownButton<String>(
      value: mapStyle,
      onChanged: (String? newValue) {
        if (newValue != null) {
          print('MapStyleDropdown: $newValue');
          ref.read(mapStateProvider.notifier).setMapStyle(newValue);
          onStyleChanged(newValue); // ✅ Notify UI when style changes
        }
      },
      items: mapStyles.map((style) {
        return DropdownMenuItem<String>(
          value: style["url"],
          child: Text(style["name"]!),
        );
      }).toList(),
    );
  }
}

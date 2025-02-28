import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/constants/text_styles.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

class MapStyleDropdown extends ConsumerWidget {
  final Function(String) onStyleChanged;

  const MapStyleDropdown({super.key, required this.onStyleChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapStyle = ref.watch(mapStateProvider).mapStyle;

    const List<Map<String, String>> mapStyles = [
      {"name": "Streets", "url": "mapbox://styles/mapbox/streets-v12"},
      {"name": "Outdoors", "url": "mapbox://styles/mapbox/outdoors-v12"},
      {"name": "Light", "url": "mapbox://styles/mapbox/light-v11"},
      {"name": "Dark", "url": "mapbox://styles/mapbox/dark-v11"},
      {"name": "Satellite", "url": "mapbox://styles/mapbox/satellite-v9"},
    ];

    // ✅ Ensure that `mapStyle` is valid (default to first item if not)
    final validUrls = mapStyles.map((s) => s["url"]!).toList();
    final selectedStyle =
        validUrls.contains(mapStyle) ? mapStyle : validUrls.first;

    // ✅ Detect if the style is dark (so we can change text color)
    final isDarkMode = selectedStyle.contains("dark-v11") ||
        selectedStyle.contains("satellite-v9");

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor:
            Colors.black.withOpacity(0.8), // ✅ Transparent dropdown background
      ),
      child: DropdownButton<String>(
        dropdownColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8), // ✅ Transparent dropdown
        value: selectedStyle, // ✅ Use validated `mapStyle`
        underline: Container(), // ✅ Removes default underline
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        onChanged: (String? newValue) {
          if (newValue != null) {
            print('MapStyleDropdown: $newValue');
            ref.read(mapStateProvider.notifier).setMapStyle(newValue);
            onStyleChanged(newValue); // ✅ Notify UI when style changes
          }
        },
        items: mapStyles.map((style) {
          return DropdownMenuItem<String>(
            value: style["url"]!,
            child: Text(
              style["name"]!,
              style: isDarkMode
                  ? kMapSetting.copyWith(
                      color: Colors.white) // ✅ White text in dark mode
                  : kMapSetting.copyWith(
                      color: Colors.black), // ✅ Black text in light mode
            ),
          );
        }).toList(),
      ),
    );
  }
}

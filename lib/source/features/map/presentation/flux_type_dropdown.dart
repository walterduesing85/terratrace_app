import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/constants/text_styles.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';

class FluxTypeDropdown extends ConsumerWidget {
  const FluxTypeDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFluxType = ref.watch(selectedFluxTypeProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    const List<String> fluxTypes = ["CO2", "Methane", "VOC", "H2O"];

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: isDarkMode
            ? Colors.black.withValues(alpha: .8)
            : Colors.white.withValues(alpha: .8),
      ),
      child: DropdownButton<String>(
        dropdownColor: isDarkMode
            ? Colors.black.withValues(alpha: .8)
            : Colors.white.withValues(alpha: .8),
        value: selectedFluxType,
        underline: Container(), // Remove default underline
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        onChanged: (String? newValue) {
          if (newValue != null) {
            print("🔀 Flux type changed to: $newValue");

            ref.read(selectedFluxTypeProvider.notifier).setFluxType(newValue);
          }
        },
        items: fluxTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(
              type,
              style: isDarkMode
                  ? kMapSetting.copyWith(color: Colors.white)
                  : kMapSetting.copyWith(color: Colors.black),
            ),
          );
        }).toList(),
      ),
    );
  }
}

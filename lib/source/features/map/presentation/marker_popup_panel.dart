import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/map/data/marker_popup_provider.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';

import 'package:terratrace/source/features/data/data/data_management.dart';

class MarkerPopupPanel extends ConsumerWidget {
  const MarkerPopupPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popups = ref.watch(markerPopupProvider); // Watch the popup state
    final selectedFluxType = ref.watch(selectedFluxTypeProvider);

    return Stack(
      children: popups.map((data) {
        return Positioned(
          right: 0,
          top: 80.0 + popups.indexOf(data) * 80.0,
          child: Dismissible(
            key: Key(data.dataDate ?? "unknown"),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              ref.read(markerPopupProvider.notifier).removePopup(data);
            },
            background: Container(color: Colors.transparent),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 250,
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(10)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("📍 ${data.dataSite}",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  SizedBox(height: 5),
                  Text("📅 ${data.dataDate}",
                      style: TextStyle(fontSize: 14, color: Colors.black87)),
                  SizedBox(height: 5),
                  Text(
                      "💨 ${_getFluxType(data, selectedFluxType)} flux: ${_getFluxValue(data, selectedFluxType)} g/m2/d",
                      style: TextStyle(fontSize: 14, color: Colors.black)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("✅ place a marker",
                          style: TextStyle(fontSize: 14, color: Colors.black)),
                      Checkbox(
                        value:
                            ref.watch(selectedFluxDataProvider).contains(data),
                        onChanged: (bool? value) {
                          ref
                              .read(selectedFluxDataProvider.notifier)
                              .toggleFluxData(data);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getFluxValue(FluxData data, String selectedFluxType) {
    switch (selectedFluxType) {
      case "Methane":
        return double.tryParse(data.dataCh4fluxGram ?? '0')
                ?.toStringAsFixed(2) ??
            "0.0";
      case "VOC":
        return double.tryParse(data.dataVocfluxGram ?? '0')
                ?.toStringAsFixed(2) ??
            "0.0";
      case "H2O":
        return double.tryParse(data.dataH2ofluxGram ?? '0')
                ?.toStringAsFixed(2) ??
            "0.0";
      default: // CO₂ by default
        return double.tryParse(data.dataCfluxGram ?? '0')?.toStringAsFixed(2) ??
            "0.0";
    }
  }

  String _getFluxType(FluxData data, String selectedFluxType) {
    switch (selectedFluxType) {
      case "Methane":
        return "Methane";
      case "VOC":
        return "VOC";
      case "H2O":
        return "H2O";
      default: // CO₂ by default
        return "CO2";
    }
  }
}

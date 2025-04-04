import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/map/data/marker_popup_provider.dart';

class MarkerPopupPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popups = ref.watch(markerPopupProvider);

    return Stack(
      children: popups.map((data) {
        return Positioned(
          right: 0,
          top: 80.0 + popups.indexOf(data) * 80.0, // Stack popups downward
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
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("📍 ${data.dataSite}",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("📅 ${data.dataDate}",
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text("💨 Flux: ${data.dataCfluxGram}",
                      style: TextStyle(fontSize: 14)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("✅ Confirm", style: TextStyle(fontSize: 14)),
                      Checkbox(
                        value: false,
                        onChanged: (bool? value) {
                          // TODO: Handle checkbox state change
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
}

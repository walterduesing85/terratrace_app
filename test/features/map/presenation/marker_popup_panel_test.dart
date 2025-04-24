import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/map/data/marker_popup_provider.dart';
import 'package:terratrace/source/features/map/presentation/marker_popup_panel.dart';

void main() {
  testWidgets('MarkerPopupPanel displays correct flux type and value', (tester) async {
    // Arrange: Set up the selected flux type provider and marker popup provider
    final selectedFluxType = "Methane"; // Set the flux type to "Methane"
    
    // Mock flux data for the test
    final fluxData = FluxData(
      dataSite: "Test Site",
      dataDate: "2025-04-23",
      dataCfluxGram: "12.34", // CO2 value
      dataCh4fluxGram: "5.67", // Methane value
      dataVocfluxGram: "8.90", // VOC value
      dataH2ofluxGram: "1.23", // H2O value
    );

    // Act: Wrap the widget with MaterialApp and Scaffold
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override the selectedFluxTypeProvider using a manually created SelectedFluxTypeNotifier
          selectedFluxTypeProvider.overrideWith(
            (ref) => SelectedFluxTypeNotifier(),
          ),

          // Override the markerPopupProvider with a list containing our mock fluxData
          markerPopupProvider.overrideWith(
            (ref) => MarkerPopupNotifier(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MarkerPopupPanel(),
          ),
        ),
      ),
    );

    // Add the mock data to the provider
    final notifier = tester.state<MarkerPopupNotifier>(find.byType(MarkerPopupPanel));
    notifier.addPopup(fluxData);

    // Pump and settle the widget to apply the changes
    await tester.pumpAndSettle();

    // Assert: Verify that the popup displays the correct flux type and value
    expect(find.text("📍 Test Site"), findsOneWidget);
    expect(find.text("📅 2025-04-23"), findsOneWidget);
    expect(find.text("💨 Methane flux: 5.67 g/m2/d"), findsOneWidget); // The correct flux value for Methane
  });
}

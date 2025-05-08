import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';

class MarkerCollectionSelector extends ConsumerWidget {
  const MarkerCollectionSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectName = ref.watch(projectNameProvider); // Fetch project name

    return FutureBuilder<List<String>>(
      future: ref
          .watch(selectedFluxDataProvider.notifier)
          .loadMarkerCollectionNames(projectName), // Fetch collection names
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator()); // Show loading while waiting
        }

        if (snapshot.hasError) {
          return Center(
              child: Text("Error: ${snapshot.error}")); // Error handling
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(); // No data message
        }

        final collectionNames = snapshot.data!; // Get the collection names

        return Row(
          children: [
            // Cloud download IconButton that triggers the dropdown

            // Dropdown Button that will be stacked on top of the icon
            if (collectionNames.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.cloud_download,
                    size: 30.0,
                    color: Colors.white,
                  ),
                  offset: const Offset(0, 40),
                  itemBuilder: (BuildContext context) {
                    return collectionNames.map((collectionName) {
                      return PopupMenuItem<String>(
                        value: collectionName,
                        child: Text(
                          collectionName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList();
                  },
                  onSelected: (newValue) async {
                    if (newValue != null) {
                      // Set the current collection name
                      ref.read(currentMarkerCollectionProvider.notifier).state = newValue;
                      
                      // Check if any data is already selected
                      final currentSelection = ref.read(selectedFluxDataProvider);
                      if (currentSelection.isNotEmpty) {
                        // Ask the user what they want to do with the current selection
                        await _showSelectionDialog(context, newValue, ref);
                      } else {
                        // If no data is selected, load the new data
                        loadFluxDataByKeys(newValue, ref);
                      }
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // Method to load FluxData based on selected keys
  Future<void> loadFluxDataByKeys(String newValue, WidgetRef ref) async {
    final fluxDataListAsync = ref.watch(fluxDataListProvider);
    final projectName = ref.watch(projectNameProvider);

    // Fetch the selectedDataKeys for the specific collection
    final selectedDataKeys = await ref
        .read(selectedFluxDataProvider.notifier)
        .loadSelectedData(projectName, newValue);

    fluxDataListAsync.when(
      data: (fluxDataList) {
        // Filter fluxDataList based on the selected keys
        final selectedFluxData = fluxDataList.where((fluxData) {
          return selectedDataKeys.contains(fluxData.dataKey);
        }).toList();

        ref
            .read(selectedFluxDataProvider.notifier)
            .clear(); // Clear previous selection

        // Pass the filtered FluxData to selectedFluxDataProvider
        ref
            .read(selectedFluxDataProvider.notifier)
            .addFluxData(selectedFluxData);
        print("✅ Flux data loaded and added to selectedFluxDataProvider.");
      },
      loading: () => print("Loading Flux Data..."),
      error: (error, stackTrace) => print("Error loading Flux Data: $error"),
    );
  }

  // Show a dialog asking what to do with the current selection
  Future<void> _showSelectionDialog(
      BuildContext context, String newValue, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Current Selection Exists"),
          content: const Text(
              "Do you want to Add, Delete, or Save the current selection?"),
          actions: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  loadFluxDataByKeys(
                      newValue, ref); // Add new data after confirming
                },
                child: const Text(
                    "Add"), // Add the new selection to the current selection
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(selectedFluxDataProvider.notifier)
                      .clear(); // Clear current selection
                  loadFluxDataByKeys(
                      newValue, ref); // Add new data after clearing
                },
                child: const Text(
                    "Delete"), // Clear current selection and replace it
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showSaveDialog(context, newValue, ref); // Show save dialog
                },
                child: const Text("Save"), // Open the save dialog
              ),
            ),
          ],
        );
      },
    );
  }

  // Show the save dialog for the collection
  Future<void> _showSaveDialog(
      BuildContext context, String newValue, WidgetRef ref) async {
    final TextEditingController collectionNameController =
        TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Save Selection"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize
                  .min, // Makes the column take only as much space as it needs
              children: [
                // Collection name input
                TextField(
                  controller: collectionNameController,
                  decoration: const InputDecoration(
                      labelText: "Collection Name",
                      border:
                          OutlineInputBorder()), // Adding border for clarity
                ),
                const SizedBox(height: 10), // Add space between inputs

                // Note input
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                      labelText: "Note (Optional)",
                      border:
                          OutlineInputBorder()), // Adding border for clarity
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final collectionName = collectionNameController.text;
                final note = noteController.text;
                if (collectionName.isNotEmpty) {
                  // Save the data after collection name is entered
                  ref.read(selectedFluxDataProvider.notifier).saveSelectedData(
                      ref.watch(projectNameProvider), collectionName, note);
                }
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without saving
              },
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }
}

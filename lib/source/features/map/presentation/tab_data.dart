import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/data/presentation/circle_icon_button.dart';
import 'package:terratrace/source/features/data/presentation/data_card_tab.dart';
import 'package:terratrace/source/features/data/presentation/marker_collection_selector.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';

class TabData extends ConsumerWidget {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fluxDataListAsync = ref.watch(fluxDataListProvider);
    final selectedFluxData = ref.watch(selectedFluxDataProvider); //

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(
                    fontSize: 25,
                    color: Colors.white70,
                  ),
                  onChanged: (value) {
                    ref
                        .read(searchValueTabProvider.notifier)
                        .setSearchValue(value);
                  },
                  decoration: kInputTextField.copyWith(
                    suffixIcon: CircleIconButton(
                      onPressed: () {
                        ref
                            .read(searchValueTabProvider.notifier)
                            .setSearchValue('');
                        FocusScope.of(context).unfocus();
                        _controller.clear();
                      },
                    ),
                    hintText: '    Search Site',
                    hintStyle: const TextStyle(
                      fontSize: 22,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              if (selectedFluxData.isEmpty) MarkerCollectionSelector(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  ref.read(sortPreferenceProvider.notifier).state = value;
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'latest',
                    child: Text('Sort by latest'),
                  ),
                  const PopupMenuItem(
                    value: 'highest',
                    child: Text('Sort by highest value'),
                  ),
                ],
                icon: const Icon(Icons.sort, color: Colors.blueGrey, size: 30),
              ),
            ],
          ),
        ),
        // Conditional rendering for Clear Selected Markers button
        if (selectedFluxData
            .isNotEmpty) // Only show when there are selected markers
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(
                      alpha: 0.5), // Semi-transparent grey background
                  border:
                      Border.all(color: Colors.white, width: 1), // White border
                  borderRadius: BorderRadius.circular(
                      8), // Optional: Rounded corners for the border
                ),
                padding:
                    EdgeInsets.all(5), // Optional padding for the container
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Clear Selection Icon
                    IconButton(
                      onPressed: () {
                        ref.read(selectedFluxDataProvider.notifier).clear();
                      },
                      icon: const Icon(
                        Icons.clear, // Icon for clear selection
                        size: 30.0,
                        color: Colors.white, // Color to match button background
                      ),
                      padding: const EdgeInsets.all(
                          8), // Optional padding for the icon
                      iconSize: 32, // Adjust icon size if necessary
                      splashRadius: 24, // For better touch feedback
                    ),
                    SizedBox(width: 10), // Add spacing between the buttons

                    // Save Selection Icon
                    IconButton(
                      onPressed: () {
                        _showSaveSelectionDialog(context, ref);
                        // Add logic for saving selection here
                      },
                      icon: const Icon(
                        Icons.save, // Icon for save selection
                        size: 30.0,
                        color: Colors.white, // Color to match button background
                      ),
                      padding: const EdgeInsets.all(
                          8), // Optional padding for the icon
                      iconSize: 32, // Adjust icon size if necessary
                      splashRadius: 30, // For better touch feedback
                    ),
                    SizedBox(width: 10), // Add spacing between the buttons

                    // Load Selection Icon
                    MarkerCollectionSelector(),
                    
                    // Delete Current Collection Icon
                    if (ref.watch(currentMarkerCollectionProvider) != null)
                      IconButton(
                        onPressed: () async {
                          final currentCollection = ref.read(currentMarkerCollectionProvider);
                          if (currentCollection != null) {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Delete Collection'),
                                  content: Text('Are you sure you want to delete "$currentCollection"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (shouldDelete == true) {
                              try {
                                await ref
                                    .read(selectedFluxDataProvider.notifier)
                                    .deleteMarkerCollection(
                                      ref.read(projectNameProvider),
                                      currentCollection,
                                    );
                                
                                // Clear the current selection and collection name
                                ref.read(selectedFluxDataProvider.notifier).clear();
                                ref.read(currentMarkerCollectionProvider.notifier).state = null;
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Collection "$currentCollection" deleted successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error deleting collection: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.delete,
                          size: 30.0,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(8),
                        iconSize: 32,
                        splashRadius: 24,
                      ),
                  ],
                ),
              )),

        Expanded(
          child: fluxDataListAsync.when(
            data: (fluxDataList) {
              final searchValue =
                  ref.watch(searchValueTabProvider).toLowerCase();
              final sortPreference = ref.watch(sortPreferenceProvider);

              // Step 1: Filtering based on search value
              List<FluxData> filteredList = List<FluxData>.from(fluxDataList);

              filteredList = filteredList.where((fluxData) {
                final siteLower = fluxData.dataSite?.toLowerCase();
                final searchLower = searchValue.toLowerCase();
                return siteLower!.contains(searchLower) || searchLower.isEmpty;
              }).toList();

              // Debugging: Log the filtered list after applying search
              print(
                  'Filtered List (after search): ${filteredList.map((e) => e.dataSite).toList()}');

              // Step 2: Fetching selected flux data and log it
              final selectedFluxData = ref.watch(selectedFluxDataProvider);
              print(
                  'Selected Flux Data: ${selectedFluxData.map((e) => e.dataSite).toList()}');

              // Step 3: Separate selected and non-selected items
              List<FluxData> selectedItems = filteredList.where((fluxData) {
                return selectedFluxData.contains(fluxData);
              }).toList();

              List<FluxData> nonSelectedItems = filteredList.where((fluxData) {
                return !selectedFluxData.contains(fluxData);
              }).toList();

              // Step 4: Sorting non-selected items by the selected sort preference
              if (sortPreference == 'latest') {
                nonSelectedItems.sort((a, b) => b.dataDate!
                    .compareTo(a.dataDate!)); // Sort by date (latest)
              } else if (sortPreference == 'highest') {
                nonSelectedItems.sort((a, b) {
                  double aValue = double.tryParse(a.dataCfluxGram!) ?? 0;
                  double bValue = double.tryParse(b.dataCfluxGram!) ?? 0;
                  return bValue
                      .compareTo(aValue); // Sort by highest value (CO2)
                });
              }

              // Step 5: Combine the selected items (always at the top) and the sorted non-selected items
              final sortedList = selectedItems + nonSelectedItems;

              // Debugging: Log the final sorted list
              print(
                  'Sorted List (after applying selection and sorting): ${sortedList.map((e) => e.dataSite).toList()}');

              return ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: sortedList.length,
                itemBuilder: (context, index) {
                  FluxData fluxData = sortedList[index];
                  return DataCardTab(
                    fluxData: fluxData,
                  );
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  // Method to show the dialog for saving the selection
  void _showSaveSelectionDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController collectionNameController =
        TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Selection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: TextField(
                  controller: collectionNameController,
                  decoration: const InputDecoration(
                    labelText: 'Collection Name',
                    hintText: 'Enter a name for the collection',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Optional Note',
                    hintText: 'Add an optional note',
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final collectionName = collectionNameController.text;
                final note = noteController.text;

                if (collectionName.isNotEmpty) {
                  await ref
                      .read(selectedFluxDataProvider.notifier)
                      .saveSelectedData(
                          ref.read(projectNameProvider), collectionName, note);

                  Navigator.of(context).pop(); // Close the dialog after saving
                } else {
                  // Optionally show an error if the collection name is empty
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/project_manager/data/project_managment.dart';

class MarkerCollectionDelete extends ConsumerWidget {
  const MarkerCollectionDelete({super.key});

  Future<void> _deleteCurrentSelection(BuildContext context, WidgetRef ref) async {
    final currentSelection = ref.read(selectedFluxDataProvider);
    final projectName = ref.watch(projectNameProvider);

    if (currentSelection.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No collection is currently selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if the current selection is saved
    final collectionNames = await ref
        .read(selectedFluxDataProvider.notifier)
        .loadMarkerCollectionNames(projectName);
    
    // Get the current collection name from the selection
    final currentCollectionName = ref.read(selectedFluxDataProvider.notifier).getCurrentCollectionName();
    
    if (currentCollectionName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current selection has not been saved yet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Current Collection'),
          content: Text('Are you sure you want to delete "$currentCollectionName"?'),
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
            .deleteMarkerCollection(projectName, currentCollectionName);
        
        // Clear the current selection after successful deletion
        ref.read(selectedFluxDataProvider.notifier).clear();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Collection "$currentCollectionName" deleted successfully'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectName = ref.watch(projectNameProvider);

    return FutureBuilder<List<String>>(
      future: ref
          .watch(selectedFluxDataProvider.notifier)
          .loadMarkerCollectionNames(projectName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No collections available."));
        }

        final collectionNames = snapshot.data!;

        return Row(
          children: [
            // Button to delete current selection
            IconButton(
              icon: const Icon(
                Icons.delete,
                size: 30.0,
                color: Colors.white,
              ),
              onPressed: () => _deleteCurrentSelection(context, ref),
            ),
            // Existing popup menu for selecting collections to delete
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.delete_outline,
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
                onSelected: (collectionName) async {
                  // Show confirmation dialog before deletion
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Collection'),
                        content: Text('Are you sure you want to delete "$collectionName"?'),
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
                          .deleteMarkerCollection(projectName, collectionName);
                      
                      // Show success message
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Collection "$collectionName" deleted successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      // Show error message
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
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

    
     
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/constants/constants.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/data/presentation/circle_icon_button.dart';
import 'package:terratrace/source/features/data/presentation/data_card_tab.dart';

class TabData extends ConsumerWidget {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fluxDataListAsync = ref.watch(fluxDataListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 20),
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
                      fontSize: 20,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(selectedFluxDataProvider.notifier).clear();
                  },
                  child: const Text('Clear Selected Markers on map'),
                ),
              ),
            ],
          ),
        ),
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
}

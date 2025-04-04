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
                    child: Text('Sort by Latest'),
                  ),
                  const PopupMenuItem(
                    value: 'highest',
                    child: Text('Sort by Highest Value'),
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

              List<FluxData> filteredList = List<FluxData>.from(fluxDataList);

              filteredList = filteredList.where((fluxData) {
                final siteLower = fluxData.dataSite?.toLowerCase();
                final searchLower = searchValue.toLowerCase();
                return siteLower!.contains(searchLower) || searchLower.isEmpty;
              }).toList();

              if (sortPreference == 'latest') {
                filteredList.sort((a, b) => b.dataDate!.compareTo(a.dataDate!));
              } else if (sortPreference == 'highest') {
                filteredList.sort((a, b) {
                  double aValue = double.tryParse(a.dataCfluxGram!) ?? 0;
                  double bValue = double.tryParse(b.dataCfluxGram!) ?? 0;
                  return bValue.compareTo(aValue);
                });
              }

              return ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  FluxData fluxData = filteredList[index];
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

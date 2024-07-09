import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terra_trace/source/features/data/data/data_management.dart';
import 'package:terra_trace/source/features/map/presentation/heat_map_screen.dart';
import 'package:terra_trace/source/features/map/presentation/marker_map_screen.dart';

final mapScreenProvider = Provider.autoDispose<Widget>((ref) {
  final listLength = ref.watch(listLengthProvider);
  return listLength > 10 ? HeatMapScreen(): MarkerMapScreen();
});

class MapScreenSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(mapScreenProvider);
  }
}

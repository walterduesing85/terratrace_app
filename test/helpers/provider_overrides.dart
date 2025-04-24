import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/map/data/heat_map_notifier.dart';
import 'package:terratrace/source/features/data/data/data_management.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';
import '../mocks/mock_heatmap_notifier.dart';

final testOverrides = <Override>[
  // ✅ Mock HeatmapNotifier
  heatmapProvider.overrideWith((ref) => MockHeatmapNotifier(ref)),

  // ✅ Firebase-related overrides
  selectedDataSetProvider.overrideWith((ref) => Stream.value(<String>[])),
  fluxDataListProvider.overrideWith((ref) => Stream.value(<FluxData>[])),

  // Add more if needed (e.g. projectManagementProvider, etc.)
];

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

import '../../../helpers/fake_widget_ref.dart';
import '../../../helpers/provider_overrides.dart';

void main() {
  group('MapStateNotifier', () {
    late ProviderContainer container;
    late FakeWidgetRef fakeRef;

    setUp(() {
      container = ProviderContainer(overrides: testOverrides);
      fakeRef = FakeWidgetRef(container);
      addTearDown(container.dispose);
    });

    test('initial state has correct defaults', () {
      final state = container.read(mapStateProvider);

      expect(state.radius, 10.0);
      expect(state.opacity, 0.75);
      expect(state.rangeValues.minV, 0.0);
      expect(state.rangeValues.maxV, 1.0);
      expect(state.useLogNormalization, false);
    });

    test('setRadius updates the radius', () {
      final notifier = container.read(mapStateProvider.notifier);
      notifier.setRadius(5.5);

      final state = container.read(mapStateProvider);
      expect(state.radius, 5.5);
    });

    test('setOpacity updates the opacity', () {
      final notifier = container.read(mapStateProvider.notifier);
      notifier.setOpacity(0.42);

      final state = container.read(mapStateProvider);
      expect(state.opacity, 0.42);
    });

    test('toggleLogNormalization flips the flag', () async {
      final notifier = container.read(mapStateProvider.notifier);
      final before = container.read(mapStateProvider).useLogNormalization;

      // Pass a fake WidgetRef using container.ref

      await notifier.toggleLogNormalization(fakeRef);

      final after = container.read(mapStateProvider).useLogNormalization;
      expect(after, !before);
    });

    test('updateRangeValues sets the new min/max', () {
      final notifier = container.read(mapStateProvider.notifier);
      final newRange = MinMaxValues(minV: 10.0, maxV: 200.0);

      notifier.updateRangeValues(newRange, fakeRef);

      final state = container.read(mapStateProvider);
      expect(state.rangeValues.minV, 10.0);
      expect(state.rangeValues.maxV, 200.0);
    });

    test('setMapStyle updates the map style URI', () {
      final notifier = container.read(mapStateProvider.notifier);
      notifier.setMapStyle("mapbox://styles/custom-style");

      final state = container.read(mapStateProvider);
      expect(state.mapStyle, "mapbox://styles/custom-style");
    });
  });
}

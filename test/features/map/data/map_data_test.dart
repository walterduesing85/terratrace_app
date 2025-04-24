import 'package:flutter_test/flutter_test.dart';
import 'package:terratrace/source/features/data/domain/flux_data.dart';
import 'package:terratrace/source/features/map/data/map_data.dart';

void main() {
  group('MapData.createIntensity', () {
    test('returns correct normalized values (linear)', () {
      final mapData = MapData();
      final minMax = MinMaxValues(minV: 0.0, maxV: 100.0);

      final fluxDataList = [
        FluxData(dataCfluxGram: '0'),
        FluxData(dataCfluxGram: '50'),
        FluxData(dataCfluxGram: '100'),
      ];

      final result =
          mapData.createIntensity(minMax, fluxDataList, false); // linear

      expect(result, equals([0.0, 0.5, 1.0]));
    });

    test('clamps values to 0–1', () {
      final mapData = MapData();
      final minMax = MinMaxValues(minV: 0.0, maxV: 100.0);

      final fluxDataList = [
        FluxData(dataCfluxGram: '-50'),
        FluxData(dataCfluxGram: '200'),
      ];

      final result =
          mapData.createIntensity(minMax, fluxDataList, false); // linear

      expect(result[0], equals(0.0));
      expect(result[1], equals(1.0));
    });

    test('returns correct normalized values (log)', () {
      final mapData = MapData();
      final minMax = MinMaxValues(minV: 0.0, maxV: 100.0);

      final fluxDataList = [
        FluxData(dataCfluxGram: '0'),
        FluxData(dataCfluxGram: '10'),
        FluxData(dataCfluxGram: '100'),
      ];

      final result =
          mapData.createIntensity(minMax, fluxDataList, true); // log norm

      expect(result.first, equals(0.0));
      expect(result.last, equals(1.0));
      expect(result[1] > 0.0 && result[1] < 1.0, isTrue);
    });
  });
}

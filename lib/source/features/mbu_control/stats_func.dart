import 'dart:math';

double calculateMax(List<double> values) => values.reduce(max);

double calculateMin(List<double> values) => values.reduce(min);

double calculateAverage(List<double> values) =>
    values.fold(0.0, (sum, element) => sum + element) / values.length;

double calculateStdDev(List<double> values) {
  final avg = calculateAverage(values);
  final sumSquaredDiff =
      values.fold(0.0, (sum, element) => sum + pow(element - avg, 2));
  return sqrt(sumSquaredDiff / values.length);
}

/// Helper function to compute the slope using linear regression on a given list of data points.
/// Each point in [data] is expected to have a "sec" (x value) and "value" (y value).
double linearRegressionSlope(List<Map<String, dynamic>> data) {
  final n = data.length;
  double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;

  for (int i = 0; i < n; i++) {
    // double x = (i + 1).toDouble(); // sequential x-values: 1,2,3,...
    double x = double.parse(data[i]['sec']);
    double y = data[i]['value'] as double;
    sumX += x;
    sumY += y;
    sumXY += x * y;
    sumX2 += x * x;
  }

  double denominator = (n * sumX2) - (sumX * sumX);
  return (denominator != 0) ? ((n * sumXY) - (sumX * sumY)) / denominator : 0.0;
}

/// Calculates the slope for the entire interval (from leftBoundaryIndex to rightBoundaryIndex)
/// and the standard deviation of slopes computed from segments of the data within the same interval.
///
/// The segmented slopes are computed by splitting the interval into parts using a step size:
///   step = ((rightBoundaryIndex - leftBoundaryIndex) / 10).floor() - 1 (with a minimum step of 1)
///
/// Returns a Map with:
///   - "wholeIntervalSlope": the slope computed on the entire interval,
///   - "stdDeviation": the standard deviation of the slopes computed for each segment.
Map<String, double> calculateSlopesAndStdDev(
    List<Map<String, dynamic>>? collectedData,
    int leftBoundaryIndex,
    int rightBoundaryIndex) {
  // Validate indices.
  if (leftBoundaryIndex < 0 ||
      rightBoundaryIndex >= collectedData!.length ||
      leftBoundaryIndex >= rightBoundaryIndex) {
    throw ArgumentError('Invalid boundary indices');
  }

  // Extract the full subset from the collected data.
  final subset =
      collectedData.sublist(leftBoundaryIndex, rightBoundaryIndex + 1);

  // Calculate the slope for the whole interval using linear regression.
  final wholeIntervalSlope = linearRegressionSlope(subset);
  // Calculate constant step.
  final totalRange = rightBoundaryIndex - leftBoundaryIndex;
  int step = ((totalRange / 10).floor()) - 1;
  if (step < 1) step = 1;
  List<double> segmentSlopes = [];
  int lastIndex = 0; // working with the subset indices

  // Iterate over the subset, computing the slope for each segment.
  while (lastIndex + step < subset.length) {
    // Create the segment (include both endpoints)
    final segment = subset.sublist(lastIndex, lastIndex + step + 1);
    final segmentSlope = linearRegressionSlope(segment);
    segmentSlopes.add(segmentSlope);

    // Move to the next segment.
    lastIndex += step;
  }

  // Calculate mean of the segment slopes.
  final mean = segmentSlopes.reduce((a, b) => a + b) / segmentSlopes.length;

  // Calculate variance.
  final variance =
      segmentSlopes.map((s) => pow(s - mean, 2)).reduce((a, b) => a + b) /
          segmentSlopes.length;

  // Compute standard deviation.
  final stdDeviation = sqrt(variance);

  return {
    "wholeIntervalSlope": wholeIntervalSlope,
    "stdDeviation": stdDeviation,
  };
}

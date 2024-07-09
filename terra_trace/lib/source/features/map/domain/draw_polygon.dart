import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_heatmap/google_maps_flutter_heatmap.dart';

class DrawPolygon {
  List<LatLng> _polygonPoints = [];
  Set<Polygon> _polygons = {};

  void createPolygon() {
    _polygons.add(Polygon(
      polygonId: PolygonId('polygon'),
      points: _polygonPoints,
      strokeWidth: 2,
      strokeColor: Colors.blue,
      fillColor: Colors.blue.withOpacity(0.3),
    ));
    _polygonPoints.clear(); // Clear points for next polygon
  }

  bool isPointInsidePolygon(LatLng point) {
    int intersectCount = 0;
    List<LatLng> polygonPoints = _polygonPoints;
    int count = polygonPoints.length;

    for (int i = 0; i < count; i++) {
      LatLng p1 = polygonPoints[i];
      LatLng p2 = polygonPoints[(i + 1) % count];

      if (_rayIntersectsSegment(point, p1, p2)) {
        intersectCount++;
      }
    }

    return intersectCount % 2 ==
        1; // Odd number of intersections means point is inside
  }

  bool _rayIntersectsSegment(LatLng point, LatLng p1, LatLng p2) {
    double px = point.longitude;
    double py = point.latitude;
    double p1x = p1.longitude;
    double p1y = p1.latitude;
    double p2x = p2.longitude;
    double p2y = p2.latitude;

    if (p1y == p2y) {
      return false; // Parallel to ray
    }

    if (py < min(p1y, p2y) || py > max(p1y, p2y)) {
      return false; // Above or below segment
    }

    if (px > max(p1x, p2x)) {
      return false; // Right of segment
    }

    double intersectX = p1x + (py - p1y) * (p2x - p1x) / (p2y - p1y);

    return px <= intersectX; // Left side of intersection
  }
}

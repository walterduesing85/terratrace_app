import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ParameterDropdown extends StatelessWidget {
  final String selectedParameter;
  final String selectedParamDevice;
  final Map<String, List<String>> deviceParametersMap;
  final Function(String) onParameterSelected;
  final Map<String, String> formatMap;

  const ParameterDropdown({
    Key? key,
    required this.selectedParameter,
    required this.selectedParamDevice,
    required this.deviceParametersMap,
    required this.onParameterSelected,
    required this.formatMap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DropdownButton<String>(
        isExpanded: true,
        // iconEnabledColor: Color.fromRGBO(58, 66, 86, 1.0),
        // dropdownColor: Color.fromRGBO(58, 66, 86, 1.0),
        value: selectedParameter.isEmpty
            ? null
            : "$selectedParameter ($selectedParamDevice)",
        items: deviceParametersMap.entries
            .expand((entry) => entry.value.map((param) {
                  String displayText =
                      "$param (${entry.key.replaceAll("Terratrace-", "")})";
                  return DropdownMenuItem<String>(
                    value: "$param (${entry.key})",
                    child: Text(
                      displayText,
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }))
            .toList(),
        onChanged: (value) {
          if (value != null) {
            List<String> parts = value.split('(');
            if (parts.length == 2) {
              onParameterSelected(value);
            }
          }
        },
      ),
    );
  }
}

class ChartOverlay extends StatelessWidget {
  final double leftBoundary;
  final double rightBoundary;
  final double chartWidth;
  final double minHandleSeparation;
  final Function(String) onCalculateSlope;
  final String selectedParamDevice;
  final bool showSelection;
  final Function(double) onLeftBoundaryChanged;
  final Function(double) onRightBoundaryChanged;

  const ChartOverlay({
    Key? key,
    required this.leftBoundary,
    required this.rightBoundary,
    required this.chartWidth,
    required this.minHandleSeparation,
    required this.onCalculateSlope,
    required this.selectedParamDevice,
    required this.showSelection,
    required this.onLeftBoundaryChanged,
    required this.onRightBoundaryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showSelection) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) {
        final tappedX = details.localPosition.dx;
        final diffToLeft = (tappedX - leftBoundary).abs();
        final diffToRight = (rightBoundary - tappedX).abs();

        if (diffToLeft < diffToRight) {
          onLeftBoundaryChanged(
              tappedX.clamp(0.0, rightBoundary - minHandleSeparation));
        } else {
          onRightBoundaryChanged(
              tappedX.clamp(leftBoundary + minHandleSeparation, chartWidth));
        }

        onCalculateSlope(selectedParamDevice);
      },
      child: CustomPaint(
        painter: SelectionPainter(leftBoundary, rightBoundary, chartWidth),
      ),
    );
  }
}

class ChartBoundaryHandle extends StatelessWidget {
  final double position;
  final double handleWidth;
  final bool isLeft;
  final double minHandleSeparation;
  final double chartWidth;
  final Function(double) onBoundaryChanged;
  final Function() onPanEnd;
  final bool showHandle;

  const ChartBoundaryHandle({
    Key? key,
    required this.position,
    required this.handleWidth,
    required this.isLeft,
    required this.minHandleSeparation,
    required this.chartWidth,
    required this.onBoundaryChanged,
    required this.onPanEnd,
    required this.showHandle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showHandle) return SizedBox.shrink();

    return Positioned(
      left: position - handleWidth / 2,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onPanUpdate: (details) {
          double newPosition = position + details.delta.dx;
          if (isLeft) {
            newPosition =
                newPosition.clamp(0.0, position + minHandleSeparation);
          } else {
            newPosition =
                newPosition.clamp(position - minHandleSeparation, chartWidth);
          }
          onBoundaryChanged(newPosition);
        },
        onPanEnd: (_) => onPanEnd(),
        child: Container(
          width: handleWidth,
          color: Colors.white.withOpacity(0.0),
        ),
      ),
    );
  }
}

class ChartValueDisplay extends StatelessWidget {
  final String selectedParameter;
  final List<FlSpot> dataPoints;
  final NumberFormat formatter;
  final Map<String, String> unitMap;
  final double avgTemp;
  final double avgPressure;

  const ChartValueDisplay({
    Key? key,
    required this.selectedParameter,
    required this.dataPoints,
    required this.formatter,
    required this.unitMap,
    required this.avgTemp,
    required this.avgPressure,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 30),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        selectedParameter.contains("Temperature")
            ? "$selectedParameter: ${dataPoints.isNotEmpty ? formatter.format(dataPoints.last.y) : "N/A"} ${unitMap[selectedParameter]} \nAverage: ${avgTemp.toStringAsFixed(2)}°C"
            : selectedParameter.contains("Pressure")
                ? "$selectedParameter: ${dataPoints.isNotEmpty ? formatter.format(dataPoints.last.y) : "N/A"} ${unitMap[selectedParameter]} \nAverage: ${avgPressure.toStringAsFixed(2)} hPa"
                : "$selectedParameter: ${dataPoints.isNotEmpty ? formatter.format(dataPoints.last.y) : "N/A"} ${unitMap[selectedParameter]}",
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class ChartStatsDisplay extends StatelessWidget {
  final double slope;
  final double rSquared;
  final double flux;
  final double fluxError;
  final NumberFormat formatter;

  const ChartStatsDisplay({
    Key? key,
    required this.slope,
    required this.rSquared,
    required this.flux,
    required this.fluxError,
    required this.formatter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 30),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "Slope: ${formatter.format(slope)} [ppm/sec] \nR²: ${rSquared.toStringAsFixed(2)} \nFlux: ${formatter.format(flux)} [moles/(m2*day)] \nFlux Error: ${fluxError.toStringAsFixed(1)} %",
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class CustomLineChart extends StatelessWidget {
  final List<FlSpot> dataPoints;
  final List<FlSpot> slopeLinePoints;
  final double minY;
  final double maxY;
  final double stepSize;
  final String selectedParameter;
  final bool showSlopeLine;
  final double chartWidth;

  const CustomLineChart({
    Key? key,
    required this.dataPoints,
    required this.slopeLinePoints,
    required this.minY,
    required this.maxY,
    required this.stepSize,
    required this.selectedParameter,
    required this.showSlopeLine,
    required this.chartWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LineChart(
      key: ValueKey(selectedParameter),
      LineChartData(
        minY: minY - (maxY - minY) * 0.05,
        maxY: maxY + (maxY - minY) * 0.05,
        clipData: FlClipData.all(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map(
                (touchedSpot) {
                  return LineTooltipItem(
                    'x: ${touchedSpot.x}, y: ${touchedSpot.y}',
                    TextStyle(color: Colors.white),
                  );
                },
              ).toList();
            },
          ),
          touchSpotThreshold: 10,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes
                .map(
                  (index) => TouchedSpotIndicatorData(
                    FlLine(color: Colors.transparent),
                    FlDotData(show: true),
                  ),
                )
                .toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints.isNotEmpty ? dataPoints : [FlSpot(0, 0)],
            isCurved: true,
            curveSmoothness: 0.2,
            barWidth: 2,
            color: Color(0xFFAEEA00),
          ),
          if (showSlopeLine)
            LineChartBarData(
              spots:
                  slopeLinePoints.isNotEmpty ? slopeLinePoints : [FlSpot(0, 0)],
              isCurved: false,
              barWidth: 2,
              color: const Color.fromARGB(255, 180, 2, 2),
              dashArray: [5, 5],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  selectedParameter == "CH4"
                      ? value.toStringAsFixed(3)
                      : formatYAxisLabel(value, stepSize),
                  style: TextStyle(fontSize: 12, color: Colors.white),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (dataPoints.length >= 10)
                  ? (dataPoints.length / 5).ceilToDouble()
                  : 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.round().toString(),
                  style: TextStyle(fontSize: 12, color: Colors.white),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

String formatYAxisLabel(double value, double stepSize) {
  if (stepSize >= 10) {
    return value.toStringAsFixed(0);
  } else {
    return value.toStringAsFixed(2);
  }
}

class SelectionPainter extends CustomPainter {
  final double leftBoundary;
  final double rightBoundary;
  final double chartWidth;

  SelectionPainter(this.leftBoundary, this.rightBoundary, this.chartWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    Rect rect = Rect.fromLTRB(leftBoundary, 0, rightBoundary, size.height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

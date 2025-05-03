import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class Details extends StatelessWidget {
  final List<double> selectedColumnData;
  final List<String> columns;
  final String selectedColumn;

  const Details({
    super.key,
    required this.selectedColumnData,
    required this.columns,
    required this.selectedColumn,
  });

  double getMaxValue(List<double> data) {
    return data.isNotEmpty ? data.reduce((a, b) => a > b ? a : b) : 0.0;
  }

  double getMinValue(List<double> data) {
    return data.isNotEmpty ? data.reduce((a, b) => a < b ? a : b) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    double maxY = getMaxValue(selectedColumnData);
    maxY = (maxY + 1).ceilToDouble();
    double minY = getMinValue(selectedColumnData);
    minY = (minY - 2).ceilToDouble();

    return Scaffold(
      appBar: AppBar(
        title: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              '$selectedColumn Graph',
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Data Insights for $selectedColumn',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: selectedColumnData.isNotEmpty
                  ? LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: selectedColumnData
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            barWidth: 4,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: const LinearGradient(
                                colors: [Colors.blueAccent, Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  'Point ${(value + 1).toInt()}',
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          horizontalInterval: 10,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: Colors.blueGrey,
                              strokeWidth: 0.5,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.blueGrey,
                            width: 1,
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                return LineTooltipItem(
                                  'Point ${spot.x.toInt() + 1}\nValue: ${spot.y.toStringAsFixed(2)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: true,
                        ),
                        minY: minY,
                        maxY: maxY,
                        minX: 0,
                        maxX: selectedColumnData.length.toDouble() - 1,
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 60,
                            color: Colors.redAccent,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No data available for the selected column.',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/health_data_service.dart';

class HealthMetricsChart extends StatefulWidget {
  const HealthMetricsChart({super.key});

  @override
  State<HealthMetricsChart> createState() => _HealthMetricsChartState();
}

class _HealthMetricsChartState extends State<HealthMetricsChart> {
  final HealthDataService _service = HealthDataService();
  List<HealthMetricPoint> _historicalMetrics = [];
  bool _loading = true;
  
  // 0 = Weight, 1 = BMI, 2 = WH Ratio
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final metrics = await _service.fetchHistoricalMetrics(days: 30);
    if (mounted) {
      setState(() {
        _historicalMetrics = metrics;
        _historicalMetrics.sort((a, b) => a.date.compareTo(b.date));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_historicalMetrics.isEmpty || _historicalMetrics.length == 1) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Log more health data over time to see your health trend graph.',
          style: TextStyle(color: Color(0xFF7A8FA6)),
        ),
      );
    }

    // Prepare active spots based on selection
    List<FlSpot> spots = [];
    final oldestDate = _historicalMetrics.first.date;
    
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var point in _historicalMetrics) {
      final daysSinceOldest = point.date.difference(oldestDate).inDays.toDouble();
      
      double val = 0;
      if (_selectedIndex == 0) val = point.rawWeight;
      else if (_selectedIndex == 1) val = point.rawBmi;
      else if (_selectedIndex == 2) val = point.rawWhr;

      spots.add(FlSpot(daysSinceOldest, val));
      
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    // Add padding to Min/Max Y
    if (minY == double.infinity) {
      minY = 0; maxY = 10;
    } else if (minY == maxY) {
      minY -= (_selectedIndex == 2) ? 0.1 : 1.0;
      maxY += (_selectedIndex == 2) ? 0.1 : 1.0;
    } else {
      double pad = (maxY - minY) * 0.2;
      minY -= pad;  
      maxY += pad;
      if (_selectedIndex != 2 && minY < 0) minY = 0; 
    }

    Color lineColor;
    Color dotFillColor;
    if (_selectedIndex == 0) {
      lineColor = const Color(0xFFFF5722); // Vibrant Orange
      dotFillColor = const Color(0xFFFFC107); // Yellowish
    } else if (_selectedIndex == 1) {
      lineColor = const Color(0xFFE91E63); // Vibrant Pink
      dotFillColor = const Color(0xFFF48FB1); // Light Pink
    } else {
      lineColor = const Color(0xFF00BCD4); // Cyan
      dotFillColor = const Color(0xFFB2EBF2); // Light Cyan
    }

    return Container(
      height: 380,
      padding: const EdgeInsets.only(right: 24, top: 20, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Custom Tab Toggle
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab(0, 'Weight (kg)', const Color(0xFFFF5722)),
                  const SizedBox(width: 8),
                  _buildTab(1, 'BMI', const Color(0xFFE91E63)),
                  const SizedBox(width: 8),
                  _buildTab(2, 'WH Ratio', const Color(0xFF00BCD4)),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: spots.length > 20 ? 5 : (spots.length > 10 ? 2 : 1), 
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(
                            'Day ${value.toInt()}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45, 
                      getTitlesWidget: (value, meta) {
                        String text = _selectedIndex == 2 
                            ? value.toStringAsFixed(2) 
                            : value.toStringAsFixed(1);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              text,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.black.withOpacity(0.15), // Prominent grey grid
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.black.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.black.withOpacity(0.15), width: 1),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false, // Straight lines
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: dotFillColor,
                          strokeWidth: 2,
                          strokeColor: Colors.black87, // Black borders on dots
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false), // No fill beneath
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, Color tabColor) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tabColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? tabColor : const Color(0xFFD6DDE3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
          ),
        ),
      ),
    );
  }
}

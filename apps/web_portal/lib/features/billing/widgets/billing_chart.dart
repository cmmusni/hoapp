import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/billing_mock.dart';

/// Line chart showing last 12 months of charges vs. paid amounts.
class BillingChart extends StatelessWidget {
  const BillingChart({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2000,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: 2000,
                getTitlesWidget: (value, meta) => Text(
                  '₱${value.toInt()}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= mockMonthly.length)
                    return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(mockMonthly[idx].month,
                        style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 7000,
          lineBarsData: [
            // Charges line
            LineChartBarData(
              spots: List.generate(
                mockMonthly.length,
                (i) => FlSpot(i.toDouble(), mockMonthly[i].charged),
              ),
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: theme.colorScheme.primary,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withOpacity(0.08),
              ),
            ),
            // Paid line
            LineChartBarData(
              spots: List.generate(
                mockMonthly.length,
                (i) => FlSpot(i.toDouble(), mockMonthly[i].paid),
              ),
              isCurved: true,
              color: theme.colorScheme.tertiary,
              barWidth: 3,
              dashArray: [6, 4],
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: theme.colorScheme.tertiary,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final isCharged = s.barIndex == 0;
                return LineTooltipItem(
                  '${isCharged ? "Charged" : "Paid"}: ₱${s.y.toStringAsFixed(0)}',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';

class SpendingTrendChart extends StatefulWidget {
  final DateTime selectedMonth;

  const SpendingTrendChart({super.key, required this.selectedMonth});

  @override
  State<SpendingTrendChart> createState() => _SpendingTrendChartState();
}

class _SpendingTrendChartState extends State<SpendingTrendChart> {
  int _weekOffset = 0;

  @override
  void didUpdateWidget(SpendingTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      setState(() {
        _weekOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, txProvider, child) {
        // Use all transactions to support weeks spanning across months
        final allExpenses = txProvider.transactions
            .where((tx) => tx.type == TransactionType.expense)
            .toList();

        DateTime now = DateTime.now();
        DateTime referenceDate;
        if (widget.selectedMonth.year == now.year &&
            widget.selectedMonth.month == now.month) {
          referenceDate = now;
        } else {
          // For past/future months, use the last day of the month to show the final week
          referenceDate = DateTime(
            widget.selectedMonth.year,
            widget.selectedMonth.month + 1,
            0,
          );
        }

        // Calculate start of week based on reference date and offset
        DateTime baseStartOfWeek = DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
        ).subtract(Duration(days: referenceDate.weekday - 1));

        DateTime startOfWeek = baseStartOfWeek.add(
          Duration(days: _weekOffset * 7),
        );
        DateTime endOfWeek = startOfWeek.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );

        final weekExpenses =
            allExpenses.where((tx) {
              return tx.date.isAfter(
                    startOfWeek.subtract(const Duration(seconds: 1)),
                  ) &&
                  tx.date.isBefore(endOfWeek.add(const Duration(seconds: 1)));
            }).toList();

        final Map<int, double> dailyTotals = {
          1: 0,
          2: 0,
          3: 0,
          4: 0,
          5: 0,
          6: 0,
          7: 0,
        };
        double maxExpense = 0;

        for (var tx in weekExpenses) {
          int weekday = tx.date.weekday;
          dailyTotals[weekday] = (dailyTotals[weekday] ?? 0) + tx.amount;
        }

        for (var total in dailyTotals.values) {
          if (total > maxExpense) {
            maxExpense = total;
          }
        }

        if (maxExpense == 0) maxExpense = 1;

        final List<FlSpot> spots = [];
        for (int i = 1; i <= 7; i++) {
          spots.add(FlSpot(i.toDouble(), dailyTotals[i]!));
        }

        String dateRangeText =
            "${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}";

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.only(
            top: 20,
            right: 20,
            left: 16,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Expense Analysis',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dateRangeText,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildNavButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => setState(() => _weekOffset--),
                      ),
                      const SizedBox(width: 8),
                      _buildNavButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => setState(() => _weekOffset++),
                        enabled: _weekOffset < 0 ||
                            (startOfWeek.add(const Duration(days: 7)).isBefore(now)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (weekExpenses.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No expenses for this week.',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval:
                            (maxExpense / 4) > 0 ? (maxExpense / 4) : 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final style = TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              );
                              String text;
                              switch (value.toInt()) {
                                case 1:
                                  text = 'MON';
                                  break;
                                case 2:
                                  text = 'TUE';
                                  break;
                                case 3:
                                  text = 'WED';
                                  break;
                                case 4:
                                  text = 'THU';
                                  break;
                                case 5:
                                  text = 'FRI';
                                  break;
                                case 6:
                                  text = 'SAT';
                                  break;
                                case 7:
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Text(
                                      'SUN',
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                default:
                                  return Container();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Text(text, style: style),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 1,
                      maxX: 7,
                      minY: 0,
                      maxY: maxExpense * 1.3,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF00E676),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: const Color(0xFF00E676),
                                strokeWidth: 2,
                                strokeColor: Theme.of(context).cardColor,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00E676).withValues(alpha: 0.3),
                                const Color(0xFF00E676).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                    .animate()
                    .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOut,
                    ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled 
              ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)
              : (Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.1) ?? Colors.white10),
          size: 20,
        ),
      ),
    );
  }
}

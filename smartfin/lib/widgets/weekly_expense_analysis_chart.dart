import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';

class ExpenseAnalysisChart extends StatelessWidget {
  final DateTime selectedMonth;

  const ExpenseAnalysisChart({super.key, required this.selectedMonth});

  int _getWeekNumber(DateTime date) {
    if (date.day <= 7) return 1;
    if (date.day <= 14) return 2;
    if (date.day <= 21) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, txProvider, child) {
        final transactions = txProvider.getTransactionsForMonth(selectedMonth);
        final expenses = transactions.where((tx) => tx.type == TransactionType.expense).toList();

        if (expenses.isEmpty) {
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
            padding: const EdgeInsets.all(20),
            child: const Center(
              child: Text(
                'No expenses to analyze this month.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final Map<int, double> weeklyTotals = {1: 0, 2: 0, 3: 0, 4: 0};
        double maxWeeklyExpense = 0;

        for (var tx in expenses) {
          int week = _getWeekNumber(tx.date);
          weeklyTotals[week] = (weeklyTotals[week] ?? 0) + tx.amount;
        }

        for (var total in weeklyTotals.values) {
          if (total > maxWeeklyExpense) {
            maxWeeklyExpense = total;
          }
        }

        if (maxWeeklyExpense == 0) maxWeeklyExpense = 1;

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
          padding: const EdgeInsets.only(top: 20, right: 20, left: 16, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Weekly Expense Analysis',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.more_horiz, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxWeeklyExpense * 1.2,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Week ${value.toInt()}',
                                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12),
                            ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _makeBarGroup(context, 1, weeklyTotals[1]!, maxWeeklyExpense * 1.2),
                      _makeBarGroup(context, 2, weeklyTotals[2]!, maxWeeklyExpense * 1.2),
                      _makeBarGroup(context, 3, weeklyTotals[3]!, maxWeeklyExpense * 1.2),
                      _makeBarGroup(context, 4, weeklyTotals[4]!, maxWeeklyExpense * 1.2),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),
              ),
            ],
          ),
        );
      },
    );
  }

  BarChartGroupData _makeBarGroup(BuildContext context, int x, double y, double maxY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA6), Color(0xFF00E676)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 22,
          borderRadius: BorderRadius.circular(6),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }
}

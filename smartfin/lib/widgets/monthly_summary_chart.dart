import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';
import '../models/transaction.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MonthlySummaryChart extends StatelessWidget {
  final DateTime selectedMonth;

  const MonthlySummaryChart({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

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
            child: Center(
              child: Text(
                'No expenses for this month.',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
              ),
            ),
          );
        }

        // Group expenses by category name
        final Map<String, double> categoryTotals = {};
        for (var tx in expenses) {
          categoryTotals[tx.categoryName] = (categoryTotals[tx.categoryName] ?? 0) + tx.amount;
        }

        // Fresh, beautiful color palette tailored for dark mode
        final List<Color> colors = [
          const Color(0xFF00BFA6), // Primary Teal/Green (Smartfin theme color)
          const Color(0xFF5C6BC0), // Soft Indigo
          const Color(0xFFE57373), // Muted Coral/Red
          const Color(0xFF64B5F6), // Sky Blue
          const Color(0xFFFFB74D), // Warm Orange
          const Color(0xFF81C784), // Soft Green
          const Color(0xFFBA68C8), // Soft Amethyst/Purple
          const Color(0xFFF06292), // Soft Pink
        ];

        int colorIndex = 0;
        final List<PieChartSectionData> sections = [];
        final totalExpense = categoryTotals.values.fold(0.0, (sum, val) => sum + val);

        categoryTotals.forEach((category, amount) {
          sections.add(
            PieChartSectionData(
              color: colors[colorIndex % colors.length],
              value: amount,
              showTitle: false,
              radius: 20,
            ),
          );
          colorIndex++;
        });

        colorIndex = 0;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly Summary',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.more_horiz, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 60,
                              sections: sections,
                              startDegreeOffset: 270, // Start from top
                            ),
                          )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.easeOutBack)
                          .fadeIn(duration: 400.ms),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Total', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 13)),
                              Text(
                                '${currencyProvider.selectedCurrency.symbol}${NumberFormat("#,##0").format(totalExpense)}',
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: categoryTotals.entries.map((entry) {
                          final color = colors[colorIndex++ % colors.length];
                          final percentage = (entry.value / totalExpense) * 100;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 10, 
                                  height: 10, 
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

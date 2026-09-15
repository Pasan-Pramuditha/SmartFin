import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/month_provider.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false).loadInsight();
    });
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<MonthProvider>(
        builder: (context, monthProvider, child) {
          final selectedMonth = monthProvider.selectedMonth;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DateTime>(
                          value: selectedMonth,
                          dropdownColor: Theme.of(context).cardColor,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF00BFA6)),
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                          items: monthProvider.lastSixMonths.map((DateTime month) {
                            return DropdownMenuItem<DateTime>(
                              value: month,
                              child: Text(DateFormat('MMMM yyyy').format(month)),
                            );
                          }).toList(),
                          onChanged: (DateTime? newValue) {
                            if (newValue != null) {
                              monthProvider.setSelectedMonth(newValue);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInsightCard(txProvider, selectedMonth),
                      const SizedBox(height: 30),
                      _buildSectionTitle(
                        _isCurrentMonth(selectedMonth) ? 'Predicted Spending' : 'Spending Summary',
                      ),
                      const SizedBox(height: 16),
                      _buildAIBudgetPredictions(txProvider, selectedMonth),
                      const SizedBox(height: 30),
                      _buildSectionTitle(_isCurrentMonth(selectedMonth) ? 'Savings Prediction' : 'Savings Summary'),
                      const SizedBox(height: 16),
                      _buildSavingsPredictions(txProvider, selectedMonth),
                      const SizedBox(height: 30),
                      _buildSectionTitle('Anomaly Alerts'),
                      const SizedBox(height: 16),
                      _buildAnomalyAlerts(txProvider, selectedMonth),
                      const SizedBox(height: 30),
                      _buildSectionTitle('Smart Savings Tips'),
                      const SizedBox(height: 16),
                      _buildSmartSavingsTips(txProvider, selectedMonth),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isCurrentMonth(DateTime month) {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }

  Widget _buildInsightCard(TransactionProvider provider, DateTime selectedMonth) {
    // If it's a past month, or the backend returned the default fallback text,
    // we generate a highly dynamic local AI text summary for the month.
    String insightText = provider.currentInsight;
    if (!_isCurrentMonth(selectedMonth) || insightText.contains("Start tracking")) {
      insightText = provider.generateSmartAssistantSummary(selectedMonth);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00BFA6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00BFA6)),
              const SizedBox(width: 12),
              Text('Smart Assistant', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insightText,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBudgetPredictions(TransactionProvider provider, DateTime selectedMonth) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
    
    // If viewing a past month, assume the full month has passed
    final isCurrent = _isCurrentMonth(selectedMonth);
    final currentDay = isCurrent ? now.day : daysInMonth;
    
    final currentSpent = provider.totalExpenseForMonth(selectedMonth);
    final dailyAvg = currentDay > 0 ? currentSpent / currentDay : 0;
    
    // For past months, prediction equals actual spent
    final predictedTotal = dailyAvg * daysInMonth;
    
    final formatter = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);
    final title = isCurrent ? 'End of Month Prediction' : 'Total Month Spent';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              Icon(isCurrent ? Icons.trending_up : Icons.fact_check_outlined, color: Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: (currentSpent / (predictedTotal == 0 ? 1 : predictedTotal)).clamp(0.0, 1.0),
            backgroundColor: Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isCurrent ? 'Current Spent' : 'Total Spent', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(formatter.format(currentSpent), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (isCurrent)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Predicted Total', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(formatter.format(predictedTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsPredictions(TransactionProvider provider, DateTime selectedMonth) {
    final isCurrent = _isCurrentMonth(selectedMonth);
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
    final currentDay = isCurrent ? now.day : daysInMonth;
    
    final currentInc = provider.totalIncomeForMonth(selectedMonth);
    final currentExp = provider.totalExpenseForMonth(selectedMonth);
    
    final dailyAvgExp = currentDay > 0 ? currentExp / currentDay : 0;
    final predictedExp = dailyAvgExp * daysInMonth;
    
    final predictedSavings = currentInc - predictedExp;
    final actualSavings = currentInc - currentExp;
    
    final formatter = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);
    final displaySavings = isCurrent ? predictedSavings : actualSavings;
    
    final isPositive = displaySavings >= 0;
    final title = isCurrent ? 'Predicted Savings' : 'Total Savings';
    final subtitle = isCurrent 
        ? 'Based on current spending rate'
        : 'What you saved this month';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isPositive ? Colors.green : Colors.redAccent).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.redAccent).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.savings_rounded : Icons.money_off_rounded, 
              color: isPositive ? Colors.green : Colors.redAccent,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatter.format(displaySavings),
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18, 
                  color: isPositive ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyAlerts(TransactionProvider provider, DateTime selectedMonth) {
    final anomalies = provider.getAnomaliesForMonth(selectedMonth);

    if (anomalies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Good!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(height: 4),
                  Text('No unusual spending patterns detected this month.', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8), height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: anomalies.map((anomaly) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAlertCard(
            icon: anomaly['icon'] as IconData,
            iconColor: anomaly['iconColor'] as Color,
            title: anomaly['title'] as String,
            subtitle: anomaly['subtitle'] as String,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlertCard({required IconData icon, required Color iconColor, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSavingsTips(TransactionProvider provider, DateTime selectedMonth) {
    final localInsight = provider.generateLocalAIInsight(selectedMonth);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: Colors.green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(localInsight, style: TextStyle(height: 1.4, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/month_provider.dart';
import '../providers/currency_provider.dart';
import 'add_budget_screen.dart';
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final Map<int, Color> _categoryIdToColor = {
    1: Colors.tealAccent, 2: Colors.blueAccent, 3: Colors.orangeAccent, 
    4: Colors.greenAccent, 5: Colors.redAccent, 6: Colors.purpleAccent,
    7: Colors.lightBlueAccent, 8: Colors.grey
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Budgets', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).textTheme.bodyLarge?.color
          )
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Consumer4<MonthProvider, BudgetProvider, TransactionProvider, CurrencyProvider>(
        builder: (context, monthProvider, budgetProvider, txProvider, cp, child) {
          final selectedMonth = monthProvider.selectedMonth;
          final budgets = budgetProvider.getBudgetsForMonth(selectedMonth);
          
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
              if (budgets.isEmpty)
                Expanded(child: _buildEmptyState())
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => budgetProvider.loadBudgets(),
                    color: const Color(0xFF00BFA6),
                    backgroundColor: Theme.of(context).cardColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: budgets.length,
                      itemBuilder: (context, index) {
                        final budget = budgets[index];
                        final color = _categoryIdToColor[budget.categoryId] ?? Colors.white;
                        
                        // calculateSpentForBudget already filters by budget.monthYear 
                        // internally comparing tx dates to that monthYear format.
                        final spentAmount = budgetProvider.calculateSpentForBudget(budget, txProvider.transactions);
                        
                        return _buildBudgetProgress(budget.categoryName, spentAmount, budget.monthlyLimit, color, cp.currencyFormat);
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
          );
        },
        backgroundColor: const Color(0xFF00BFA6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_rounded, size: 80, color: Colors.blueGrey[700]),
          const SizedBox(height: 16),
          Text('No budgets set up yet', style: TextStyle(color: Colors.blueGrey[500], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBudgetProgress(String category, double spent, double limit, Color color, NumberFormat currencyFormat) {
    double progress = limit == 0 ? 0 : spent / limit;
    bool isOver = progress > 1;
    bool isNear = progress >= 0.8 && !isOver;
    
    Color progressColor = isOver ? Colors.redAccent : (isNear ? Colors.orangeAccent : color);
    
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${currencyFormat.format(spent)} / ${currencyFormat.format(limit)}',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOver
                          ? 'Overspent: ${currencyFormat.format(spent - limit)}'
                          : 'Remaining: ${currencyFormat.format(limit - spent)}',
                      style: TextStyle(
                        color: isOver ? Colors.redAccent : (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : Colors.green[700]),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress > 1 ? 1 : progress,
                backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 10,
              ),
            ),
            if (isOver) ...[
              const SizedBox(height: 8),
              const Text('⚠️ Budget exceeded!', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ] else if (isNear) ...[
              const SizedBox(height: 8),
              const Text('⚠️ Nearing budget limit!', style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}

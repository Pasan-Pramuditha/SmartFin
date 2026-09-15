import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/currency_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/month_provider.dart';
import '../models/transaction.dart';
import '../providers/theme_provider.dart';
import 'add_transaction_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load transactions from PostgreSQL backend when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).loadTransactions();
      Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);
    final monthProvider = Provider.of<MonthProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final selectedMonth = monthProvider.selectedMonth;

    final currencyFormat = currencyProvider.currencyFormat;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'SmartFin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Consumer3<BudgetProvider, TransactionProvider, ThemeProvider>(
            builder: (context, budgetProvider, txProvider, themeProvider, child) {
              if (!themeProvider.spendingAlerts) return const SizedBox.shrink();
              
              final alertsCount = budgetProvider
                  .getBudgetAlerts(txProvider.transactions, selectedMonth)
                  .length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_active_rounded,
                      size: 30,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (alertsCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          alertsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
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
            const SizedBox(height: 16),
            _buildBalanceCard(txProvider, selectedMonth, currencyFormat),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'See All',
                    style: TextStyle(color: Color(0xFF00BFA6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            txProvider.getTransactionsForMonth(selectedMonth).isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: txProvider.getTransactionsForMonth(selectedMonth).length,
                    itemBuilder: (context, index) {
                      final tx = txProvider.getTransactionsForMonth(selectedMonth)[index];
                      return _buildTransactionItem(
                        tx,
                        currencyFormat,
                        txProvider,
                      );
                    },
                  ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBalanceCard(TransactionProvider provider, DateTime month, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA6), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA6).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            format.format(provider.totalBalanceForMonth(month)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildIncomeExpense(
                  'Income',
                  format.format(provider.totalIncomeForMonth(month)),
                  Icons.arrow_downward,
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIncomeExpense(
                  'Expense',
                  format.format(provider.totalExpenseForMonth(month)),
                  Icons.arrow_upward,
                  Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpense(
    String title,
    String amount,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(
    Transaction tx,
    NumberFormat format,
    TransactionProvider provider,
  ) {
    final isIncome = tx.type == TransactionType.income;
    return Dismissible(
      key: Key(tx.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => provider.deleteTransaction(tx.id!),
      child: Card(
        color: Theme.of(context).cardColor,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddTransactionScreen(transactionToEdit: tx),
              ),
            );
          },
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isIncome ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome
                    ? Icons.account_balance_wallet_rounded
                    : Icons.shopping_bag_rounded,
                color: isIncome ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(
              tx.description,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            subtitle: Text(
              tx.categoryName,
              style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
            ),
            trailing: Text(
              (isIncome ? '+ ' : '- ') + format.format(tx.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncome ? (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : Colors.green[700]) : Colors.redAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: Colors.blueGrey[700],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(color: Colors.blueGrey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "+" to add your first expense!',
            style: TextStyle(color: Colors.blueGrey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  final ApiService _apiService = ApiService();

  List<Transaction> get transactions => _transactions;

  List<Transaction> getTransactionsForMonth(DateTime month) {
    return _transactions.where((tx) => 
      tx.date.year == month.year && tx.date.month == month.month
    ).toList();
  }

  double totalBalanceForMonth(DateTime month) {
    double total = 0;
    for (var tx in getTransactionsForMonth(month)) {
      if (tx.type == TransactionType.income) {
        total += tx.amount;
      } else {
        total -= tx.amount;
      }
    }
    return total;
  }

  double totalIncomeForMonth(DateTime month) {
    return getTransactionsForMonth(month)
        .where((tx) => tx.type == TransactionType.income)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  double totalExpenseForMonth(DateTime month) {
    return getTransactionsForMonth(month)
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  Future<void> loadTransactions() async {
    try {
      final fetchedTransactions = await _apiService.fetchUserTransactions();
      _transactions = fetchedTransactions;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load backend DB transactions: $e");
    }
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      final createdTx = await _apiService.createTransaction(transaction);
      if (createdTx != null) {
        // createdTx comes from DB without UI fields (categoryName, type).
        // Let's create a full transaction combining backend ID with local UI fields.
        final completeTx = Transaction(
          id: createdTx.id,
          userId: createdTx.userId,
          categoryId: createdTx.categoryId,
          amount: createdTx.amount,
          description: createdTx.description,
          date: createdTx.date,
          paymentMethod: createdTx.paymentMethod,
          notes: createdTx.notes,
          receiptImageUrl: createdTx.receiptImageUrl,
          // Inherit the UI fields we had when creating it
          categoryName: transaction.categoryName,
          type: transaction.type,
        );

        _transactions.add(completeTx);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to save transaction to backend: $e");
    }
  }

  Future<void> updateTransaction(int id, Transaction updatedTx) async {
    try {
      final updatedResponse = await _apiService.updateTransaction(id, updatedTx);
      if (updatedResponse != null) {
        final index = _transactions.indexWhere((tx) => tx.id == id);
        if (index != -1) {
          final completeTx = Transaction(
            id: updatedResponse.id,
            userId: updatedResponse.userId,
            categoryId: updatedResponse.categoryId,
            amount: updatedResponse.amount,
            description: updatedResponse.description,
            date: updatedResponse.date,
            paymentMethod: updatedResponse.paymentMethod,
            notes: updatedResponse.notes,
            receiptImageUrl: updatedResponse.receiptImageUrl,
            // Inherit the UI context we had when updating
            categoryName: updatedTx.categoryName,
            type: updatedTx.type,
          );

          _transactions[index] = completeTx;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Failed to update transaction to backend: $e");
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      final success = await _apiService.deleteTransaction(id);
      if (success) {
        _transactions.removeWhere((tx) => tx.id == id);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to delete backend transaction: $e");
    }
  }

  String _currentInsight = "Analyzing your spending...";
  String get currentInsight => _currentInsight;

  Future<void> loadInsight() async {
    try {
      final fetchedInsight = await _apiService.fetchUserInsights();
      _currentInsight = fetchedInsight;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load backend DB insight: $e");
    }
  }

  // Fallback / local insight generation logic (Optional if backend lacks data)
  String generateLocalAIInsight(DateTime month) {
    final monthTxs = getTransactionsForMonth(month);
    if (monthTxs.isEmpty) return "No data for this month. Start tracking to get insights!";
    
    final totalExp = totalExpenseForMonth(month);
    final totalInc = totalIncomeForMonth(month);
    double expenseRatio = totalExp / (totalInc > 0 ? totalInc : 1);
    
    // Find highest spending category
    final expTxs = monthTxs.where((tx) => tx.type == TransactionType.expense).toList();
    if (expTxs.isNotEmpty) {
      final categoryMap = <String, double>{};
      for (var tx in expTxs) {
        categoryMap[tx.categoryName] = (categoryMap[tx.categoryName] ?? 0) + tx.amount;
      }
      String highestCat = categoryMap.keys.first;
      double highestAmt = categoryMap[highestCat]!;
      for (var entry in categoryMap.entries) {
        if (entry.value > highestAmt) {
          highestAmt = entry.value;
          highestCat = entry.key;
        }
      }
      
      if (expenseRatio > 0.8 && totalInc > 0) {
        return "⚠️ Warning: You've spent over ${(expenseRatio*100).toStringAsFixed(0)}% of your income. A big portion (Rs. ${highestAmt.toStringAsFixed(0)}) went to $highestCat. Try to cut back there.";
      } else if (expenseRatio > 0.0 && totalInc == 0) {
        return "💡 You have Rs. ${totalExp.toStringAsFixed(0)} in expenses but no recorded income. Mostly spending on $highestCat. Keep an eye on your budget.";
      } else if (expenseRatio < 0.4 && totalInc > 0) {
        return "✅ Great job! Your savings rate is excellent. Your main expense was $highestCat.";
      } else {
         return "📊 Your spending is balanced. Your biggest expense was $highestCat (Rs. ${highestAmt.toStringAsFixed(0)}). Setting a specific budget for it could save more.";
      }
    }
    
    if (totalInc > 0) {
      return "You have income but no expenses recorded. Great time to invest your savings!";
    }

    return "Keep adding your daily transactions to unlock smart financial advice.";
  }

  List<Map<String, dynamic>> getAnomaliesForMonth(DateTime month) {
    final monthTxs = getTransactionsForMonth(month);
    List<Map<String, dynamic>> anomalies = [];
    if (monthTxs.isEmpty) return anomalies;

    final totalExp = totalExpenseForMonth(month);
    final expTxs = monthTxs.where((tx) => tx.type == TransactionType.expense).toList();

    // 1. Check for single large transactions (> 40% of total expenses)
    if (totalExp > 0) {
      for (var tx in expTxs) {
        if (tx.amount > (totalExp * 0.4) && expTxs.length > 2) {
          anomalies.add({
            'icon': Icons.warning_amber_rounded,
            'iconColor': Colors.orangeAccent,
            'title': 'Unusually Large Expense',
            'subtitle': 'You spent Rs. ${tx.amount.toStringAsFixed(0)} on ${tx.categoryName} which is a massive portion of your monthly expenses.',
          });
        }
      }
    }

    // 2. Check for possible duplicates (same amount, same category on the same day or consecutive days)
    for (int i = 0; i < expTxs.length; i++) {
      for (int j = i + 1; j < expTxs.length; j++) {
        final tx1 = expTxs[i];
        final tx2 = expTxs[j];
        if (tx1.amount == tx2.amount && tx1.categoryName == tx2.categoryName) {
           final diff = tx1.date.difference(tx2.date).inDays.abs();
           if (diff <= 2) {
             anomalies.add({
               'icon': Icons.copy_all_rounded,
               'iconColor': Colors.redAccent,
               'title': 'Possible Duplicate',
               'subtitle': 'Two identical transactions of Rs. ${tx1.amount.toStringAsFixed(0)} for "${tx1.categoryName}" detected within $diff days.',
             });
           }
        }
      }
    }

    // Keep unique anomalies by title + subtitle to prevent spamming
    final uniqueAnomalies = <String, Map<String, dynamic>>{};
    for (var anomaly in anomalies) {
      final key = "${anomaly['title']}-${anomaly['subtitle']}";
      uniqueAnomalies[key] = anomaly;
    }

    return uniqueAnomalies.values.take(3).toList();
  }

  // Dynamic Smart Assistant Summary for specific months
  String generateSmartAssistantSummary(DateTime month) {
    final monthTxs = getTransactionsForMonth(month);
    if (monthTxs.isEmpty) {
      return "You haven't tracked any transactions for this month yet. Start tracking to see your summary!";
    }

    final totalExp = totalExpenseForMonth(month);
    final totalInc = totalIncomeForMonth(month);

    if (totalInc > 0) {
      if (totalExp > totalInc) {
        final overspent = totalExp - totalInc;
        return "Watch out! You exceeded your income by Rs. ${overspent.toStringAsFixed(0)} this month. Let's try to reduce unnecessary expenses next month.";
      } else {
        final saved = totalInc - totalExp;
        return "Fantastic! You kept your expenses under control and saved Rs. ${saved.toStringAsFixed(0)} this month. Keep up the great financial habits!";
      }
    } else {
      if (totalExp > 0) {
        return "You have recorded Rs. ${totalExp.toStringAsFixed(0)} in expenses this month, but no income has been tracked yet.";
      } else {
        return "You haven't recorded any expenses or income for this month.";
      }
    }
  }
}

import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class BudgetProvider with ChangeNotifier {
  List<Budget> _budgets = [];
  Map<int, double> _predictedBudgets = {};
  final ApiService _apiService = ApiService();

  List<Budget> get budgets => _budgets;
  Map<int, double> get predictedBudgets => _predictedBudgets;

  List<Budget> getBudgetsForMonth(DateTime month) {
    final monthYearStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    return _budgets.where((b) => b.monthYear == monthYearStr).toList();
  }

  Future<void> loadBudgets() async {
    try {
      // Fetch categories to map the names correctly
      final categories = await _apiService.fetchCategories();
      final categoryMap = {for (var c in categories) c.id: c.name};

      final response = await _apiService.fetchUserBudgets();
      _budgets = response.map((data) {
        final catId = data['category_id'] as int;
        return Budget.fromJson(data, cName: categoryMap[catId] ?? 'Unknown');
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load budgets: $e");
    }
  }

  Future<void> loadPredictedBudgets() async {
    try {
      _predictedBudgets = await _apiService.predictBudgets();
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load predicted budgets: $e");
    }
  }

  Future<void> addBudget(Budget budget) async {
    try {
      final createdBudget = await _apiService.createBudget(budget);
      if (createdBudget != null) {
        final categories = await _apiService.fetchCategories();
        final categoryMap = {for (var c in categories) c.id: c.name};
        final String cName = categoryMap[createdBudget.categoryId] ?? 'Unknown';
        
        final completeBudget = Budget(
          id: createdBudget.id,
          userId: createdBudget.userId,
          categoryId: createdBudget.categoryId,
          monthlyLimit: createdBudget.monthlyLimit,
          monthYear: createdBudget.monthYear,
          categoryName: cName,
        );
        _budgets.add(completeBudget);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to save budget: $e");
    }
  }

  Future<void> updateBudget(int id, Budget budget) async {
    try {
      final updatedBudget = await _apiService.updateBudget(id, budget);
      if (updatedBudget != null) {
        final index = _budgets.indexWhere((b) => b.id == id);
        if (index != -1) {
          final categories = await _apiService.fetchCategories();
          final categoryMap = {for (var c in categories) c.id: c.name};
          final String cName = categoryMap[updatedBudget.categoryId] ?? 'Unknown';

          final completeBudget = Budget(
            id: updatedBudget.id,
            userId: updatedBudget.userId,
            categoryId: updatedBudget.categoryId,
            monthlyLimit: updatedBudget.monthlyLimit,
            monthYear: updatedBudget.monthYear,
            categoryName: cName,
          );
          _budgets[index] = completeBudget;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Failed to update budget: $e");
    }
  }

  // Calculate spent amount based on transaction list for current month
  double calculateSpentForBudget(Budget budget, List<Transaction> transactions) {
    // Only count expenses matching the category and current month
    // Format required for monthYear comparison: 'YYYY-MM'
    
    return transactions.where((tx) {
      if (tx.type != TransactionType.expense) return false;
      if (tx.categoryName.toLowerCase() != budget.categoryName.toLowerCase()) return false;
      
      // Check date matches budget month using YYYY-MM
      final txMonthYear = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
      return txMonthYear == budget.monthYear;
    }).fold(0.0, (sum, tx) => sum + tx.amount);
  }

  // Get alerts for any budgets exceeding 80% or 100%
  List<String> getBudgetAlerts(List<Transaction> transactions, DateTime selectedMonth) {
    List<String> alerts = [];
    
    for (var budget in getBudgetsForMonth(selectedMonth)) {
      double spent = calculateSpentForBudget(budget, transactions);
      if (budget.monthlyLimit > 0) {
        double ratio = spent / budget.monthlyLimit;
        if (ratio >= 1.0) {
          alerts.add("⚠️ You've exceeded your ${budget.categoryName} budget!");
        } else if (ratio >= 0.8) {
          alerts.add("You've used ${(ratio * 100).toInt()}% of your ${budget.categoryName} budget.");
        }
      }
    }
    
    return alerts;
  }
}

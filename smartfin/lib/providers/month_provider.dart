import 'package:flutter/material.dart';

class MonthProvider with ChangeNotifier {
  late DateTime _selectedMonth;

  MonthProvider() {
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  DateTime get selectedMonth => _selectedMonth;

  void setSelectedMonth(DateTime month) {
    if (_selectedMonth.year != month.year || _selectedMonth.month != month.month) {
      _selectedMonth = DateTime(month.year, month.month);
      notifyListeners();
    }
  }

  List<DateTime> get lastSixMonths {
    final now = DateTime.now();
    final List<DateTime> months = [];
    for (int i = 0; i < 6; i++) {
      // Handle year wrap-around by using DateTime subtraction
      int targetMonth = now.month - i;
      int targetYear = now.year;
      if (targetMonth <= 0) {
        targetMonth += 12;
        targetYear -= 1;
      }
      months.add(DateTime(targetYear, targetMonth));
    }
    return months;
  }
}

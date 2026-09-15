import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/month_provider.dart';
import '../providers/currency_provider.dart';
import '../models/budget.dart';
import '../models/category.dart';
import 'package:intl/intl.dart';

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
      Provider.of<BudgetProvider>(context, listen: false).loadPredictedBudgets();
    });
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _saveBudget() {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      final limit = double.tryParse(_limitController.text) ?? 0;
      if (limit > 0) {
        final monthProvider = Provider.of<MonthProvider>(context, listen: false);
        final selectedMonth = monthProvider.selectedMonth;
        final monthYear = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}";
        
        final budget = Budget(
          categoryId: _selectedCategory!.id!,
          monthlyLimit: limit,
          monthYear: monthYear,
        );
        
        Provider.of<BudgetProvider>(context, listen: false).addBudget(budget);
        Navigator.pop(context);
      }
    } else if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('New Category', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.2) ?? Colors.blueGrey),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00BFA6)),
                    ),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Cannot be empty' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA6)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newCategory = Category(
                    name: nameController.text.trim(),
                    categoryType: 'expense',
                    iconName: 'default',
                  );
                  Navigator.pop(ctx);
                  final createdCategory = await Provider.of<CategoryProvider>(context, listen: false).addCategory(newCategory);
                  
                  if (createdCategory != null) {
                    setState(() {
                      _selectedCategory = createdCategory;
                    });
                  } else {
                    setState(() {});
                  }
                }
              },
              child: const Text('Add', style: TextStyle(color: Color(0xFF0A192F))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w500));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CategoryProvider, CurrencyProvider>(
      builder: (context, categoryProvider, currencyProvider, child) {
        final symbol = currencyProvider.selectedCurrency.symbol;
        final expenseCategories = categoryProvider.categories
            .where((c) => c.categoryType.toLowerCase() == 'expense')
            .toList();

        // Removed auto-select so category always shows the hint first

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Add Budget'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge?.color),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Category'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(left: 12, right: 16),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Icon(Icons.category, color: Colors.blueGrey[300]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Category>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    dropdownColor: Theme.of(context).cardColor,
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                                    hint: Text(
                                      expenseCategories.isEmpty ? 'No Categories added' : 'Select or add your category',
                                      style: TextStyle(color: Colors.blueGrey[400]),
                                    ),
                                    items: expenseCategories.map((cat) {
                                      return DropdownMenuItem<Category>(
                                        value: cat,
                                        child: Text(cat.name),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCategory = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Color(0xFF00BFA6)),
                          onPressed: () => _showAddCategoryDialog(context),
                          tooltip: 'Add Category',
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 25),
              _buildLabel('Monthly Limit ($symbol)'),
              Consumer<BudgetProvider>(
                builder: (context, budgetProvider, child) {
                  if (_selectedCategory == null) return const SizedBox(height: 10);
                  
                  final predicted = budgetProvider.predictedBudgets[_selectedCategory!.id];
                  if (predicted == null || predicted <= 0) return const SizedBox(height: 10);
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text('AI Suggestion: $symbol ${NumberFormat('#,##0.00').format(predicted)}', style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _limitController.text = predicted.toStringAsFixed(2);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Apply', style: TextStyle(color: Color(0xFF00BFA6), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              TextFormField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.blueGrey[600]),
                  prefixIcon: Icon(Icons.payments_rounded, color: Colors.blueGrey[300]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter a value';
                  if (double.tryParse(val) == null) return 'Please enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA6),
                    foregroundColor: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF0A192F) 
                        : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _saveBudget,
                  child: const Text('Save Budget'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

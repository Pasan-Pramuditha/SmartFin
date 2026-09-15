import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/month_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'dart:async';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transactionToEdit;

  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  
  Category? _selectedCategory;
  TransactionType _selectedType = TransactionType.expense;
  
  final ApiService _apiService = ApiService();
  Timer? _debounce;
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.transactionToEdit != null) {
      _titleController.text = widget.transactionToEdit!.description;
      _amountController.text = widget.transactionToEdit!.amount.toString();
      _categoryController.text = widget.transactionToEdit!.categoryName;
      _selectedType = widget.transactionToEdit!.type;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catProvider = Provider.of<CategoryProvider>(context, listen: false);
      catProvider.loadCategories().then((_) {
        if (!mounted) return;
        if (widget.transactionToEdit != null) {
          setState(() {
            try {
              _selectedCategory = catProvider.categories.firstWhere(
                (c) => c.id == widget.transactionToEdit!.categoryId
              );
            } catch (e) {
              _selectedCategory = null; // In case the category was deleted
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _onTitleChanged(String title) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (title.trim().isEmpty) {
       setState(() { _isSuggesting = false; });
       return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      setState(() { _isSuggesting = true; });
      try {
        final categoryType = _selectedType == TransactionType.expense ? 'expense' : 'income';
        final suggestionData = await _apiService.suggestCategory(title.trim(), categoryType);
        
        if (suggestionData != null && mounted) {
          final suggestedId = suggestionData['suggested_category_id'] as int?;
          final message = suggestionData['message'] as String?;
          
          if (suggestedId != null) {
            final catProvider = Provider.of<CategoryProvider>(context, listen: false);
            try {
              final suggestedCat = catProvider.categories.firstWhere(
                (c) => c.id == suggestedId && c.categoryType.toLowerCase() == categoryType
              );
              
              // Only auto-select if user hasn't manually selected something else recently
              setState(() {
                _selectedCategory = suggestedCat;
                _categoryController.text = suggestedCat.name;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        "AI Suggested: ${suggestedCat.name}",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF00BFA6),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  duration: const Duration(seconds: 2),
                ),
              );
            } catch (_) {
              if (suggestionData['suggested_category_name'] != null) {
                 _showSuggestionDialog(suggestionData['suggested_category_name'] as String);
              }
            }
          } else if (suggestionData['suggested_category_name'] != null) {
             _showSuggestionDialog(suggestionData['suggested_category_name'] as String);
          } else if (message != null && message != "No category suggested.") {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('💡 $message'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.blueAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } finally {
        if (mounted) setState(() { _isSuggesting = false; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final isExpense = _selectedType == TransactionType.expense;
    
    // Filter categories by type
    final availableCategories = categoryProvider.categories
        .where((c) => c.categoryType.toLowerCase() == (isExpense ? 'expense' : 'income'))
        .toList();

    // Ensure selected category is valid for current type
    if (_selectedCategory != null && 
        _selectedCategory!.categoryType.toLowerCase() != (isExpense ? 'expense' : 'income')) {
      _selectedCategory = null;
    }

    // Removed auto-select so category always shows the hint first

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.transactionToEdit == null ? 'Add Transaction' : 'Edit Transaction'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: widget.transactionToEdit != null ? [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context),
          )
        ] : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 30),
              _buildLabel('Title'),
              const SizedBox(height: 10),
              _buildTextField(_titleController, 'e.g. Lunch', Icons.title_rounded, onChanged: _onTitleChanged),
              const SizedBox(height: 25),
              _buildLabel('Amount'),
              const SizedBox(height: 10),
              _buildTextField(_amountController, '0.00', Icons.payments_rounded, isNumber: true),
              const SizedBox(height: 25),
              _buildLabel('Category'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryAutocomplete(availableCategories),
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
                  onPressed: () => _saveTransaction(context),
                  child: Text(widget.transactionToEdit == null ? 'Save Transaction' : 'Update Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _typeButton('Expense', TransactionType.expense, Colors.redAccent),
        const SizedBox(width: 16),
        _typeButton('Income', TransactionType.income, Colors.greenAccent),
      ],
    );
  }

  Widget _typeButton(String label, TransactionType type, Color activeColor) {
    bool isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.2) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? activeColor : Colors.transparent, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.blueGrey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w500));
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).cardColor,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.blueGrey[600]),
        prefixIcon: Icon(icon, color: Colors.blueGrey[300]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Please enter a value' : null,
    );
  }

  void _showSuggestionDialog(String suggestedName) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: const Color(0xFF00BFA6).withValues(alpha: 0.2), width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Row(
          children: [
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: const Color(0xFF00BFA6).withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Icon(Icons.auto_awesome_rounded, color: const Color(0xFF00BFA6), size: 24),
             ),
             const SizedBox(width: 14),
             Text('Smart Suggestion', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 15, height: 1.5),
                children: [
                  const TextSpan(text: "Our AI thinks this transaction belongs in "),
                  TextSpan(
                    text: "'$suggestedName'",
                    style: const TextStyle(color: Color(0xFF00BFA6), fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ". Would you like to use this category?"),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not Now', style: TextStyle(color: Colors.blueGrey[400], fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA6),
              foregroundColor: const Color(0xFF0A192F),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              setState(() {
                _categoryController.text = suggestedName;
                _selectedCategory = null;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        "Added '$suggestedName' as category",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF00BFA6),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Yes, Apply', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAutocomplete(List<Category> availableCategories) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: RawAutocomplete<Category>(
        textEditingController: _categoryController,
        focusNode: FocusNode(),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return availableCategories;
          }
          return availableCategories.where((Category option) {
            return option.name
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase());
          });
        },
        displayStringForOption: (Category option) => option.name,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              hintText: _isSuggesting ? 'Suggesting...' : 'Select or type category',
              hintStyle: TextStyle(color: _isSuggesting ? const Color(0xFF00BFA6) : Colors.blueGrey[400]),
              prefixIcon: Icon(Icons.category_rounded, color: Colors.blueGrey[300], size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: MediaQuery.of(context).size.width - 100, // Adjust width
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Category option = options.elementAt(index);
                    return ListTile(
                      title: Text(option.name, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      onTap: () {
                        onSelected(option);
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
        onSelected: (Category selection) {
          setState(() {
            _selectedCategory = selection;
          });
        },
      ),
    );
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
                    categoryType: _selectedType == TransactionType.expense ? 'expense' : 'income',
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

  Future<void> _saveTransaction(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final categoryName = _categoryController.text.trim();
      if (categoryName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or type a category first')),
        );
        return;
      }

      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      Category? catToUse = _selectedCategory;

      // If typed something but didn't select or selection doesn't match typed text
      if (catToUse == null || catToUse.name != categoryName) {
        // Try to find by name in existing categories
        try {
          catToUse = categoryProvider.categories.firstWhere(
            (c) => c.name.toLowerCase() == categoryName.toLowerCase() && 
                   c.categoryType.toLowerCase() == (_selectedType == TransactionType.expense ? 'expense' : 'income')
          );
        } catch (_) {
          // If not found, create it!
          catToUse = await categoryProvider.addCategory(Category(
            name: categoryName,
            categoryType: _selectedType == TransactionType.expense ? 'expense' : 'income',
            iconName: 'default',
          ));
        }
      }

      if (catToUse == null) {
        if (!context.mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error creating/selecting category')),
        );
        return;
      }

      if (!context.mounted) return;
      final monthProvider = Provider.of<MonthProvider>(context, listen: false);
      final selectedMonth = monthProvider.selectedMonth;

      final tx = Transaction(
        id: widget.transactionToEdit?.id,
        userId: widget.transactionToEdit?.userId,
        description: _titleController.text,
        amount: double.parse(_amountController.text),
        date: widget.transactionToEdit?.date ??
            (selectedMonth.year == DateTime.now().year && selectedMonth.month == DateTime.now().month
                ? DateTime.now()
                : selectedMonth),
        categoryId: catToUse.id ?? 1,
        categoryName: catToUse.name,
        type: _selectedType, // This enforces what user selected Expense/Income
      );

      final provider = Provider.of<TransactionProvider>(context, listen: false);
      if (widget.transactionToEdit == null) {
        provider.addTransaction(tx);
      } else {
        provider.updateTransaction(tx.id!, tx);
      }
      
      if (_selectedType == TransactionType.expense) {
        final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
        try {
          final budget = budgetProvider.getBudgetsForMonth(selectedMonth).firstWhere(
            (b) => b.categoryId == catToUse!.id,
          );
          
          double currentSpent = budgetProvider.calculateSpentForBudget(budget, provider.transactions);
          double amountDiff = widget.transactionToEdit == null ? tx.amount : (tx.amount - widget.transactionToEdit!.amount);
          
          // Note: provider.transactions might already be updated depending on async logic, 
          // but if it's not, we just estimate the new spend.
          if ((currentSpent + amountDiff) > budget.monthlyLimit && budget.monthlyLimit > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Alert: You have exceeded your ${budget.categoryName} budget!'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (_) {
          // No budget exists for this category, skipping alert
        }
      }
      
      Navigator.pop(context);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Transaction', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text('Are you sure you want to delete this transaction?', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Provider.of<TransactionProvider>(context, listen: false)
                  .deleteTransaction(widget.transactionToEdit!.id!);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  final ApiService _apiService = ApiService();

  List<Category> get categories => _categories;

  Future<void> loadCategories() async {
    try {
      final fetchedCategories = await _apiService.fetchCategories();
      _categories = fetchedCategories;
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load categories: $e");
    }
  }

  Future<Category?> addCategory(Category category) async {
    try {
      final createdCat = await _apiService.createCategory(category);
      if (createdCat != null) {
        _categories.add(createdCat);
        notifyListeners();
        return createdCat;
      }
    } catch (e) {
      debugPrint("Failed to create category: $e");
    }
    return null;
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';

class CurrencyProvider with ChangeNotifier {
  static const String _prefKey = 'selected_currency';

  Currency _selectedCurrency = const Currency(
    code: 'LKR',
    name: 'Sri Lankan Rupee',
    symbol: 'Rs. ',
  );

  Currency get selectedCurrency => _selectedCurrency;

  NumberFormat get currencyFormat => NumberFormat.currency(
        symbol: _selectedCurrency.symbol,
        decimalDigits: 2,
      );

  CurrencyProvider() {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final String? currencyJson = prefs.getString(_prefKey);
    if (currencyJson != null) {
      try {
        _selectedCurrency = Currency.fromJson(jsonDecode(currencyJson));
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading currency: $e');
      }
    }
  }

  Future<void> setCurrency(Currency currency) async {
    _selectedCurrency = currency;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(currency.toJson()));
  }

  static const List<Currency> currencies = [
    Currency(code: 'LKR', name: 'Sri Lankan Rupee', symbol: 'Rs. '),
    Currency(code: 'USD', name: 'United States Dollar', symbol: '\$'),
    Currency(code: 'EUR', name: 'Euro', symbol: '€'),
    Currency(code: 'GBP', name: 'British Pound Sterling', symbol: '£'),
    Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥'),
    Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
    Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$'),
    Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$'),
    Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF'),
    Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥'),
    Currency(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$'),
    Currency(code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ\$'),
    Currency(code: 'AED', name: 'United Arab Emirates Dirham', symbol: 'DH '),
    Currency(code: 'SAR', name: 'Saudi Riyal', symbol: 'SR '),
    Currency(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'KD '),
    Currency(code: 'OMR', name: 'Omani Rial', symbol: 'RO '),
    Currency(code: 'QAR', name: 'Qatari Rial', symbol: 'QR '),
    Currency(code: 'BHD', name: 'Bahraini Dinar', symbol: 'BD '),
    Currency(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM '),
    Currency(code: 'THB', name: 'Thai Baht', symbol: '฿'),
    Currency(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp '),
    Currency(code: 'PHP', name: 'Philippine Peso', symbol: '₱'),
    Currency(code: 'KRW', name: 'South Korean Won', symbol: '₩'),
    Currency(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$'),
    Currency(code: 'RUB', name: 'Russian Ruble', symbol: '₽'),
    Currency(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$'),
    Currency(code: 'ZAR', name: 'South African Rand', symbol: 'R '),
    Currency(code: 'TRY', name: 'Turkish Lira', symbol: '₺'),
    Currency(code: 'MXN', name: 'Mexican Peso', symbol: 'Mex\$'),
    Currency(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr '),
    Currency(code: 'SEK', name: 'Swedish Krona', symbol: 'kr '),
    Currency(code: 'DKK', name: 'Danish Krone', symbol: 'kr '),
    Currency(code: 'PLN', name: 'Polish Zloty', symbol: 'zł '),
    Currency(code: 'ILS', name: 'Israeli New Shekel', symbol: '₪'),
  ];
}

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' hide Category;
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class ApiService {
  //static const String baseUrl = 'http://10.0.2.2:8000'; // Android Emulator default localhost
  static const String baseUrl = 'http://192.168.8.100:8000'; // Physical Device

  final _secureStorage = const FlutterSecureStorage();

  // --- Auth Helpers ---
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _secureStorage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final url = Uri.parse('$baseUrl/auth/refresh');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _secureStorage.write(
          key: 'access_token',
          value: data['access_token'],
        );
        debugPrint("Token refreshed successfully.");
        return true;
      }
    } catch (e) {
      debugPrint("Error refreshing token: $e");
    }
    await logout(); // Revoke/clear tokens if refresh fails
    return false;
  }

  /// Wrapper around http requests that handles auto-refresh on 401 Unauthorized
  Future<http.Response> _makeAuthenticatedRequest(
    String method,
    Uri url, {
    Map<String, String>? additionalHeaders,
    Object? body,
  }) async {
    final headers = await _getAuthHeaders();
    if (additionalHeaders != null) headers.addAll(additionalHeaders);

    http.Response response;

    // Initial request
    if (method == 'GET') {
      response = await http.get(url, headers: headers);
    } else if (method == 'POST') {
      response = await http.post(url, headers: headers, body: body);
    } else if (method == 'PUT') {
      response = await http.put(url, headers: headers, body: body);
    } else if (method == 'DELETE') {
      response = await http.delete(url, headers: headers);
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    // If unauthorized, try to refresh and retry exactly once
    if (response.statusCode == 401) {
      debugPrint("Access token expired. Attempting refresh...");
      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        final newHeaders = await _getAuthHeaders();
        if (additionalHeaders != null) newHeaders.addAll(additionalHeaders);

        if (method == 'GET') {
          response = await http.get(url, headers: newHeaders);
        } else if (method == 'POST') {
          response = await http.post(url, headers: newHeaders, body: body);
        } else if (method == 'PUT') {
          response = await http.put(url, headers: newHeaders, body: body);
        } else if (method == 'DELETE') {
          response = await http.delete(url, headers: newHeaders);
        }
      }
    }

    return response;
  }

  // --- 1. Login Function ---
  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool isBiometric = false,
  }) async {
    final url = Uri.parse('$baseUrl/login/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'is_biometric': isBiometric,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if 2FA is required
        if (data['requires_2fa'] == true) {
          debugPrint("Login requires 2FA.");
          return {'status': '2FA_REQUIRED', 'temp_token': data['temp_token']};
        }

        final token = data['access_token'];
        final refreshToken = data['refresh_token'];
        final userId = data['user_id'];

        // Saving Tokens securely, User ID normally
        await _secureStorage.write(key: 'access_token', value: token);
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userId);

        debugPrint("Login Successful! Token Saved.");
        return {'status': 'SUCCESS'};
      } else {
        debugPrint("Login Failed: ${response.body}");
        return {
          'status': 'FAILED',
          'message': jsonDecode(response.body)['detail'] ?? 'Login failed',
        };
      }
    } catch (e) {
      debugPrint("Error during login: $e");
      // Rethrow so the UI can show network error instead of simple Incorrect Password
      throw Exception(
        'Network Error: Cannot connect to Server. Is the backend running?',
      );
    }
  }

  // --- 1.5 2FA Verification Methods ---
  Future<Map<String, dynamic>> verifyLoginOTP(
    String tempToken,
    String otpCode,
  ) async {
    final url = Uri.parse('$baseUrl/login/verify-2fa');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'temp_token': tempToken, 'otp_code': otpCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final refreshToken = data['refresh_token'];
        final userId = data['user_id'];

        await _secureStorage.write(key: 'access_token', value: token);
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userId);

        return {'status': 'SUCCESS'};
      } else if (response.statusCode == 403) {
        return {
          'status': 'FAILED_MAX_ATTEMPTS',
          'message': jsonDecode(response.body)['detail'],
        };
      } else {
        return {
          'status': 'FAILED',
          'message': jsonDecode(response.body)['detail'] ?? 'Invalid code',
        };
      }
    } catch (e) {
      throw Exception('Network Error: Cannot connect to Server.');
    }
  }

  Future<bool> resendLoginOTP(String tempToken) async {
    final url = Uri.parse('$baseUrl/login/resend-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'temp_token': tempToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final url = Uri.parse('$baseUrl/auth/forgot-password/request');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'status': 'SUCCESS',
          'message':
              data['message'] ??
              'If an account exists, a reset code has been sent.',
        };
      }

      return {
        'status': 'FAILED',
        'message': data['detail'] ?? 'Failed to request password reset',
      };
    } catch (e) {
      return {'status': 'ERROR', 'message': 'Network Error'};
    }
  }

  Future<Map<String, dynamic>> checkEmailExists(String email) async {
    final url = Uri.parse('$baseUrl/auth/check-email');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'status': 'SUCCESS',
          'message': data['message'] ?? 'Email exists',
        };
      }

      return {
        'status': 'FAILED',
        'message': data['detail'] ?? 'Email not found',
      };
    } catch (e) {
      return {'status': 'ERROR', 'message': 'Network Error'};
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset(
    String email,
    String resetCode,
    String newPassword,
  ) async {
    final url = Uri.parse('$baseUrl/auth/forgot-password/confirm');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'reset_code': resetCode,
          'new_password': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'status': 'SUCCESS',
          'message': data['message'] ?? 'Password reset successful',
        };
      }

      return {
        'status': 'FAILED',
        'message': data['detail'] ?? 'Failed to reset password',
      };
    } catch (e) {
      return {'status': 'ERROR', 'message': 'Network Error'};
    }
  }

  // --- 1.6 High-Security 2FA & Password Methods ---

  Future<bool> request2FAChallenge() async {
    final url = Uri.parse('$baseUrl/users/me/2fa-challenge');
    try {
      final response = await _makeAuthenticatedRequest('POST', url);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error requesting 2FA challenge: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> updatePassword(
    String oldPassword,
    String newPassword, {
    String? otpCode,
  }) async {
    final url = Uri.parse('$baseUrl/users/me/password');
    try {
      final response = await _makeAuthenticatedRequest(
        'PUT',
        url,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'otp_code': otpCode,
        }),
      );

      if (response.statusCode == 403 &&
          response.body.contains("2FA_REQUIRED")) {
        return {'status': '2FA_REQUIRED'};
      }

      if (response.statusCode == 200) {
        return {'status': 'SUCCESS'};
      }

      final errorData = jsonDecode(response.body);
      return {
        'status': 'FAILED',
        'message': errorData['detail'] ?? 'Update failed',
      };
    } catch (e) {
      debugPrint("Error updating password: $e");
      return {'status': 'ERROR', 'message': 'Network Error'};
    }
  }

  Future<Map<String, dynamic>> toggle2FA(bool enable, {String? otpCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      return {'status': 'ERROR', 'message': 'User not logged in'};
    }

    final url = Uri.parse('$baseUrl/users/$userId/2fa/toggle');
    try {
      final response = await _makeAuthenticatedRequest(
        'POST',
        url,
        body: jsonEncode({'enable': enable, 'otp_code': otpCode}),
      );

      if (response.statusCode == 403 &&
          response.body.contains("2FA_REQUIRED")) {
        return {'status': '2FA_REQUIRED'};
      }

      if (response.statusCode == 200) {
        return {
          'status': 'SUCCESS',
          'two_factor_enabled': jsonDecode(response.body)['two_factor_enabled'],
        };
      }

      final errorData = jsonDecode(response.body);
      return {
        'status': 'FAILED',
        'message': errorData['detail'] ?? 'Toggle failed',
      };
    } catch (e) {
      debugPrint("Error toggling 2FA: $e");
      return {'status': 'ERROR', 'message': 'Network Error'};
    }
  }

  // --- 2. Signup Function ---
  Future<bool> signup(
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/users/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Signup Successful!");
        return true;
      } else {
        debugPrint("Signup Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error during signup: $e");
      return false;
    }
  }

  // --- 2. Google Login Function ---
  Future<bool> signInWithGoogle({bool silent = false}) async {
    try {
      // Initializing Google Sign In
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '1048975331457-khgpuu3hhqm0jblpof2foph89ents3to.apps.googleusercontent.com',
      );

      // Requesting the user to select a Google account
      GoogleSignInAccount? googleUser;
      if (silent) {
        final future = GoogleSignIn.instance.attemptLightweightAuthentication();
        if (future != null) {
          googleUser = await future;
        } else {
          // If null, it means event stream needs to be used, but for simplicity here we assume failure or handle it manually if needed.
          // Usually attemptLightweightAuthentication returns a future on iOS/Android.
          debugPrint(
            "attemptLightweightAuthentication returned null, cannot silently sign in procedurally",
          );
        }
      } else {
        googleUser = await GoogleSignIn.instance
            .authenticate(); // standard method
      }

      if (googleUser == null) {
        debugPrint("Google Sign in cancelled or silent sign-in failed.");
        return false;
      }

      // Getting the ID Token
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        debugPrint("No ID Token received.");
        return false;
      }

      debugPrint("Google Login Success!");
      debugPrint("Email: ${googleUser.email}");
      debugPrint("Name: ${googleUser.displayName}");
      debugPrint("Google ID: ${googleUser.id}");

      // Need to send these details to our Python Backend (FastAPI) to save the user
      final url = Uri.parse('$baseUrl/auth/google');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': idToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final refreshToken = data['refresh_token'];
        final userId = data['user_id'];

        // Saving Tokens securely, User ID normally
        await _secureStorage.write(key: 'access_token', value: token);
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userId);

        debugPrint("Google Login Successful! Token Saved.");
        return true;
      } else {
        debugPrint("Google Login Backend Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      if (e is FlutterError) {
        debugPrint("User Login Failed: $e");
        throw Exception("Google Login Error: $e");
      }

      final String errorString = e.toString();
      if (errorString.contains('sign_in_canceled') ||
          errorString.contains('canceled')) {
        debugPrint("User canceled the Login.");
        return false;
      } else {
        debugPrint("A Google Login Error occurred: $e");
        throw Exception(e.toString());
      }
    }
  }

  // --- 2.5 Facebook Login Function ---
  Future<bool> signInWithFacebook({bool silent = false}) async {
    try {
      AccessToken? accessToken;

      if (silent) {
        accessToken = await FacebookAuth.instance.accessToken;
      } else {
        // Trigger the sign-in flow
        final LoginResult result = await FacebookAuth.instance.login();
        if (result.status == LoginStatus.success) {
          accessToken = result.accessToken;
        }
      }

      if (accessToken != null) {
        // you are logged
        debugPrint("Facebook Login Success!");
        debugPrint("Facebook Token: ${accessToken.tokenString}");

        // Send token to our Python Backend (FastAPI) to save the user
        final url = Uri.parse('$baseUrl/auth/facebook');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': accessToken.tokenString}),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final token = data['access_token'];
          final refreshToken = data['refresh_token'];
          final userId = data['user_id'];

          // Saving Tokens securely, User ID normally
          await _secureStorage.write(key: 'access_token', value: token);
          await _secureStorage.write(key: 'refresh_token', value: refreshToken);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', userId);

          debugPrint("Facebook Login Successful! Token Saved.");
          return true;
        } else {
          debugPrint("Facebook Login Backend Failed: ${response.body}");
          return false;
        }
      } else {
        debugPrint("Facebook Login Failed or cancelled.");
        return false;
      }
    } catch (e) {
      debugPrint("A Facebook Login Error occurred: $e");
      throw Exception(e.toString());
    }
  }

  // --- 3. Transaction Fetching ---
  Future<List<Transaction>> fetchUserTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return [];

    // First fetch categories to map the transaction types correctly
    final categories = await fetchCategories();
    final categoryMap = {for (var c in categories) c.id: c};

    final url = Uri.parse('$baseUrl/transactions/$userId');
    try {
      final response = await _makeAuthenticatedRequest('GET', url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((item) {
          final catId = item['category_id'] as int;
          final category = categoryMap[catId];
          final cName = category?.name ?? 'Unknown';
          final cType = category?.categoryType.toLowerCase() == 'income'
              ? TransactionType.income
              : TransactionType.expense;

          return Transaction.fromJson(item, cName: cName, cType: cType);
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching transactions: $e");
      throw Exception("Failed to connect to the server.");
    }
    return [];
  }

  // --- 4. Create Transaction ---
  Future<Transaction?> createTransaction(Transaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return null;

    final url = Uri.parse('$baseUrl/transactions/?user_id=$userId');
    try {
      final response = await _makeAuthenticatedRequest(
        'POST',
        url,
        body: jsonEncode(transaction.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Transaction.fromJson(jsonDecode(response.body));
      } else {
        debugPrint("Failed to create transaction: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error creating transaction: $e");
    }
    return null;
  }

  // --- 4.5. Update Transaction ---
  Future<Transaction?> updateTransaction(
    int transactionId,
    Transaction transaction,
  ) async {
    final url = Uri.parse('$baseUrl/transactions/$transactionId');
    try {
      final response = await _makeAuthenticatedRequest(
        'PUT',
        url,
        body: jsonEncode(transaction.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Transaction.fromJson(jsonDecode(response.body));
      } else {
        debugPrint("Failed to update transaction: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error updating transaction: $e");
    }
    return null;
  }

  // --- 5. Delete Transaction ---
  Future<bool> deleteTransaction(int transactionId) async {
    final url = Uri.parse('$baseUrl/transactions/$transactionId');
    try {
      final response = await _makeAuthenticatedRequest('DELETE', url);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error deleting transaction: $e");
      return false;
    }
  }

  // --- 5.1 Suggest Category ---
  Future<Map<String, dynamic>?> suggestCategory(
    String title,
    String type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null || title.trim().isEmpty) return null;

    final url = Uri.parse('$baseUrl/transactions/suggest-category/$userId');
    try {
      final response = await _makeAuthenticatedRequest(
        'POST',
        url,
        body: jsonEncode({'title': title, 'type': type}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error suggesting category: $e");
    }
    return null;
  }

  // --- 5.5 Fetch Categories ---
  Future<List<Category>> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return [];

    final url = Uri.parse('$baseUrl/categories/user/$userId');
    try {
      final response = await _makeAuthenticatedRequest('GET', url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Category.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      throw Exception("Failed to connect to the server.");
    }
    return [];
  }

  // --- 5.6 Create Category ---
  Future<Category?> createCategory(Category category) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return null;

    final url = Uri.parse('$baseUrl/categories/?user_id=$userId');
    try {
      final response = await _makeAuthenticatedRequest(
        'POST',
        url,
        body: jsonEncode(
          category.toJson()..['user_id'] = userId,
        ), // Pass user_id explicitly in body if backend expects or via query param over URL
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Category.fromJson(jsonDecode(response.body));
      } else {
        debugPrint("Failed to create category: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error creating category: $e");
    }
    return null;
  }

  // --- 6. Fetch Budgets ---
  Future<List<dynamic>> fetchUserBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return [];

    final url = Uri.parse('$baseUrl/budgets/user/$userId');
    try {
      final response = await _makeAuthenticatedRequest('GET', url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error fetching budgets: $e");
    }
    return [];
  }

  // --- 6.1 Create Budget ---
  Future<Budget?> createBudget(Budget budget) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return null;

    final url = Uri.parse('$baseUrl/budgets/?user_id=$userId');
    try {
      final response = await _makeAuthenticatedRequest(
        'POST',
        url,
        body: jsonEncode(budget.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Budget.fromJson(jsonDecode(response.body));
      } else {
        debugPrint("Failed to create budget: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error creating budget: $e");
    }
    return null;
  }

  // --- 6.2 Update Budget ---
  Future<Budget?> updateBudget(int budgetId, Budget budget) async {
    final url = Uri.parse('$baseUrl/budgets/$budgetId');
    try {
      final response = await _makeAuthenticatedRequest(
        'PUT',
        url,
        body: jsonEncode(budget.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Budget.fromJson(jsonDecode(response.body));
      } else {
        debugPrint("Failed to update budget: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error updating budget: $e");
    }
    return null;
  }

  // --- 6.3 Predict Budgets ---
  Future<Map<int, double>> predictBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return {};

    final url = Uri.parse('$baseUrl/budgets/predict/$userId');
    try {
      final response = await _makeAuthenticatedRequest('GET', url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data.map(
          (key, value) => MapEntry(int.parse(key), (value as num).toDouble()),
        );
      }
    } catch (e) {
      debugPrint("Error predicting budgets: $e");
    }
    return {};
  }

  // --- 7. Fetch AI Insights ---
  Future<String> fetchUserInsights() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return "Please log in to see insights.";

    final url = Uri.parse('$baseUrl/insights/user/$userId');
    try {
      final response = await _makeAuthenticatedRequest('GET', url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Return the latest unread or newest message
          return data.last['message'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching insights: $e");
    }
    return "Start tracking to get daily generated AI insights!";
  }

  // --- 8. Fetch User Details ---
  Future<Map<String, dynamic>?> fetchUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return null;

    final url = Uri.parse('$baseUrl/users/$userId');
    try {
      final response = await _makeAuthenticatedRequest('GET', url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
    return null;
  }

  // --- 8.5 Upload Profile Picture ---
  Future<bool> uploadProfilePicture(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return false;

    final url = Uri.parse('$baseUrl/users/$userId/upload-profile-picture');
    try {
      final headers = await _getAuthHeaders();
      var request = http.MultipartRequest('POST', url)
        ..headers.addAll(headers)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint("Profile picture uploaded successfully.");
        return true;
      } else {
        debugPrint("Failed to upload profile picture: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error uploading profile picture: $e");
    }
    return false;
  }

  // --- 8.6 Update User Details ---
  Future<Map<String, dynamic>> updateUserDetails(
    String firstName,
    String lastName, {
    String? otpCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return {'status': 'ERROR', 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/users/$userId');
    try {
      final response = await _makeAuthenticatedRequest(
        'PUT',
        url,
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'otp_code': otpCode,
        }),
      );

      if (response.statusCode == 403 &&
          response.body.contains("2FA_REQUIRED")) {
        return {'status': '2FA_REQUIRED'};
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("User details updated successfully.");
        return {'status': 'SUCCESS'};
      } else {
        debugPrint("Failed to update user details: ${response.body}");
        final errorData = jsonDecode(response.body);
        return {
          'status': 'FAILED',
          'message': errorData['detail'] ?? 'Update failed',
        };
      }
    } catch (e) {
      debugPrint("Error updating user details: $e");
      return {'status': 'ERROR', 'message': 'Network Error'};
    }
  }

  // --- 8.7 Change Password ---
  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      return {
        'success': false,
        'message': 'User not found. Please log in again.',
      };
    }

    final url = Uri.parse('$baseUrl/users/$userId/change-password');
    try {
      final response = await _makeAuthenticatedRequest(
        'PUT',
        url,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully.',
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Failed to change password.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // --- 9. Logout ---
  Future<void> logout() async {
    try {
      // 1. Tell backend to revoke refresh token
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken != null) {
        final url = Uri.parse('$baseUrl/auth/logout');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      }
    } catch (e) {
      debugPrint("Backend logout failed or offline: $e");
    }

    // 2. Clear local storage
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');

    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getInt('user_id');
    if (currentUserId != null) {
      await prefs.setInt('last_user_id', currentUserId);
    }
    await prefs.remove('token'); // Leftover cleanup just in case
    await prefs.remove('user_id');

    debugPrint("User logged out successfully. Local tokens cleared.");
  }
}

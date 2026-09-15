import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final Color _primaryTeal = const Color(0xFF00BFA6);
  final Color _bgDarkBlue = const Color(0xFF0A192F);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signup() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showCustomSnackBar(
        context: context,
        message: 'Please fill all fields.',
        icon: Icons.warning_amber_rounded,
        backgroundColor: Colors.orange.shade800,
      );
      return;
    }

    if (password != confirmPassword) {
      _showCustomSnackBar(
        context: context,
        message: 'Passwords do not match.',
        icon: Icons.error_outline_rounded,
        backgroundColor: Colors.redAccent.shade700,
      );
      return;
    }

    try {
      final apiService = ApiService();
      final isSuccess = await apiService.signup(firstName, lastName, email, password);

      if (!mounted) return;

      if (isSuccess) {
        _showCustomSnackBar(
          context: context,
          message: 'Account created successfully!',
          icon: Icons.check_circle_outline_rounded,
          backgroundColor: Colors.green.shade600,
        );
        // Navigate back to login screen
        Navigator.pop(context);
      } else {
        _showCustomSnackBar(
          context: context,
          message: 'Registration failed. Email might already be taken.',
          icon: Icons.error_outline_rounded,
          backgroundColor: Colors.redAccent.shade700,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showCustomSnackBar(
        context: context,
        message: 'Error: $e',
        icon: Icons.warning_amber_rounded,
        backgroundColor: Colors.redAccent.shade700,
      );
    }
  }

  void _showCustomSnackBar({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 6,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primaryTeal, _primaryTeal.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryTeal.withValues(alpha: 0.4),
                              blurRadius: 25,
                              spreadRadius: -5,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_add_rounded, size: 45, color: Colors.white),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        'Create Account',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color, letterSpacing: 1),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Join SmartFin today.',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('First Name'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _firstNameController,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            decoration: _inputDecoration('John', Icons.person_outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Last Name'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _lastNameController,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            decoration: _inputDecoration('Doe', Icons.person_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLabel('Email Address'),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('name@example.com', Icons.email_outlined),
                ),
                const SizedBox(height: 20),
                _buildLabel('Password'),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: _isPasswordHidden,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: _inputDecoration('Create a password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                      onPressed: () {
                        setState(() { _isPasswordHidden = !_isPasswordHidden; });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabel('Confirm Password'),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _isConfirmPasswordHidden,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: _inputDecoration('Confirm your password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                      onPressed: () {
                        setState(() { _isConfirmPasswordHidden = !_isConfirmPasswordHidden; });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark 
                        ? _bgDarkBlue 
                        : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 5,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    onPressed: _signup,
                    child: const Text('Sign Up'),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account? ", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Log In",
                        style: TextStyle(color: _primaryTeal, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).cardColor,
      hintText: hint,
      hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
      prefixIcon: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.blueGrey.withValues(alpha: 0.1) : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _primaryTeal, width: 2)),
    );
  }
}

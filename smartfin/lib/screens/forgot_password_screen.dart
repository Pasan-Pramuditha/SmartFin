import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _apiService = ApiService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _emailVerified = false;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  final Color _primaryTeal = const Color(0xFF00BFA6);
  final Color _bgDarkBlue = const Color(0xFF0A192F);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailAndRequestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email address.', false);
      return;
    }

    setState(() => _isLoading = true);
    final emailCheck = await _apiService.checkEmailExists(email);
    if (!mounted) return;

    if (emailCheck['status'] != 'SUCCESS') {
      setState(() => _isLoading = false);
      _showSnackBar(emailCheck['message'] ?? 'Email not found.', false);
      return;
    }

    final result = await _apiService.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['status'] == 'SUCCESS') {
        _emailVerified = true;
        _codeSent = true;
      }
    });

    _showSnackBar(
      result['message'] ?? 'Request processed.',
      result['status'] == 'SUCCESS',
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty ||
        code.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar('Please complete all fields.', false);
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('Password must be at least 6 characters.', false);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match.', false);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _apiService.confirmPasswordReset(
      email,
      code,
      newPassword,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    final success = result['status'] == 'SUCCESS';
    _showSnackBar(result['message'] ?? 'Password reset failed.', success);

    if (success) {
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? Colors.green.shade600
            : Colors.redAccent.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primaryTeal,
                          _primaryTeal.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryTeal.withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: -6,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      children: [
                        TextSpan(
                          text: 'Smart',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        TextSpan(
                          text: 'Fin',
                          style: TextStyle(color: _primaryTeal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure account recovery',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Reset your account password',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? 'Enter the code sent to your email and choose a new password.'
                  : 'Enter your email address. We will check whether the account exists before sending a reset code.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            if (_codeSent) ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reset Code',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: _hideNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hideNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _hideNewPassword = !_hideNewPassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _hideConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hideConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(
                        () => _hideConfirmPassword = !_hideConfirmPassword,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (!_codeSent) ...[
              const SizedBox(height: 4),
              Text(
                _emailVerified
                    ? 'Email verified. Sending reset code...'
                    : 'Tap the button below to verify the email first.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!_codeSent) const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryTeal,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? _bgDarkBlue
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : _codeSent
                    ? _resetPassword
                    : _checkEmailAndRequestCode,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _codeSent ? 'Reset Password' : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _checkEmailAndRequestCode,
                  child: Text(
                    'Resend Code',
                    style: TextStyle(color: _primaryTeal),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

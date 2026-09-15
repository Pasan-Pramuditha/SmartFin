import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _showOTPField = false;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isResending = false;
  Timer? _timer;
  int _start = 120; // 2 minutes setup

  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final Color _primaryTeal = const Color(0xFF00BFA6);

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _start = 120);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() => timer.cancel());
      } else {
        setState(() => _start--);
      }
    });
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);
    try {
      final success = await _apiService.request2FAChallenge();
      if (!mounted) return;
      setState(() => _isResending = false);
      if (success == true) { // just in case it returns true/boolean
        _startTimer();
        _otpController.clear();
        FocusScope.of(context).requestFocus(_otpFocusNode);
        _showSnackBar('A new verification code has been sent.', isError: false);
      } else {
        _showSnackBar('Failed to resend code.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showSnackBar(e.toString());
    }
  }

  bool get _hasMinLength => _newPasswordController.text.length >= 6;
  bool get _passwordsMatch =>
      _newPasswordController.text == _confirmPasswordController.text &&
      _newPasswordController.text.isNotEmpty;

  Future<void> _handleChangePassword() async {
    final oldPass = _oldPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showSnackBar('Please fill all fields');
      return;
    }
    if (newPass != confirmPass) {
      _showSnackBar('New passwords do not match');
      return;
    }
    if (newPass.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    if (_showOTPField && _otpController.text.trim().length != 6) {
      _showSnackBar('Please enter the 6-digit verification code');
      return;
    }

    setState(() => _isLoading = true);
    
    final result = await _apiService.updatePassword(
      oldPass, 
      newPass, 
      otpCode: _showOTPField ? _otpController.text.trim() : null
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['status'] == 'SUCCESS') {
      _showSnackBar('Password updated successfully', isError: false);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } else if (result['status'] == '2FA_REQUIRED') {
      // Trigger OTP sending
      await _apiService.request2FAChallenge();
      setState(() {
        _showOTPField = true;
        _startTimer();
      });
      _showSnackBar('Verification required. Code sent to your email.', isError: false);
    } else {
      _showSnackBar(result['message'] ?? 'Failed to update password');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.redAccent.withValues(alpha: 0.9)
            : _primaryTeal.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    String timerText = '${_start ~/ 60}:${(_start % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Password',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Center(child: _buildHeader(textColor)),
              const SizedBox(height: 32),

              // Form Container
              _buildInputSection(
                label: 'Current Password',
                controller: _oldPasswordController,
                isVisible: _isOldPasswordVisible,
                onToggle: () => setState(
                  () => _isOldPasswordVisible = !_isOldPasswordVisible,
                ),
              ),
              const SizedBox(height: 24),

              _buildInputSection(
                label: 'New Password',
                controller: _newPasswordController,
                isVisible: _isNewPasswordVisible,
                onToggle: () => setState(
                  () => _isNewPasswordVisible = !_isNewPasswordVisible,
                ),
                onChanged: (val) => setState(() {}),
              ),

              const SizedBox(height: 12),
              _buildValidationChecklist(),

              const SizedBox(height: 24),
              _buildInputSection(
                label: 'Confirm New Password',
                controller: _confirmPasswordController,
                isVisible: _isConfirmPasswordVisible,
                onToggle: () => setState(
                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                ),
                onChanged: (val) => setState(() {}),
              ),
 
              if (_newPasswordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ValidationItem(
                  label: 'Passwords match',
                  isValid: _passwordsMatch,
                ),
              ],

              if (_showOTPField) ...[
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 16),
                  child: Text(
                    'VERIFICATION CODE (OTP)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primaryTeal.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _buildOTPBoxes(),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'We sent a 6-digit code to your email for security.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive a code?",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: (_isResending || _start > 0) ? null : _resendOTP,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00BFA6),
                      ),
                      child: _isResending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFA6)))
                          : Text(
                              _start > 0 ? "Resend in $timerText" : "Resend",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _start > 0 
                                  ? (Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4) ?? Colors.blueGrey[400]) 
                                  : const Color(0xFF00BFA6),
                              ),
                            ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 48),
              _buildSubmitButton(isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color? textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryTeal.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primaryTeal.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.shield_rounded, color: _primaryTeal, size: 85),
        ),
        const SizedBox(height: 50),
        Text(
          'Secure Your Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Update your password to stay protected.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: textColor?.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggle,
    Function(String)? onChanged,
    bool isOTP = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _primaryTeal.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: !isVisible,
            onChanged: onChanged,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: InputBorder.none,
              hintText: isOTP ? '• • • • • •' : '••••••••',
              hintStyle: TextStyle(
                color: (Theme.of(
                  context,
                ).textTheme.bodyLarge?.color)?.withValues(alpha: 0.2),
                letterSpacing: isOTP ? 8 : 0,
              ),
              suffixIcon: isOTP ? null : IconButton(
                icon: Icon(
                  isVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _primaryTeal.withValues(alpha: 0.7),
                  size: 22,
                ),
                onPressed: onToggle,
              ),
            ),
            keyboardType: isOTP ? TextInputType.number : TextInputType.text,
            maxLength: isOTP ? 6 : null,
            textAlign: isOTP ? TextAlign.center : TextAlign.start,
          ),
        ),
      ],
    );
  }

  Widget _buildValidationChecklist() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          _ValidationItem(
            label: 'At least 6 characters long',
            isValid: _hasMinLength,
          ),
        ],
      ),
    );
  }

  Widget _buildOTPBoxes() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(_otpFocusNode),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              autofillHints: const [AutofillHints.oneTimeCode],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final text = _otpController.text;
              final char = index < text.length ? text[index] : "";
              final isFocused = index == text.length || (index == 5 && text.length == 6);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 45,
                height: 55,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF112240) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFocused && _otpFocusNode.hasFocus
                        ? const Color(0xFF00BFA6)
                        : (isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.black12),
                    width: 2,
                  ),
                  boxShadow: isFocused && _otpFocusNode.hasFocus
                      ? [BoxShadow(color: const Color(0xFF00BFA6).withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  char,
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryTeal.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleChangePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Update Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class _ValidationItem extends StatelessWidget {
  final String label;
  final bool isValid;

  const _ValidationItem({required this.label, required this.isValid});

  @override
  Widget build(BuildContext context) {
    final color = isValid ? const Color(0xFF00BFA6) : Colors.blueGrey[400];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: isValid ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

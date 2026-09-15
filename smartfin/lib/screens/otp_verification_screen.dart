import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import 'main_layout.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String tempToken;
  final String? email;
  final String? password;

  const OTPVerificationScreen({super.key, required this.tempToken, this.email, this.password});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isResending = false;
  Timer? _timer;
  int _start = 120;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpController.addListener(() {
      if (_otpController.text.length == 6 && !_isLoading) {
        _verifyOTP();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
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

  Future<void> _verifyOTP() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.verifyLoginOTP(widget.tempToken, code);
      
      if (!mounted) return;

      if (result['status'] == 'SUCCESS') {
        if (widget.email != null && widget.password != null) {
          const secureStorage = FlutterSecureStorage();
          await secureStorage.write(key: 'saved_email', value: widget.email);
          await secureStorage.write(key: 'saved_password', value: widget.password);
        }

        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');
        
        if (userId != null) {
          await _checkAndPromptBiometrics(userId);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      } else if (result['status'] == 'FAILED_MAX_ATTEMPTS') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Too many failed attempts.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context); // Go back to login screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Invalid code.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndPromptBiometrics(int userId) async {
    final biometricService = BiometricService();
    final isAvailable = await biometricService.isAvailable();
    if (!isAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('biometrics_enabled_$userId') ?? false;
    if (isEnabled) return;

    if (!mounted) return;

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enable Biometrics?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Would you like to use Face ID or Fingerprint for faster login next time?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Maybe Later', style: TextStyle(color: Colors.blueGrey[300])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      await prefs.setBool('biometrics_enabled_$userId', true);
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);
    final success = await _apiService.resendLoginOTP(widget.tempToken);
    if (!mounted) return;

    setState(() => _isResending = false);
    
    if (success) {
      _startTimer();
      _otpController.clear();
      FocusScope.of(context).requestFocus(_focusNode);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent to your email.'), backgroundColor: Color(0xFF00BFA6)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend code.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildOTPBoxes() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _otpController,
              focusNode: _focusNode,
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
                width: 48,
                height: 58,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF112240) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFocused && _focusNode.hasFocus
                        ? const Color(0xFF00BFA6)
                        : (isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.black12),
                    width: 2,
                  ),
                  boxShadow: isFocused && _focusNode.hasFocus
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

  @override
  Widget build(BuildContext context) {
    String timerText = '${_start ~/ 60}:${(_start % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00BFA6),
                      const Color(0xFF00BFA6).withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BFA6).withValues(alpha: 0.4),
                      blurRadius: 25,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 45,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  children: [
                    TextSpan(
                      text: 'Verify ',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                    TextSpan(
                      text: 'Identity',
                      style: TextStyle(color: const Color(0xFF00BFA6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit code to your email address. Please enter it below to securely log in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              _buildOTPBoxes(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading || _otpController.text.length < 6 ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA6),
                    foregroundColor: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF0A192F)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    disabledBackgroundColor: const Color(0xFF00BFA6).withValues(alpha: 0.5),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Verify & Proceed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive a code?",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 15,
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
                              fontSize: 15,
                              color: _start > 0 
                                ? (Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4) ?? Colors.blueGrey[400]) 
                                : const Color(0xFF00BFA6),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'signup_screen.dart';
import 'main_layout.dart';
import 'otp_verification_screen.dart';
import 'forgot_password_screen.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordHidden = true;
  bool _showBiometricButton = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkAndShowBiometricButton();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  final Color _primaryTeal = const Color(0xFF00BFA6);
  final Color _bgDarkBlue = const Color(0xFF0A192F);

  /// On startup: if user has biometrics enabled, auto-show the prompt.
  Future<void> _checkAndShowBiometricButton() async {
    final prefs = await SharedPreferences.getInstance();
    // Use current user_id if logged in, otherwise fall back to the last logged out user_id
    final userId = prefs.getInt('user_id') ?? prefs.getInt('last_user_id');

    debugPrint("Biometric DEBUG: userId (or last_user_id) = $userId");

    if (userId == null) {
      debugPrint("Biometric DEBUG: No userId or last_user_id found.");
      return;
    }

    final biometricsEnabled =
        prefs.getBool('biometrics_enabled_$userId') ?? false;

    final secureStorage = const FlutterSecureStorage();
    final hasToken = await secureStorage.read(key: 'refresh_token') != null;
    final hasCredentials =
        await secureStorage.read(key: 'saved_email') != null &&
        await secureStorage.read(key: 'saved_password') != null;
    final hasAuthProvider =
        await secureStorage.read(key: 'auth_provider') != null;

    debugPrint("Biometric DEBUG: biometricsEnabled = $biometricsEnabled");
    debugPrint("Biometric DEBUG: hasToken = $hasToken");
    debugPrint("Biometric DEBUG: hasCredentials = $hasCredentials");

    if (!biometricsEnabled) {
      debugPrint("Biometric DEBUG: Biometrics not enabled for this user.");
      return;
    }

    // Biometrics should only be offered if there is an active token OR safely stored credentials or auth provider
    if (!hasToken && !hasCredentials && !hasAuthProvider) {
      debugPrint(
        "Biometric DEBUG: No active token or securely saved credentials to authenticate with.",
      );
      return;
    }

    final available = await _biometricService.isAvailable();
    debugPrint("Biometric DEBUG: available = $available");
    if (!available) return;

    if (mounted) {
      setState(() => _showBiometricButton = true);
    }
  }

  Future<void> _promptToEnableBiometrics(int userId) async {
    final available = await _biometricService.isAvailable();
    if (!available) return;

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
        title: const Text(
          'Enable Biometrics?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Would you like to use Face ID or Fingerprint for faster login next time?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.blueGrey[300]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Enable Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await prefs.setBool('biometrics_enabled_$userId', true);
    }
  }

  Future<void> _loginWithBiometrics() async {
    final success = await _biometricService.authenticate();
    if (!mounted) return;

    if (success) {
      // Check if we need to silently re-login using saved credentials
      final secureStorage = const FlutterSecureStorage();
      final hasToken = await secureStorage.read(key: 'refresh_token') != null;

      if (!hasToken) {
        // App is in "Logged Out" state, but biometric succeeded.
        // Retrieve securely stored credentials and authenticate in the background.
        final email = await secureStorage.read(key: 'saved_email');
        final password = await secureStorage.read(key: 'saved_password');
        final authProvider = await secureStorage.read(key: 'auth_provider');

        if (!mounted) return;

        if (email == null && password == null && authProvider == null) {
          _showCustomSnackBar(
            context: context,
            message: 'Session expired. Please log in again.',
            icon: Icons.error_outline_rounded,
            backgroundColor: Colors.redAccent.shade700,
          );
          return;
        }

        // Show a loading indicator during the network request
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
          ),
        );

        try {
          final apiService = ApiService();
          if (authProvider == 'google') {
            final isSuccess = await apiService.signInWithGoogle(silent: true);
            if (!mounted) return;
            Navigator.pop(context); // Dismiss loading dialog

            if (isSuccess) {
              _showCustomSnackBar(
                context: context,
                message: 'Biometric Google login successful!',
                icon: Icons.check_circle_outline_rounded,
                backgroundColor: Colors.green.shade600,
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainLayout()),
              );
            } else {
              _showCustomSnackBar(
                context: context,
                message: 'Google Sign-in failed. Please log in again.',
                icon: Icons.error_outline_rounded,
                backgroundColor: Colors.redAccent.shade700,
              );
            }
          } else if (authProvider == 'facebook') {
            final isSuccess = await apiService.signInWithFacebook(silent: true);
            if (!mounted) return;
            Navigator.pop(context); // Dismiss loading dialog

            if (isSuccess) {
              _showCustomSnackBar(
                context: context,
                message: 'Biometric Facebook login successful!',
                icon: Icons.check_circle_outline_rounded,
                backgroundColor: Colors.green.shade600,
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainLayout()),
              );
            } else {
              _showCustomSnackBar(
                context: context,
                message: 'Facebook Sign-in failed. Please log in again.',
                icon: Icons.error_outline_rounded,
                backgroundColor: Colors.redAccent.shade700,
              );
            }
          } else if (email != null && password != null) {
            final result = await apiService.login(
              email,
              password,
              isBiometric: true,
            );

            if (!mounted) return;
            Navigator.pop(context); // Dismiss loading dialog

            if (result['status'] == 'SUCCESS') {
              _showCustomSnackBar(
                context: context,
                message: 'Biometric login successful!',
                icon: Icons.check_circle_outline_rounded,
                backgroundColor: Colors.green.shade600,
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainLayout()),
              );
            } else if (result['status'] == '2FA_REQUIRED') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPVerificationScreen(
                    tempToken: result['temp_token'],
                    email: email,
                    password: password,
                  ),
                ),
              );
            } else {
              _showCustomSnackBar(
                context: context,
                message:
                    result['message'] ??
                    'Authentication failed. Please use your password.',
                icon: Icons.error_outline_rounded,
                backgroundColor: Colors.redAccent.shade700,
              );
            }
          }
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // Dismiss loading dialog
          _showCustomSnackBar(
            context: context,
            message: 'Network Error. Could not authenticate.',
            icon: Icons.error_outline_rounded,
            backgroundColor: Colors.redAccent.shade700,
          );
        }
      } else {
        // Token exists, just proceed.
        if (!mounted) return;
        _showCustomSnackBar(
          context: context,
          message: 'Biometric authentication successful!',
          icon: Icons.check_circle_outline_rounded,
          backgroundColor: Colors.green.shade600,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } else {
      if (!mounted) return;
      _showCustomSnackBar(
        context: context,
        message: 'Biometric authentication failed. Please use your password.',
        icon: Icons.fingerprint,
        backgroundColor: Colors.orange.shade800,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
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
                            colors: [
                              _primaryTeal,
                              _primaryTeal.withValues(alpha: 0.7),
                            ],
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
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 45,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 25),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          children: [
                            TextSpan(
                              text: 'Smart',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            TextSpan(
                              text: 'Fin',
                              style: TextStyle(color: _primaryTeal),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Master your money, smartly.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                _buildLabel('Email Address'),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: _inputDecoration(
                    'name@example.com',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 25),
                _buildLabel('Password'),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: _isPasswordHidden,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration:
                      _inputDecoration(
                        'Enter your password',
                        Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.blueGrey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordHidden = !_isPasswordHidden;
                            });
                          },
                        ),
                      ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: _primaryTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryTeal,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? _bgDarkBlue
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    onPressed: () async {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text.trim();

                      if (email.isEmpty || password.isEmpty) {
                        _showCustomSnackBar(
                          context: context,
                          message: 'Please enter email and password.',
                          icon: Icons.warning_amber_rounded,
                          backgroundColor: Colors.orange.shade800,
                        );
                        return;
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00BFA6),
                          ),
                        ),
                      );

                      try {
                        final apiService = ApiService();
                        final result = await apiService.login(email, password);

                        if (!context.mounted) return;
                        Navigator.pop(context); // Dismiss loading dialog

                        if (result['status'] == 'SUCCESS') {
                          const secureStorage = FlutterSecureStorage();
                          await secureStorage.write(
                            key: 'saved_email',
                            value: email,
                          );
                          await secureStorage.write(
                            key: 'saved_password',
                            value: password,
                          );

                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getInt('user_id');
                          if (userId != null) {
                            await _promptToEnableBiometrics(userId);
                          }

                          if (!context.mounted) return;

                          _showCustomSnackBar(
                            context: context,
                            message: 'Logged in successfully!',
                            icon: Icons.check_circle_outline_rounded,
                            backgroundColor: Colors.green.shade600,
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainLayout(),
                            ),
                          );
                        } else if (result['status'] == '2FA_REQUIRED') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OTPVerificationScreen(
                                tempToken: result['temp_token'],
                                email: email,
                                password: password,
                              ),
                            ),
                          );
                        } else {
                          _showCustomSnackBar(
                            context: context,
                            message:
                                result['message'] ??
                                'Incorrect email or password.',
                            icon: Icons.error_outline_rounded,
                            backgroundColor: Colors.redAccent.shade700,
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context); // Dismiss loading dialog
                        _showCustomSnackBar(
                          context: context,
                          message: 'Error: $e',
                          icon: Icons.error_outline_rounded,
                          backgroundColor: Colors.redAccent.shade700,
                        );
                      }
                    },
                    child: const Text('Log In'),
                  ),
                ),

                // ── Biometric button ──────────────────────────────────────
                if (_showBiometricButton) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _primaryTeal, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        foregroundColor: _primaryTeal,
                      ),
                      onPressed: _loginWithBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 26),
                      label: const Text(
                        'Use Face ID / Fingerprint',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                // ─────────────────────────────────────────────────────────
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.blueGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        'Or continue with',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.blueGrey.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _socialButton(
                      child: _multicolorGoogleIcon(),
                      text: 'Google',
                      onPressed: () async {
                        try {
                          final apiService = ApiService();
                          final isSuccess = await apiService.signInWithGoogle();

                          if (!context.mounted) return;

                          if (isSuccess) {
                            const secureStorage = FlutterSecureStorage();
                            await secureStorage.write(
                              key: 'auth_provider',
                              value: 'google',
                            );
                            await secureStorage.delete(key: 'saved_email');
                            await secureStorage.delete(key: 'saved_password');

                            final prefs = await SharedPreferences.getInstance();
                            final userId = prefs.getInt('user_id');
                            if (userId != null) {
                              await _promptToEnableBiometrics(userId);
                            }

                            if (!context.mounted) return;

                            _showCustomSnackBar(
                              context: context,
                              message: 'Logged in successfully with Google!',
                              icon: Icons.check_circle_outline_rounded,
                              backgroundColor: Colors.green.shade600,
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MainLayout(),
                              ),
                            );
                          } else {
                            _showCustomSnackBar(
                              context: context,
                              message: 'Google Sign-in failed or was canceled.',
                              icon: Icons.error_outline_rounded,
                              backgroundColor: Colors.redAccent.shade700,
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          _showCustomSnackBar(
                            context: context,
                            message: 'Error: $e',
                            icon: Icons.error_outline_rounded,
                            backgroundColor: Colors.redAccent.shade700,
                          );
                        }
                      },
                    ),
                    _socialButton(
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          child: const Icon(
                            Icons.facebook_rounded,
                            size: 24,
                            color: Color(0xFF1877F2),
                          ),
                        ),
                      ),
                      text: 'Facebook',
                      onPressed: () async {
                        try {
                          final apiService = ApiService();
                          final isSuccess = await apiService
                              .signInWithFacebook();

                          if (!context.mounted) return;

                          if (isSuccess) {
                            const secureStorage = FlutterSecureStorage();
                            await secureStorage.write(
                              key: 'auth_provider',
                              value: 'facebook',
                            );
                            await secureStorage.delete(key: 'saved_email');
                            await secureStorage.delete(key: 'saved_password');

                            final prefs = await SharedPreferences.getInstance();
                            final userId = prefs.getInt('user_id');
                            if (userId != null) {
                              await _promptToEnableBiometrics(userId);
                            }

                            if (!context.mounted) return;

                            _showCustomSnackBar(
                              context: context,
                              message: 'Logged in successfully with Facebook!',
                              icon: Icons.check_circle_outline_rounded,
                              backgroundColor: Colors.green.shade600,
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MainLayout(),
                              ),
                            );
                          } else {
                            _showCustomSnackBar(
                              context: context,
                              message:
                                  'Facebook Sign-in failed or was canceled.',
                              icon: Icons.error_outline_rounded,
                              backgroundColor: Colors.redAccent.shade700,
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          _showCustomSnackBar(
                            context: context,
                            message: 'Error: $e',
                            icon: Icons.error_outline_rounded,
                            backgroundColor: Colors.redAccent.shade700,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          color: _primaryTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(
          context,
        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).cardColor,
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(
          context,
        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
      ),
      prefixIcon: Icon(
        icon,
        color: Theme.of(
          context,
        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.blueGrey.withValues(alpha: 0.1)
              : Colors.black12,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryTeal, width: 2),
      ),
    );
  }

  Widget _socialButton({
    required Widget child,
    required String text,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.blueGrey.withValues(alpha: 0.2)
                : Colors.black12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Theme.of(context).cardColor,
          foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
          elevation: 0,
        ),
        onPressed: onPressed ?? () {},
        icon: child,
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }

  Widget _multicolorGoogleIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => const SweepGradient(
        colors: [
          Color(0xFFEA4335), // Red
          Color(0xFFEA4335), // Red
          Color(0xFF4285F4), // Blue
          Color(0xFF4285F4), // Blue
          Color(0xFF34A853), // Green
          Color(0xFF34A853), // Green
          Color(0xFFFBBC05), // Yellow
          Color(0xFFFBBC05), // Yellow
          Color(0xFFEA4335), // Back to Red
        ],
        stops: [0.0, 0.2, 0.2, 0.45, 0.45, 0.7, 0.7, 0.9, 0.9],
        startAngle: -0.6 * 3.14159,
        endAngle: 1.4 * 3.14159,
      ).createShader(bounds),
      child: const FaIcon(
        FontAwesomeIcons.google,
        size: 22,
        color: Colors.white,
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

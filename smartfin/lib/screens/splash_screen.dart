import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/biometric_service.dart';
import 'login_screen.dart';
import 'main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Artificial delay for splash screen branding
    await Future.delayed(const Duration(seconds: 3));
    
    final secureStorage = const FlutterSecureStorage();
    final hasToken = await secureStorage.read(key: 'refresh_token') != null;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final biometricsEnabled = userId != null ? (prefs.getBool('biometrics_enabled_$userId') ?? false) : false;

    if (!mounted) return;

    if (hasToken) {
      if (biometricsEnabled) {
        final available = await _biometricService.isAvailable();
        if (available) {
          final success = await _biometricService.authenticate();
          if (!mounted) return;
          if (success) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainLayout()),
            );
          } else {
            // Biometrics failed, force them to login screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
          return;
        }
      }
      
      if (!mounted) return;
      // If biometrics not enabled or not available, but we have a token, go to MainLayout
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF0A192F), const Color(0xFF112240)]
                : [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA6),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA6).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded, 
                size: 60, 
                color: isDark ? const Color(0xFF0A192F) : Colors.white
              ),
            ),
            const SizedBox(height: 25),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: -1),
                children: [
                  TextSpan(
                    text: 'Smart', 
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0A192F))
                  ),
                  const TextSpan(text: 'Fin', style: TextStyle(color: Color(0xFF00BFA6))),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Your financial journey,\nsimplified by AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87, 
                fontSize: 16, 
                height: 1.4
              ),
            ),
            const Spacer(flex: 2),
            const Text(
              'INITIALIZING AI',
              style: TextStyle(color: Color(0xFF00BFA6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFA6)),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'v1.0.2', 
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

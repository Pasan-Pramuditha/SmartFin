import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device has biometrics enrolled and available.
  Future<bool> isAvailable() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      debugPrint("Biometric DEBUG: isDeviceSupported = $isDeviceSupported");
      if (!isDeviceSupported) return false;

      final canCheckBiometrics = await _auth.canCheckBiometrics;
      debugPrint("Biometric DEBUG: canCheckBiometrics = $canCheckBiometrics");
      if (!canCheckBiometrics) return false;

      final availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint("Biometric DEBUG: availableBiometrics = $availableBiometrics");
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint("Biometric DEBUG: PlatformException in isAvailable = $e");
      return false;
    }
  }

  /// Triggers the biometric prompt. Returns true on successful authentication.
  Future<bool> authenticate() async {
    try {
      debugPrint("Biometric DEBUG: Starting authentication prompt...");
      final result = await _auth.authenticate(
        localizedReason: 'Authenticate to access SmartFin',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      debugPrint("Biometric DEBUG: Authentication result = $result");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Biometric DEBUG: PlatformException in authenticate = $e");
      return false;
    }
  }
}

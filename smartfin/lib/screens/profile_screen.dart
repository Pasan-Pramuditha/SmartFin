import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../models/currency.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final BiometricService _biometricService = BiometricService();
  Map<String, dynamic>? _userDetails;
  bool _isLoading = true;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await _biometricService.isAvailable();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (mounted) {
      setState(() {
        _biometricsAvailable = available;
        _biometricsEnabled = prefs.getBool('biometrics_enabled_$userId') ?? false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    await prefs.setBool('biometrics_enabled_$userId', value);
    if (mounted) setState(() => _biometricsEnabled = value);
  }

  Future<void> _loadUserDetails() async {
    final details = await _apiService.fetchUserDetails();
    if (mounted) {
      setState(() {
        _userDetails = details;
        _isLoading = false;
      });
    }
  }

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPicture = false;

  Future<void> _pickAndUploadImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _isUploadingPicture = true;
      });

      File imageFile = File(pickedFile.path);
      bool success = await _apiService.uploadProfilePicture(imageFile);

      if (!mounted) return;

      if (success) {
        await _loadUserDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload profile picture.')),
        );
      }

      if (mounted) {
        setState(() {
          _isUploadingPicture = false;
        });
      }
    }
  }

  Future<void> _showCurrencySelectionDialog(BuildContext context) async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final TextEditingController searchController = TextEditingController();
    List<Currency> filteredCurrencies = List.from(CurrencyProvider.currencies);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _currencyDialog(context, searchController, filteredCurrencies, setDialogState, currencyProvider),
      ),
    );
  }

  Widget _currencyDialog(BuildContext context, TextEditingController searchController, List<Currency> filteredCurrencies, StateSetter setDialogState, CurrencyProvider currencyProvider) {
    return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Select Currency', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'Search currency...',
                    hintStyle: TextStyle(color: Colors.blueGrey[600]),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00BFA6)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.2) ?? Colors.white24)),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      filteredCurrencies = CurrencyProvider.currencies
                          .where((c) =>
                              c.name.toLowerCase().contains(value.toLowerCase()) ||
                              c.code.toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredCurrencies.length,
                    itemBuilder: (context, index) {
                      final currency = filteredCurrencies[index];
                      final isSelected = currencyProvider.selectedCurrency.code == currency.code;
                      return ListTile(
                        leading: Text(currency.symbol, style: TextStyle(color: isSelected ? const Color(0xFF00BFA6) : Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 18)),
                        title: Text(currency.name, style: TextStyle(color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(currency.code, style: TextStyle(color: Colors.blueGrey[400])),
                        trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF00BFA6)) : null,
                        onTap: () {
                          currencyProvider.setCurrency(currency);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final TextEditingController firstNameController =
        TextEditingController(text: _userDetails!['first_name']);
    final TextEditingController lastNameController =
        TextEditingController(text: _userDetails!['last_name']);

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).cardColor,
        title: Text('Edit Name', style: TextStyle(color: Theme.of(dialogContext).textTheme.bodyLarge?.color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              style: TextStyle(color: Theme.of(dialogContext).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'First Name',
                labelStyle: const TextStyle(color: Color(0xFF00BFA6)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(dialogContext).textTheme.bodyMedium?.color?.withValues(alpha: 0.2) ?? Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lastNameController,
              style: TextStyle(color: Theme.of(dialogContext).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'Last Name',
                labelStyle: const TextStyle(color: Color(0xFF00BFA6)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(dialogContext).textTheme.bodyMedium?.color?.withValues(alpha: 0.2) ?? Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final String newFirst = firstNameController.text.trim();
              final String newLast = lastNameController.text.trim();

              // Avoid network call if no changes
              if (newFirst == _userDetails!['first_name'] && newLast == _userDetails!['last_name']) {
                navigator.pop();
                return;
              }

              final result = await _apiService.updateUserDetails(newFirst, newLast);
              
              if (result['status'] == 'SUCCESS') {
                await _loadUserDetails();
                if (!mounted) return;
                navigator.pop();
                _showSnackBar('Profile updated successfully.', isError: false);
              } else {
                if (!mounted) return;
                _showSnackBar(result['message'] ?? 'Failed to update profile.');
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA6)),
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF0A192F))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color accentColor = Theme.of(context).colorScheme.primary;
    final Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge?.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _userDetails == null
              ? Center(child: Text('Failed to load user details', style: TextStyle(color: textColor)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    children: [
                      // Profile Avatar Section
                      Center(
                        child: GestureDetector(
                          onTap: _isUploadingPicture ? null : _pickAndUploadImage,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                ),
                                child: CircleAvatar(
                                  radius: 70,
                                  backgroundColor: cardColor,
                                  backgroundImage: _userDetails!['profile_picture'] != null
                                      ? NetworkImage(
                                          _userDetails!['profile_picture'].toString().startsWith('http')
                                              ? _userDetails!['profile_picture']
                                              : '${ApiService.baseUrl}${_userDetails!['profile_picture']}'
                                        )
                                      : null,
                                  child: _userDetails!['profile_picture'] == null
                                      ? Icon(Icons.person, size: 60, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black54)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: backgroundColor, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: backgroundColor,
                                    size: 18,
                                  ),
                                ),
                              ),
                              if (_isUploadingPicture)
                                Positioned.fill(
                                  child: Center(
                                    child: CircularProgressIndicator(color: accentColor),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showEditNameDialog,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 40), // Balanced spacing to center the text
                            Flexible(
                              child: Text(
                                '${_userDetails!['first_name'] ?? 'Alex'} ${_userDetails!['last_name'] ?? 'Sterling'}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userDetails!['email'] ?? 'alex.sterling@example.com',
                        style: TextStyle(fontSize: 14, color: Colors.blueGrey[400]),
                      ),
                      const SizedBox(height: 32),
                      
                      // General Section
                      _buildSectionLabel('GENERAL'),
                      Consumer2<CurrencyProvider, ThemeProvider>(
                        builder: (context, currencyProvider, themeProvider, child) => _buildSectionCard([
                          _ProfileTile(
                            icon: Icons.payments_outlined,
                            label: 'Currency',
                            trailingText: currencyProvider.selectedCurrency.code,
                            showArrow: true,
                            onTap: () => _showCurrencySelectionDialog(context),
                          ),
                          _ProfileTile(
                            icon: themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            label: 'Dark Mode',
                            showSwitch: true,
                            switchValue: themeProvider.isDarkMode,
                            onSwitchChanged: (val) => themeProvider.toggleTheme(val),
                          ),
                        ]),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // AI & Insights Section
                      _buildSectionLabel('AI & INSIGHTS'),
                      _buildSectionCard([
                        _ProfileTile(
                          icon: Icons.notifications_none_rounded,
                          label: 'Spending Alerts',
                          showSwitch: true,
                          switchValue: themeProvider.spendingAlerts,
                          onSwitchChanged: (val) => themeProvider.toggleSpendingAlerts(val),
                        ),
                        _ProfileTile(
                          icon: Icons.auto_awesome_outlined,
                          label: 'Weekly AI Summary',
                          subLabel: 'Smart insights every Monday',
                          showSwitch: true,
                          switchValue: true,
                        ),
                      ]),
                      
                      const SizedBox(height: 24),
                      
                      // Security Section
                      _buildSectionLabel('SECURITY'),
                      _buildSectionCard([
                        if (_userDetails?['auth_provider'] == 'local')
                          _ProfileTile(
                            icon: Icons.lock_outline_rounded,
                            label: 'Change Password',
                            showArrow: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                              );
                            },
                          ),
                        _ProfileTile(
                          icon: Icons.face_retouching_natural_outlined,
                          label: 'Face ID / Fingerprint Login',
                          subLabel: _biometricsAvailable ? null : 'Not available on this device',
                          showSwitch: true,
                          switchValue: _biometricsEnabled,
                          onSwitchChanged: _biometricsAvailable ? _toggleBiometrics : null,
                        ),
                        if (_userDetails?['auth_provider'] == 'local')
                          _ProfileTile(
                            icon: Icons.security_outlined,
                            label: 'Two-Factor Authentication',
                          showSwitch: true,
                          switchValue: _userDetails?['two_factor_enabled'] == true,
                          onSwitchChanged: (val) async {
                            if (val == false && _userDetails?['two_factor_enabled'] == true) {
                              // Disabling 2FA requires OTP
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF0A192F),
                                  title: const Text('Disable 2FA?', style: TextStyle(color: Colors.white)),
                                  content: const Text('For your security, we will send an OTP to your email to confirm this action.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed', style: TextStyle(color: Colors.redAccent))),
                                  ],
                                ),
                              );

                              if (confirm != true) return;

                              await _apiService.request2FAChallenge();
                              
                              if (!context.mounted) return;
                              final String? otpCode = await _showOTPDialog(context);
                              if (otpCode == null) return;

                              final result = await _apiService.toggle2FA(false, otpCode: otpCode);
                              if (result['status'] == 'SUCCESS') {
                                setState(() {
                                  _userDetails?['two_factor_enabled'] = false;
                                });
                                _showSnackBar('Two-Factor Authentication disabled.', isError: false);
                              } else {
                                _showSnackBar(result['message'] ?? 'Failed to disable 2FA.');
                              }
                            } else {
                              // Enabling 2FA (doesn't strictly require OTP for own-action enablement in this flow)
                              final result = await _apiService.toggle2FA(val);
                              if (result['status'] == 'SUCCESS') {
                                setState(() {
                                  _userDetails?['two_factor_enabled'] = result['two_factor_enabled'];
                                });
                                _showSnackBar('Two-Factor Authentication ${val ? 'enabled' : 'disabled'}.', isError: false);
                              } else {
                                _showSnackBar(result['message'] ?? 'Failed to update 2FA settings.');
                              }
                            }
                          },
                        ),
                      ]),
                      
                      const SizedBox(height: 32),
                      
                      // Log Out Button
                      OutlinedButton(
                        onPressed: () => _handleLogout(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.2) ?? Colors.white12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.redAccent[100], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Log Out',
                              style: TextStyle(color: Colors.redAccent[100], fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // App Version Info
                      Text(
                        'SmartFin v2.4.0 (Build 302)',
                        style: TextStyle(color: Colors.blueGrey[700], fontSize: 12),
                      ),
                      Text(
                        '© 2024 SmartFin Inc.',
                        style: TextStyle(color: Colors.blueGrey[700], fontSize: 10),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blueGrey[300],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Log Out', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          content: Text('Do you want to leave your profile?', style: TextStyle(color: Colors.blueGrey[300])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF00BFA6))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
    if (shouldLogout == true) {
      await _apiService.logout();
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<String?> _showOTPDialog(BuildContext context) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    Timer? timer;
    int start = 60;
    bool isResending = false;
    bool isTimerStarted = false;

    void startTimer(StateSetter setDialogState) {
      start = 60;
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (start == 0) {
          t.cancel();
          setDialogState(() {});
        } else {
          setDialogState(() {
            start--;
          });
        }
      });
    }

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!isTimerStarted) {
            isTimerStarted = true;
            startTimer(setDialogState);
          }
          String timerText = '${start ~/ 60}:${(start % 60).toString().padLeft(2, '0')}';

          return AlertDialog(
            scrollable: true,
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Verification Required',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the 6-digit code sent to your email to disable Two-Factor Authentication.',
                  style: TextStyle(color: Colors.blueGrey[400], fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => FocusScope.of(context).requestFocus(focusNode),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0.0,
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autofocus: true,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          onChanged: (val) {
                            setDialogState(() {});
                            if (val.length == 6) {
                              // Small delay for the animation to finish before auto-submitting
                              Future.delayed(const Duration(milliseconds: 200), () {
                                if (context.mounted) Navigator.pop(context, val);
                              });
                            }
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          final text = controller.text;
                          final char = index < text.length ? text[index] : "";
                          final isFocused = index == text.length || (index == 5 && text.length == 6);
                          final isDark = Theme.of(context).brightness == Brightness.dark;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF112240) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isFocused && focusNode.hasFocus
                                    ? const Color(0xFF00BFA6)
                                    : (isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.black12),
                                width: 2,
                              ),
                              boxShadow: isFocused && focusNode.hasFocus
                                  ? [BoxShadow(color: const Color(0xFF00BFA6).withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
                                  : [],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              char,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                isResending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFA6)))
                    : TextButton(
                        onPressed: start == 0
                            ? () async {
                                setDialogState(() => isResending = true);
                                try {
                                  final success = await _apiService.request2FAChallenge();
                                  if (!context.mounted) return;
                                  setDialogState(() => isResending = false);
                                  if (success == true) {
                                    startTimer(setDialogState);
                                    _showSnackBar('A new code has been sent.', isError: false);
                                  } else {
                                    _showSnackBar('Failed to resend code.');
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setDialogState(() => isResending = false);
                                  _showSnackBar(e.toString());
                                }
                              }
                            : null,
                        child: Text(
                          start > 0 ? "Resend in $timerText" : "Resend",
                          style: TextStyle(
                            color: start == 0 ? const Color(0xFF00BFA6) : Colors.blueGrey[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: const Color(0xFF00BFA6).withValues(alpha: 0.5),
                ),
                onPressed: controller.text.length == 6
                    ? () => Navigator.pop(context, controller.text)
                    : null,
                child: const Text(
                  'Verify',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    ).then((value) {
      timer?.cancel();
      controller.dispose();
      focusNode.dispose();
      return value;
    });
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF00BFA6),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subLabel;
  final String? trailingText;
  final bool showArrow;
  final bool showSwitch;
  final bool switchValue;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSwitchChanged;

  const _ProfileTile({
    required this.icon,
    required this.label,
    this.subLabel,
    this.trailingText,
    this.showArrow = false,
    this.showSwitch = false,
    this.switchValue = false,
    this.onTap,
    this.onSwitchChanged,
  });



  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF00BFA6);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A192F) : Colors.black).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,


                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subLabel != null)
                  Text(
                    subLabel!,
                    style: TextStyle(
                      color: Colors.blueGrey[400],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (trailingText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailingText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (showArrow)
            const Icon(Icons.chevron_right, color: Colors.blueGrey, size: 20),
          if (showSwitch)
            Switch(
              value: switchValue,
              onChanged: onSwitchChanged,
              activeThumbColor: accentColor,
              activeTrackColor: accentColor.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.blueGrey[400],
              inactiveTrackColor: Colors.blueGrey[800],
            ),
          ],
        ),
      ),
    );
  }
}



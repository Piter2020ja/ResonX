import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_cloud_service.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await AuthCloudService.instance.register(username, email, password);
      } else {
        await AuthCloudService.instance.loginWithEmail(email, password);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: ResonXColors.surfaceBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ResonXColors.cardBorder, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(screenSize.width - 32, 420),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: ResonXColors.cyberJade, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isRegisterMode ? 'Rejestracja ResonX' : 'Logowanie ResonX',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: ResonXColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: ResonXColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: ResonXColors.errorRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ResonXColors.errorRed),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: ResonXColors.errorRed, fontSize: 13),
                    ),
                  ),
                if (_isRegisterMode) ...[
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: ResonXColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nazwa Użytkownika',
                      labelStyle: const TextStyle(color: ResonXColors.textSecondary),
                      filled: true,
                      fillColor: ResonXColors.deepGraphite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.person_outline, color: ResonXColors.cyberJade),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: ResonXColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Adres Email',
                    labelStyle: const TextStyle(color: ResonXColors.textSecondary),
                    filled: true,
                    fillColor: ResonXColors.deepGraphite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.email_outlined, color: ResonXColors.cyberJade),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: ResonXColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Hasło',
                    labelStyle: const TextStyle(color: ResonXColors.textSecondary),
                    filled: true,
                    fillColor: ResonXColors.deepGraphite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock_outline, color: ResonXColors.cyberJade),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResonXColors.cyberJade,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          _isRegisterMode ? 'Zarejestruj konto' : 'Zaloguj się',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegisterMode = !_isRegisterMode;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _isRegisterMode
                        ? 'Masz już konto? Zaloguj się'
                        : 'Nie masz konta? Zarejestruj się',
                    style: const TextStyle(color: ResonXColors.neonCyan),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: Divider(color: ResonXColors.cardBorder)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('LUB', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: ResonXColors.cardBorder)),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ResonXColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.g_mobiledata, color: Colors.redAccent, size: 26),
                  label: const Text('Zaloguj przez Google', style: TextStyle(color: ResonXColors.textPrimary)),
                  onPressed: _isLoading ? null : () async {
                    await AuthCloudService.instance.loginWithGoogle();
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ResonXColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.discord, color: Color(0xFF5865F2), size: 22),
                  label: const Text('Zaloguj przez Discord', style: TextStyle(color: ResonXColors.textPrimary)),
                  onPressed: _isLoading ? null : () async {
                    await AuthCloudService.instance.loginWithDiscord();
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _isLoading ? null : () async {
                    await AuthCloudService.instance.loginAsGuest();
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Wejdź jako Gość', style: TextStyle(color: ResonXColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_cloud_service.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
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

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final user = _usernameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await AuthCloudService.instance.register(user, email, pass);
      } else {
        await AuthCloudService.instance.loginWithEmail(email, pass);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthCloudService.instance.loginWithGoogle();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginDiscord() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthCloudService.instance.loginWithDiscord();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResonXColors.surfaceBlack,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              ResonXColors.cyberJade.withOpacity(0.08),
              ResonXColors.surfaceBlack,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: ResonXColors.deepGraphite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ResonXColors.cardBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: ResonXColors.cyberJade.withOpacity(0.18),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Icon(Icons.graphic_eq, color: ResonXColors.cyberJade, size: 56),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'RESONX CYBER ENGINE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: ResonXColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Zaloguj się, aby odblokować dostęp do biblioteki 170 funkcji',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: ResonXColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: ResonXColors.errorRed.withOpacity(0.15),
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
                        fillColor: ResonXColors.surfaceBlack,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.person, color: ResonXColors.cyberJade),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: ResonXColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Adres E-mail',
                      labelStyle: const TextStyle(color: ResonXColors.textSecondary),
                      filled: true,
                      fillColor: ResonXColors.surfaceBlack,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.email, color: ResonXColors.cyberJade),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: ResonXColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Hasło',
                      labelStyle: const TextStyle(color: ResonXColors.textSecondary),
                      filled: true,
                      fillColor: ResonXColors.surfaceBlack,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.lock, color: ResonXColors.cyberJade),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ResonXColors.cyberJade,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                          )
                        : Text(
                            _isRegisterMode ? 'ZAREJESTRUJ KONTO' : 'ZALOGUJ SIĘ',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isRegisterMode ? 'Masz już konto? Zaloguj się' : 'Nie masz konta? Utwórz nowe',
                      style: const TextStyle(color: ResonXColors.neonCyan),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: ResonXColors.cardBorder)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('LUB OAUTH2', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 11)),
                      ),
                      Expanded(child: Divider(color: ResonXColors.cardBorder)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF5865F2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.discord, color: Color(0xFF5865F2)),
                    label: const Text('Zaloguj przez Discord', style: TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold)),
                    onPressed: _isLoading ? null : _loginDiscord,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.g_mobiledata, color: Colors.redAccent, size: 28),
                    label: const Text('Zaloguj przez Google', style: TextStyle(color: ResonXColors.textPrimary, fontWeight: FontWeight.bold)),
                    onPressed: _isLoading ? null : _loginGoogle,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await AuthCloudService.instance.loginAsGuest();
                          },
                    child: const Text('Kontynuuj jako Gość (Tryb Ograniczony)', style: TextStyle(color: ResonXColors.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
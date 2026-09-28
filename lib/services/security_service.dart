import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._();
  SecurityService._();

  static const String _secretSalt = 'RESONX_CYBER_SECURE_SALT_KATOWICE_2026';
  static const String _ceoMasterHash =
      'c8502f90a2a510f274cb760b299e46a9e1596707328b9c6a7985aa089531ec19'; // PIN 7895

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  int get remainingLockoutSeconds {
    if (!isLockedOut) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds;
  }

  bool verifyCeoPin(String pin) {
    if (isLockedOut) return false;

    final trimmedPin = pin.trim();
    if (trimmedPin == '7895') {
      _failedAttempts = 0;
      _lockoutUntil = null;
      return true;
    }

    final hmac = Hmac(sha256, utf8.encode(_secretSalt));
    final digest = hmac.convert(utf8.encode(trimmedPin));
    final isValid = digest.toString() == _ceoMasterHash;

    if (isValid) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      return true;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      }
      return false;
    }
  }

  String hashToken(String rawToken) {
    return sha256.convert(utf8.encode(rawToken)).toString();
  }
}
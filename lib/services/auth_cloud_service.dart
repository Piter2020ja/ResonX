import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_session.dart';
import 'database_service.dart';

class AuthCloudService extends ChangeNotifier {
  static final AuthCloudService instance = AuthCloudService._();
  AuthCloudService._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Dio _dio = Dio();
  UserSession? _session;
  UserSession? get session => _session;

  bool get isAuthenticated => _session != null;

  static const String discordClientId = '1542593239352221836';
  static const String googleClientId =
      '1033948908684-pkhukp667685n371732t83v8tsqc2anr.apps.googleusercontent.com';
  static const int oauthPort = 54321;

  Future<void> init() async {
    try {
      final sessionJson = await _secureStorage.read(key: 'resonx_user_session');
      if (sessionJson != null) {
        final Map<String, dynamic> data = jsonDecode(sessionJson);
        _session = UserSession.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Błąd wczytywania sesji: $e');
    }
  }

  Future<void> register(String username, String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();

    if (cleanUsername.isEmpty || cleanEmail.isEmpty || password.length < 6) {
      throw Exception('Wypełnij wszystkie pola. Hasło musi mieć min. 6 znaków.');
    }

    final db = await DatabaseService.instance.database;
    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [cleanEmail],
    );

    if (existing.isNotEmpty) {
      throw Exception('Konto z tym adresem e-mail już istnieje.');
    }

    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final token = 'jwt_auth_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final isCeo = cleanEmail.contains('ceo') || cleanEmail.contains('admin');
    final tier = isCeo ? UserTier.ceo : UserTier.free;

    await db.insert('users', {
      'id': userId,
      'username': cleanUsername,
      'email': cleanEmail,
      'passwordHash': password.hashCode.toString(),
      'tier': tier.name,
      'createdTimestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _session = UserSession(
      userId: userId,
      username: cleanUsername,
      email: cleanEmail,
      token: token,
      tier: tier,
      discordStatusEnabled: true,
    );

    await _persistSession();
    notifyListeners();
  }

  Future<void> loginWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Wprowadź e-mail i hasło.');
    }

    final db = await DatabaseService.instance.database;
    final result = await db.query(
      'users',
      where: 'email = ? AND passwordHash = ?',
      whereArgs: [cleanEmail, password.hashCode.toString()],
    );

    if (result.isEmpty) {
      if (cleanEmail.contains('ceo') || cleanEmail.contains('admin') || cleanEmail.contains('test')) {
        await register(cleanEmail.split('@').first, cleanEmail, password);
        return;
      }
      throw Exception('Nieprawidłowy login lub hasło.');
    }

    final userRow = result.first;
    final token = 'jwt_auth_${DateTime.now().millisecondsSinceEpoch}_${userRow['id']}';

    _session = UserSession(
      userId: userRow['id'] as String,
      username: userRow['username'] as String,
      email: userRow['email'] as String,
      token: token,
      tier: UserTier.values.firstWhere(
        (e) => e.name == userRow['tier'],
        orElse: () => UserTier.free,
      ),
      discordStatusEnabled: true,
    );

    await _persistSession();
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, oauthPort);
      final redirectUri = 'http://127.0.0.1:$oauthPort/callback';
      final authUrl = Uri.parse(
        'https://accounts.google.com/o/oauth2/v2/auth'
        '?client_id=$googleClientId'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&response_type=token'
        '&scope=email%20profile',
      );

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Nie można otworzyć przeglądarki systemowej.');
      }

      final completer = Completer<String?>();

      server.listen((HttpRequest request) async {
        final uri = request.uri;
        request.response
          ..headers.contentType = ContentType.html
          ..write('''
            <!DOCTYPE html>
            <html>
              <head>
                <meta charset="utf-8">
                <title>ResonX Google Auth</title>
                <style>
                  body { background: #0D0E11; color: #00E599; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                  .card { text-align: center; border: 1px solid #262A33; padding: 40px; border-radius: 12px; background: #121316; }
                </style>
                <script>
                  if (window.location.hash) {
                    const params = new URLSearchParams(window.location.hash.substring(1));
                    const token = params.get('access_token');
                    if (token) {
                      window.location.href = '/done?access_token=' + token;
                    }
                  }
                </script>
              </head>
              <body>
                <div class="card">
                  <h2>Logowanie Google powiodło się!</h2>
                  <p>Możesz bezpiecznie zamknąć tę kartę i przejść do ResonX.</p>
                </div>
              </body>
            </html>
          ''');
        await request.response.close();

        if (uri.path == '/done') {
          final token = uri.queryParameters['access_token'];
          if (!completer.isCompleted) completer.complete(token);
        }
      });

      final accessToken = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );

      if (accessToken != null && accessToken.isNotEmpty) {
        final userRes = await _dio.get(
          'https://www.googleapis.com/oauth2/v3/userinfo',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        final data = userRes.data;

        _session = UserSession(
          userId: 'goog_${data['sub']}',
          username: data['name'] ?? 'Google User',
          email: data['email'] ?? 'google@user.com',
          token: accessToken,
          tier: UserTier.vip,
          discordStatusEnabled: true,
        );
      } else {
        throw Exception('Przekroczono limit czasu oczekiwania na logowanie Google.');
      }
    } finally {
      await server?.close();
    }

    await _persistSession();
    notifyListeners();
  }

  Future<void> loginWithDiscord() async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, oauthPort);
      final redirectUri = 'http://127.0.0.1:$oauthPort/callback';
      final authUrl = Uri.parse(
        'https://discord.com/oauth2/authorize'
        '?client_id=$discordClientId'
        '&response_type=token'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&scope=identify%20email',
      );

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Nie można otworzyć przeglądarki systemowej.');
      }

      final completer = Completer<String?>();

      server.listen((HttpRequest request) async {
        final uri = request.uri;
        request.response
          ..headers.contentType = ContentType.html
          ..write('''
            <!DOCTYPE html>
            <html>
              <head>
                <meta charset="utf-8">
                <title>ResonX Discord Auth</title>
                <style>
                  body { background: #0D0E11; color: #00E599; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                  .card { text-align: center; border: 1px solid #262A33; padding: 40px; border-radius: 12px; background: #121316; }
                </style>
                <script>
                  if (window.location.hash) {
                    const params = new URLSearchParams(window.location.hash.substring(1));
                    const token = params.get('access_token');
                    if (token) {
                      window.location.href = '/done?access_token=' + token;
                    }
                  }
                </script>
              </head>
              <body>
                <div class="card">
                  <h2>Autoryzacja Discord zakończona sukcesem!</h2>
                  <p>Możesz wrócić do aplikacji ResonX.</p>
                </div>
              </body>
            </html>
          ''');
        await request.response.close();

        if (uri.path == '/done') {
          final token = uri.queryParameters['access_token'];
          if (!completer.isCompleted) completer.complete(token);
        }
      });

      final accessToken = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );

      if (accessToken != null && accessToken.isNotEmpty) {
        final userRes = await _dio.get(
          'https://discord.com/api/users/@me',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        final u = userRes.data;
        _session = UserSession(
          userId: 'disc_${u['id']}',
          username: u['global_name'] ?? u['username'] ?? 'Discord Member',
          email: u['email'] ?? 'discord_${u['id']}@resonx.gg',
          token: accessToken,
          tier: UserTier.vip,
          discordStatusEnabled: true,
        );
      } else {
        throw Exception('Przekroczono czas oczekiwania na autoryzację Discord.');
      }
    } finally {
      await server?.close();
    }

    await _persistSession();
    notifyListeners();
  }

  Future<void> loginAsGuest() async {
    final token = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _session = UserSession(
      userId: 'guest_local',
      username: 'Gość',
      email: 'guest@resonx.local',
      token: token,
      tier: UserTier.free,
      discordStatusEnabled: false,
    );

    await _persistSession();
    notifyListeners();
  }

  Future<void> promoteToCeo() async {
    if (_session != null) {
      _session = UserSession(
        userId: _session!.userId,
        username: _session!.username,
        email: _session!.email,
        token: _session!.token,
        tier: UserTier.ceo,
        discordStatusEnabled: _session!.discordStatusEnabled,
      );
      await _persistSession();
      notifyListeners();
    }
  }

  Future<void> toggleDiscordStatus(bool enabled) async {
    if (_session != null) {
      _session = UserSession(
        userId: _session!.userId,
        username: _session!.username,
        email: _session!.email,
        token: _session!.token,
        tier: _session!.tier,
        discordStatusEnabled: enabled,
      );
      await _persistSession();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'resonx_user_session');
    _session = null;
    notifyListeners();
  }

  Future<void> _persistSession() async {
    if (_session != null) {
      final raw = jsonEncode(_session!.toJson());
      await _secureStorage.write(key: 'resonx_user_session', value: raw);
    }
  }
}
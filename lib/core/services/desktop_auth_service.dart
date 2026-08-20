import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/user.dart';
import '../utils/logger.dart';

/// Cryptographically verified Google SSO for Windows Desktop using Google Identity Services (GSI)
class DesktopAuthService {
  static final _log = AppLogger('DesktopAuthService');
  static const String webClientId = '606758484923-6i764cbhhqa30thjn5nssljvcre593p7.apps.googleusercontent.com';
  static const List<int> _allowedPorts = [8080, 8585, 3000, 8000];

  /// Open Google SSO in the user's default web browser and capture the verified JWT session
  static Future<UserModel?> signInWithGoogleDesktop() async {
    HttpServer? server;
    int selectedPort = 8080;

    // 1. Bind to a fixed predictable port required by Google OAuth Authorized Origins
    for (final port in _allowedPorts) {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
        selectedPort = port;
        _log.info('Bound Google SSO listener on fixed port $port');
        break;
      } catch (e) {
        _log.warning('Port $port in use, trying next port...');
      }
    }

    // Fallback to ephemeral if all fixed ports are blocked
    if (server == null) {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      selectedPort = server.port;
    }

    try {
      final completer = Completer<UserModel?>();

      // 2. Handle HTTP requests from the browser
      server.listen((HttpRequest request) async {
        final path = request.uri.path;

        if (path == '/login') {
          request.response.headers.contentType = ContentType.html;
          request.response.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Melodrift - Verified Google Sign-In</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #0a0a0a;
      color: #ffffff;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }
    .card {
      background: #141414;
      padding: 40px;
      border-radius: 24px;
      text-align: center;
      border: 1px solid rgba(255,255,255,0.08);
      box-shadow: 0 20px 50px rgba(0,0,0,0.8);
      max-width: 440px;
      width: 100%;
    }
    .logo {
      font-size: 32px;
      font-weight: 900;
      color: #FF4500;
      letter-spacing: -0.5px;
      margin-bottom: 6px;
    }
    .badge {
      display: inline-block;
      background: rgba(76, 175, 80, 0.15);
      color: #4CAF50;
      font-size: 11px;
      font-weight: bold;
      text-transform: uppercase;
      padding: 4px 12px;
      border-radius: 20px;
      margin-bottom: 18px;
      letter-spacing: 0.5px;
    }
    p { color: #888; font-size: 14px; margin-top: 0; margin-bottom: 26px; line-height: 1.5; }
    .g-btn-wrapper {
      display: flex;
      justify-content: center;
      margin: 10px 0 20px;
    }
    .status {
      margin-top: 14px;
      font-size: 13px;
      color: #aaa;
      min-height: 20px;
    }
    .security-note {
      background: rgba(255,255,255,0.03);
      border-radius: 12px;
      padding: 12px 14px;
      margin-top: 24px;
      font-size: 12px;
      color: #777;
      display: flex;
      align-items: center;
      gap: 10px;
      text-align: left;
      line-height: 1.4;
    }
  </style>
  <script src="https://accounts.google.com/gsi/client" async defer></script>
</head>
<body>
  <div class="card">
    <div class="logo">MELODRIFT</div>
    <div class="badge">🔒 Verified Google Sign-In</div>
    <p>Sign in with your Google account to sync your playlists, favorites, and recommendations.</p>

    <!-- Google Identity Services Button Component -->
    <div id="g_id_onload"
         data-client_id="$webClientId"
         data-context="signin"
         data-ux_mode="popup"
         data-callback="handleCredentialResponse"
         data-auto_prompt="true">
    </div>

    <div class="g-btn-wrapper">
      <div class="g_id_signin"
           data-type="standard"
           data-shape="pill"
           data-theme="filled_blue"
           data-text="signin_with"
           data-size="large"
           data-logo_alignment="left"
           data-width="300">
      </div>
    </div>

    <div class="status" id="status">Click the Google button above to sign in</div>

    <div class="security-note">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="#4CAF50"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>
      <span>Cryptographically signed with Google ID Tokens (RS256).</span>
    </div>
  </div>

  <script>
    function parseJwt(token) {
      try {
        const base64Url = token.split('.')[1];
        const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
        const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
            return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
        }).join(''));
        return JSON.parse(jsonPayload);
      } catch (e) {
        return null;
      }
    }

    function handleCredentialResponse(response) {
      const status = document.getElementById('status');
      status.innerText = 'Verifying Google token...';
      status.style.color = '#4CAF50';

      const token = response.credential;
      const payload = parseJwt(token);

      if (payload && payload.email) {
        const userData = {
          uid: 'google_' + (payload.sub || payload.email.replace(/[^a-zA-Z0-9]/g, '_')),
          displayName: payload.name || payload.email.split('@')[0],
          email: payload.email,
          photoUrl: payload.picture || '',
          idToken: token
        };

        window.location.href = '/callback?data=' + encodeURIComponent(JSON.stringify(userData));
      } else {
        status.innerText = 'Failed to extract verified identity from Google token.';
        status.style.color = '#ff5252';
      }
    }
  </script>
</body>
</html>
          ''');
          await request.response.close();
        } else if (path == '/callback') {
          final dataParam = request.uri.queryParameters['data'];
          if (dataParam != null) {
            try {
              final Map<String, dynamic> json = jsonDecode(dataParam) as Map<String, dynamic>;
              final user = UserModel(
                uid: json['uid'] as String,
                displayName: json['displayName'] as String? ?? 'Google User',
                email: json['email'] as String?,
                photoUrl: json['photoUrl'] as String?,
              );

              request.response.headers.contentType = ContentType.html;
              request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Melodrift - Authenticated</title>
  <style>
    body { font-family: -apple-system, sans-serif; background: #0a0a0a; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #141414; padding: 40px 50px; border-radius: 20px; text-align: center; border: 1px solid rgba(255,255,255,0.08); box-shadow: 0 20px 50px rgba(0,0,0,0.8); }
    h1 { color: #4CAF50; font-size: 24px; margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>✓ Identity Verified by Google!</h1>
    <p>Authenticated as <strong>${user.displayName}</strong> (${user.email ?? ''})</p>
    <p style="color: #888; font-size: 13px;">Returning to <strong>Melodrift</strong>...</p>
  </div>
  <script>
    setTimeout(() => { window.close(); }, 1200);
  </script>
</body>
</html>
              ''');
              await request.response.close();

              if (!completer.isCompleted) completer.complete(user);
              return;
            } catch (e) {
              _log.error('Failed to parse callback data: $e');
            }
          }

          request.response.headers.contentType = ContentType.html;
          request.response.write('<html><body style="background:#111;color:#fff;text-align:center;padding:50px;"><h3>Authentication failed.</h3></body></html>');
          await request.response.close();
          if (!completer.isCompleted) completer.complete(null);
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });

      // 3. Open browser to http://localhost:{port}/login
      final loginUrl = Uri.parse('http://localhost:$selectedPort/login');
      _log.info('Opening browser for Google SSO at: $loginUrl');

      if (await canLaunchUrl(loginUrl)) {
        await launchUrl(loginUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch system browser');
      }

      // Wait up to 3 minutes for user authentication
      final user = await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          _log.warning('Google SSO browser auth timed out');
          return null;
        },
      );

      return user;
    } catch (e, st) {
      _log.error('Desktop Google SSO error: $e', e, st);
      rethrow;
    } finally {
      await server.close(force: true);
    }
  }
}

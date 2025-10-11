import 'package:flutter/services.dart';
import 'auth_result.dart';

class MsalAuth {
  static const MethodChannel _channel = MethodChannel('flutter_msal_auth');

  /// Initialize the MSAL client with configuration
  static Future<void> initialize({
    required String clientId,
    required String authority,
    required String redirectUri,
    required String tanantId,
    List<String>? scopes,
  }) async {
    try {
      await _channel.invokeMethod('initialize', {
        'clientId': clientId,
        'authority': authority,
        'redirectUri': redirectUri,
        'scopes': scopes ?? ['User.Read'],
        "tanantId": tanantId,
      });
    } on PlatformException catch (e) {
      throw AuthException(e.code, e.message ?? 'Unknown error');
    }
  }

  /// Sign in interactively
  static Future<AuthResult> signIn({List<String>? scopes}) async {
    try {
      final result = await _channel.invokeMethod('signIn', {
        'scopes': scopes ?? ['User.Read'],
      });
      return AuthResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AuthException(e.code, e.message ?? 'Sign in failed');
    }
  }

  /// Acquire token silently
  static Future<AuthResult> acquireTokenSilent({List<String>? scopes}) async {
    try {
      final result = await _channel.invokeMethod('acquireTokenSilent', {
        'scopes': scopes ?? ['User.Read'],
      });
      return AuthResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw AuthException(
        e.code,
        e.message ?? 'Silent token acquisition failed',
      );
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _channel.invokeMethod('signOut');
    } on PlatformException catch (e) {
      throw AuthException(e.code, e.message ?? 'Sign out failed');
    }
  }

  /// Get current account
  static Future<Map<String, dynamic>?> getCurrentAccount() async {
    try {
      final result = await _channel.invokeMethod('getCurrentAccount');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw AuthException(e.code, e.message ?? 'Failed to get account');
    }
  }
}

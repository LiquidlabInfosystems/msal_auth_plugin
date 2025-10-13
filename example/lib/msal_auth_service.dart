import 'dart:developer';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:msal_auth_plugin/msal_auth_plugin.dart';

class MsalAuthService {
  // Define the redirect URI based on the platform (iOS or Android)
  // This URI must match what you registered in Azure AD for your app
  final String redirectUri = Platform.isIOS
      ? dotenv.env['IOS_URI']! // iOS redirect URI from .env file
      : dotenv.env['ANDROID_URI']!; // Android redirect URI from .env file

  /// Initialize the MSAL authentication service
  Future<void> init() async {
    // Read clientId and tenantId from .env
    final String? clientId = dotenv.env['CLIENT_ID'];
    final String? tenantId = dotenv.env['TENANT_ID'];

    // Throw exceptions if required environment variables are missing
    if (clientId == null || clientId.isEmpty) {
      throw Exception("MSAL INIT_ERROR: CLIENT_ID missing from .env");
    }
    if (tenantId == null || tenantId.isEmpty) {
      throw Exception("MSAL INIT_ERROR: TENANT_ID missing from .env");
    }

    // Initialize MSAL with the required parameters
    // - clientId: Application ID from Azure AD
    // - authority: URL for your tenant, e.g., https://login.microsoftonline.com/<tenantId>
    // - redirectUri: Redirect URI registered in Azure AD
    // - tanantId: (likely a typo, should be 'tenantId') Tenant ID from Azure AD
    await MsalAuth.initialize(
      clientId: clientId,
      authority: "https://login.microsoftonline.com/$tenantId",
      redirectUri: redirectUri,
      tanantId: tenantId, // ⚠️ likely a typo in the code, should be tenantId
    );
  }

  /// Perform interactive sign-in
  Future<AuthResult> signIn() async {
    try {
      // Attempt to authenticate the user interactively
      return await _performInteractiveAuth();
    } catch (e) {
      // Log any unexpected errors and rethrow them
      log('Unexpected sign-in error: $e');
      rethrow;
    }
  }

  /// Internal method to perform interactive authentication
  Future<AuthResult> _performInteractiveAuth() async {
    // Call MSAL to sign in interactively
    final AuthResult result = await MsalAuth.signIn();
    // Log tokens for debugging (avoid in production)
    log("ID Token: ${result.idToken}");
    log('Auth result: ${result.accessToken}');
    return result;
  }

  /// Acquire a token silently if the user has already signed in
  /// Useful for refreshing access without user interaction
  Future<AuthResult> acquireTokenSilent() {
    return MsalAuth.acquireTokenSilent();
  }

  /// Sign out the current user
  Future<void> signOut() async {
    MsalAuth.signOut();
  }

  /// Get information about the currently signed-in user
  Future<Map<String, dynamic>?> getCurrentAccount() async {
    final user = await MsalAuth.getCurrentAccount();
    // Log the current user info for debugging
    log("Current user: $user");
    return user;
  }
}

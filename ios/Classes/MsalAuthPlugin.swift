import Flutter
import MSAL
import UIKit

public class MsalAuthPlugin: NSObject, FlutterPlugin {
  private var msalApp: MSALPublicClientApplication?
  private var webViewParameters: MSALWebviewParameters?
  private var currentAccount: MSALAccount?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_msal_auth", binaryMessenger: registrar.messenger())
    let instance = MsalAuthPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initialize(call: call, result: result)
    case "signIn":
      signIn(call: call, result: result)
    case "acquireTokenSilent":
      acquireTokenSilent(call: call, result: result)
    case "signOut":
      signOut(result: result)
    case "getCurrentAccount":
      getCurrentAccount(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let clientId = args["clientId"] as? String,
      let authority = args["authority"] as? String
    else {
      result(
        FlutterError(
          code: "INVALID_ARGS",
          message: "Missing required arguments: clientId or authority",
          details: nil
        ))
      return
    }

    do {
      // Create authority URL
      guard let authorityURL = URL(string: authority) else {
        result(
          FlutterError(
            code: "INVALID_AUTHORITY",
            message: "Invalid authority URL",
            details: nil
          ))
        return
      }

      let msalAuthority = try MSALAuthority(url: authorityURL)

      // Configure MSAL
      let redirectUriArg = args["redirectUri"] as? String
      let config = MSALPublicClientApplicationConfig(
        clientId: clientId,
        redirectUri: redirectUriArg,  // If nil, MSAL will use default
        authority: msalAuthority
      )

      // Optional: Configure cache (use defaults unless explicitly set)

      // Create MSAL application
      msalApp = try MSALPublicClientApplication(configuration: config)

      setupWebViewParameters()

      result(nil)
    } catch let error as NSError {
      result(
        FlutterError(
          code: "INIT_ERROR",
          message: "Failed to initialize MSAL: \(error.localizedDescription)",
          details: error.debugDescription
        ))
    }
  }

  private func setupWebViewParameters() {
    if let viewController = UIApplication.shared.windows.first?.rootViewController {
      webViewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
    } else {
      // Fallback: try to get the key window's root view controller
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        let window = windowScene.windows.first(where: { $0.isKeyWindow }),
        let rootViewController = window.rootViewController
      {
        webViewParameters = MSALWebviewParameters(
          authPresentationViewController: rootViewController)
      }
    }
  }

  // MARK: - Sign In
  private func signIn(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let scopes = args["scopes"] as? [String]
    else {
      result(
        FlutterError(
          code: "INVALID_ARGS",
          message: "Missing scopes argument",
          details: nil
        ))
      return
    }

    guard let msalApp = msalApp else {
      result(
        FlutterError(
          code: "NOT_INITIALIZED",
          message: "MSAL not initialized. Call initialize() first",
          details: nil
        ))
      return
    }

    // Ensure web view parameters are set
    if webViewParameters == nil {
      setupWebViewParameters()
    }

    guard let webViewParameters = webViewParameters else {
      result(
        FlutterError(
          code: "NO_VIEW_CONTROLLER",
          message: "Could not find a view controller to present authentication",
          details: nil
        ))
      return
    }

    // Create interactive parameters
    let parameters = MSALInteractiveTokenParameters(
      scopes: scopes,
      webviewParameters: webViewParameters
    )

    // Optional: Add login hint
    if let loginHint = args["loginHint"] as? String {
      parameters.loginHint = loginHint
    }

    // Optional: Add prompt type
    // parameters.promptType = .selectAccount  // or .login, .consent

    // Acquire token interactively
    msalApp.acquireToken(with: parameters) { [weak self] (authResult, error) in
      if let error = error {
        let nsError = error as NSError
        result(
          FlutterError(
            code: "SIGN_IN_ERROR",
            message: nsError.localizedDescription,
            details: nsError.userInfo.description
          ))
        return
      }

      guard let authResult = authResult else {
        result(
          FlutterError(
            code: "SIGN_IN_ERROR",
            message: "No authentication result returned",
            details: nil
          ))
        return
      }

      // Store current account
      self?.currentAccount = authResult.account

      // Return result to Dart
      let resultMap: [String: Any] = [
        "accessToken": authResult.accessToken,
        "idToken": authResult.idToken ?? "",
        "scopes": authResult.scopes,
        "expiresOn": Int((authResult.expiresOn?.timeIntervalSince1970 ?? 0) * 1000),
        "accountId": authResult.account.identifier ?? "",
      ]

      result(resultMap)
    }
  }

  // MARK: - Acquire Token Silently
  private func acquireTokenSilent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let scopes = args["scopes"] as? [String]
    else {
      result(
        FlutterError(
          code: "INVALID_ARGS",
          message: "Missing scopes argument",
          details: nil
        ))
      return
    }

    guard let msalApp = msalApp else {
      result(
        FlutterError(
          code: "NOT_INITIALIZED",
          message: "MSAL not initialized",
          details: nil
        ))
      return
    }

    // Get account
    let account: MSALAccount?
    if let currentAccount = self.currentAccount {
      account = currentAccount
    } else {
      // Try to get the first available account
      do {
        let accounts = try msalApp.allAccounts()
        account = accounts.first
        self.currentAccount = account
      } catch {
        result(
          FlutterError(
            code: "NO_ACCOUNT",
            message: "No account found. Please sign in first",
            details: nil
          ))
        return
      }
    }

    guard let msalAccount = account else {
      result(
        FlutterError(
          code: "NO_ACCOUNT",
          message: "No account available",
          details: nil
        ))
      return
    }

    // Create silent parameters
    let parameters = MSALSilentTokenParameters(
      scopes: scopes,
      account: msalAccount
    )

    // Optional: Force refresh
    if let forceRefresh = args["forceRefresh"] as? Bool {
      parameters.forceRefresh = forceRefresh
    }

    // Acquire token silently
    msalApp.acquireTokenSilent(with: parameters) { (authResult, error) in
      if let error = error {
        let nsError = error as NSError
        result(
          FlutterError(
            code: "SILENT_ERROR",
            message: nsError.localizedDescription,
            details: nsError.userInfo.description
          ))
        return
      }

      guard let authResult = authResult else {
        result(
          FlutterError(
            code: "SILENT_ERROR",
            message: "No authentication result returned",
            details: nil
          ))
        return
      }

      let resultMap: [String: Any] = [
        "accessToken": authResult.accessToken,
        "idToken": authResult.idToken ?? "",
        "scopes": authResult.scopes,
        "expiresOn": Int((authResult.expiresOn?.timeIntervalSince1970 ?? 0) * 1000),
        "accountId": authResult.account.identifier ?? "",
      ]

      result(resultMap)
    }
  }

  // MARK: - Sign Out
  private func signOut(result: @escaping FlutterResult) {
    guard let msalApp = msalApp else {
      result(
        FlutterError(
          code: "NOT_INITIALIZED",
          message: "MSAL not initialized",
          details: nil
        ))
      return
    }

    guard let account = currentAccount else {
      // No account to sign out
      result(nil)
      return
    }

    do {
      try msalApp.remove(account)
      currentAccount = nil
      result(nil)
    } catch let error as NSError {
      result(
        FlutterError(
          code: "SIGN_OUT_ERROR",
          message: error.localizedDescription,
          details: error.userInfo.description
        ))
    }
  }

  // MARK: - Get Current Account
  private func getCurrentAccount(result: @escaping FlutterResult) {
    guard let msalApp = msalApp else {
      result(
        FlutterError(
          code: "NOT_INITIALIZED",
          message: "MSAL not initialized",
          details: nil
        ))
      return
    }

    do {
      let accounts = try msalApp.allAccounts()
      if let account = accounts.first {
        currentAccount = account
        let accountMap: [String: Any] = [
          "id": account.identifier ?? "",
          "username": account.username ?? "",
          "name": account.accountClaims?["name"] as? String ?? "",
          "tenantId": account.homeAccountId?.tenantId ?? "",
          "environment": account.environment ?? "",
        ]
        result(accountMap)
      } else {
        result(nil)
      }
    } catch let error as NSError {
      result(
        FlutterError(
          code: "ACCOUNT_ERROR",
          message: error.localizedDescription,
          details: error.userInfo.description
        ))
    }
  }

}

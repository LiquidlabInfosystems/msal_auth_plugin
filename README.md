# msal_auth_plugin

`msal_auth_plugin` provides Microsoft authentication on **Android** and **iOS** using the native **MSAL** library.  
It is designed to be **straightforward**, **secure**, and **easy to use** for Flutter developers.

---

## Features 🚀

- Option to set one of the following brokers (Authentication middleware):
  - **MS Authenticator App**
  - **Browser**
  - **In-App WebView**
- **Single account mode** support  
- **Acquire token** interactively & silently  
- **Complete authentication result** with account information  

---

## Platform Support

| Platform | Supported Version |
|-----------|------------------|
| **Android** | API Level 21+ (Android 5.0 and above) |
| **iOS** | iOS 14+ |

---

## Setup Guide ⚙️

To implement MSAL in Flutter, you first need to **set up an app in the Azure Portal** and configure platform-specific settings.

➡ Follow the step-by-step guide below ⬇️

### 1. Create an App in Azure Portal

1. Sign in to the **[Azure Portal](https://portal.azure.com)**.  
2. In the search bar, type **App registrations** and click on it.  
3. Click **New registration**.  
4. Fill in the **Name** field and select the desired **Supported account types**.  
5. Click **Register** to create the app.  
6. Once created, you will find:
   - **Application (client) ID**
   - **Directory (tenant) ID**

   These values are required later in your Dart code.

### 2. Configure Platform-Specific Settings

After registration:

1. Go to **Manage → Authentication → Add platform**.  
2. Add platform configurations for:
   - **Android**
   - **iOS/macOS**
3. Configure redirect URIs and other settings as per your platform needs.

---

## Android Setup – Azure Portal ⚙️

For **Android**, you need to provide your **package name** and **signature hash**.

To generate a **signature hash** in Flutter, run the following commands **from your project’s `android` folder**:

#### 🔹 Debug build:
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
```
#### 🔹 Release build:
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64keytool -exportcert -alias upload -keystore app/upload-keystore.jks | openssl sha1 -binary | openssl base64
```
 - Ensure you have `upload-keystore.jks` file placed inside `android/app` folder. Follow the Flutter's documentation [Build and release an Android app] to create a release setup.

Register both signature hash in Azure's Android Platform configurations. 

---

### iOS Setup - Azure portal

- You need to provide only `Bundle ID` of your iOS/macOS app. `Redirect URI` will be generated automatically by system.

---

## Android Configuration

This plugin offers full customization, allowing you to provide a configuration `JSON` file to be used during application creation & authentication.

Follow the steps below to complete the Android configuration.

### Creating MSAL Configuration JSON

- Create an `msal_config.json` file in the `android/app/src/main/res/raw` folder of your project and copy the **JSON** content from the [Microsoft default configuration file].
- Below is an example JSON format you can use for configuration:
```json
{
  "client_id" : "YOUR APPLICATION CLIENT ID",
  "authorization_user_agent" : "DEFAULT",
  "broker_redirect_uri_registered": true,
  "redirect_uri" : "msauth://<APP_PACKAGE_NAME>/<BASE64_ENCODED_PACKAGE_SIGNATURE>",
  "account_mode": "SINGLE",
  "authority": "https://login.microsoftonline.com/<TENANT_ID>",

  "authorities" : [
    {
      "type": "AAD",
      "audience": {
        "type": "AzureADandPersonalMicrosoftAccount",
        "tenant_id": "YOUR TENANT_ID"
      }
    }
  ]
}
```
- If you are using a broker, set **broker_redirect_uri_registered** to `true`; if not, set it to `false`.
- **account_mode** currently only supports **SINGLE**. **MULTIPLE** support will be added in the future.
- **authorization_user_agent** can be set to one of the following values:
```json
"authorization_user_agent": "BROWSER"
or
"authorization_user_agent": "WEBVIEW"

---

### Add Internet and Network State permission in AndroidManifest.xml

This permission declaration is required for browser-delegated authentication:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

---

### Add BrowserTabActivity in AndroidManifest.xml

If you use the `Browser` or `Authenticator` app for authentication, you must specify `BrowserTabActivity` within the `<application>` tag in your **AndroidManifest.xml** file.

```xml
<application>
    ...
    <activity android:name="com.microsoft.identity.client.BrowserTabActivity">
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />

            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />

            <data
                android:host="com.example.msal_auth_example"
                android:path="/<BASE64_ENCODED_PACKAGE_SIGNATURE>"
                android:scheme="msauth" />
        </intent-filter>
    </activity>
</application>
```
- Replace `host` with your app's package name and `path` with the `base64 signature hash` that was generated earlier.

---

### Add Required Packages for Broker Authentication

If you are using a **broker** for authentication, make sure to add the following packages in your `AndroidManifest.xml`:

```xml
<package android:name="com.azure.authenticator" />
<package android:name="com.microsoft.windowsintune.companyportal" />
```
---

## iOS Configuration

- Add the following keychain groups to your project capabilities:  
  - `com.microsoft.adalcache`  
  - `com.microsoft.identity.universalstorage`

  ![iOS Keychain Sharing](/Screenshots/keychain.png)

> Without these keychain groups, your app will not be able to open the [Microsoft Authenticator] app if specified as a broker. Additionally, the `logout` method will throw an exception because the account cannot be found in the cache.


---

### `Info.plist` Modification

- Add your application's redirect URI scheme to your `Info.plist` file:

  ```plist
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
  </array>
  ```

- Add `LSApplicationQueriesSchemes` to allow the [Microsoft Authenticator] app to be used as a broker for authentication.This is **not required** when using `Safari Browser` or `WebView` as the broker.
  ```plist
  <key>LSApplicationQueriesSchemes</key>
  <array>
	  <string>msauthv2</string>
	  <string>msauthv3</string>
  </array>
  ```

  - If you use `Broker.msAuthenticator` after declaring the above schemes but the Authenticator app is not installed on the iPhone, the authentication will fall back to using `Safari Browser`.

---

### Handle `callback` from MSAL

- Your app needs to handle login success callback if app uses [Microsoft Authenticator] app OR `Safari Browser` for authentication. `WebView` does not require it.
- Your app needs to handle the **login success callback** if it uses the [Microsoft Authenticator] app or `Safari Browser` for authentication. `WebView` does not require this callback.

#### AppDelegate.swift

```swift
import MSAL

override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
      return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String)
}
```

- Refer to the [`AppDelegate.swift`] file in the example app for more clarity.


---

## Implementation 

This section covers how to write the `Dart` code to set up an `MSAL` application in `Flutter` and authenticate the user.

```dart
class MsalAuthService {
  // Define the redirect URI based on the platform (iOS or Android)
  // This URI must match what you registered in Azure AD for your app
  final String redirectUri = Platform.isIOS
      ? dotenv.env['IOS_URI']!   // iOS redirect URI from .env file
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
```
### Reference Documentation

For detailed platform-specific configuration, refer to the official Microsoft Azure documentation:

- **Android MSAL setup:** [Microsoft Authentication Library (MSAL) for Android](https://learn.microsoft.com/en-gb/entra/identity-platform/tutorial-mobile-app-android-prepare-app?tabs=workforce-tenant)  
- **iOS MSAL setup:** [Microsoft Authentication Library (MSAL) for iOS](https://learn.microsoft.com/en-gb/entra/identity-platform/tutorial-mobile-app-ios-swift-sign-in?pivots=workforce)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.





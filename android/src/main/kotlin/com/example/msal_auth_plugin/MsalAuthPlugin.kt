package com.example.msal_auth_plugin

import android.app.Activity
import androidx.annotation.NonNull
import com.microsoft.identity.client.*
import com.microsoft.identity.client.exception.MsalException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** MsalAuthPlugin */
class MsalAuthPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var msalApp: ISingleAccountPublicClientApplication? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(
            @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        this.flutterPluginBinding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_msal_auth")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "signIn" -> signIn(call, result)
            "acquireTokenSilent" -> acquireTokenSilent(call, result)
            "signOut" -> signOut(result)
            "getCurrentAccount" -> getCurrentAccount(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: Result) {
        //        val clientId = call.argument<String>("clientId")
        //        val authority = call.argument<String>("authority")
        //        val redirectUri = call.argument<String>("redirectUri")
        //        val tanantId = call.argument<String>("tanantId")
        //
        //        if (clientId == null || authority == null || redirectUri == null) {
        //            result.error("INVALID_ARGS", "Missing required arguments", null)
        //            return
        //        }

        // Fix 1: Handle nullable context
        val context = flutterPluginBinding?.applicationContext
        if (context == null) {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }

        // Load host app's res/raw/msal_config.json rather than generating JSON
        val resources = context.resources
        val packageName = context.packageName
        var configResId = resources.getIdentifier("msal_config", "raw", packageName)
        if (configResId == 0) {
            // Fallback to common alternative name used by some apps
            configResId = resources.getIdentifier("auth_config", "raw", packageName)
        }

        if (configResId == 0) {
            result.error(
                    "MISSING_CONFIG",
                    "MSAL config not found. Expected app/src/main/res/raw/msal_config.json or auth_config.json",
                    null
            )
            return
        }

        PublicClientApplication.createSingleAccountPublicClientApplication(
                context,
                configResId,
                object : IPublicClientApplication.ISingleAccountApplicationCreatedListener {
                    override fun onCreated(application: ISingleAccountPublicClientApplication) {
                        msalApp = application
                        result.success(null)
                    }

                    override fun onError(exception: MsalException) {
                        result.error("INIT_ERROR", exception.message, null)
                    }
                }
        )
    }

    private fun signIn(call: MethodCall, result: Result) {
        val scopes = call.argument<List<String>>("scopes") ?: listOf("User.Read")
        val activity = this.activity

        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        if (msalApp == null) {
            result.error("NOT_INITIALIZED", "MSAL not initialized", null)
            return
        }

        val scopesArray = scopes.toTypedArray()
        msalApp?.signIn(
                activity,
                null,
                scopesArray,
                object : AuthenticationCallback {
                    override fun onSuccess(authenticationResult: IAuthenticationResult) {
                        result.success(
                                mapOf(
                                        "accessToken" to authenticationResult.accessToken,
                                        "idToken" to authenticationResult.account.idToken,
                                        "scopes" to authenticationResult.scope?.toList(),
                                        "expiresOn" to authenticationResult.expiresOn.time,
                                        "accountId" to authenticationResult.account.id
                                )
                        )
                    }

                    override fun onError(exception: MsalException) {
                        result.error("SIGN_IN_ERROR", exception.message, null)
                    }

                    override fun onCancel() {
                        result.error("CANCELLED", "User cancelled", null)
                    }
                }
        )
    }

    private fun acquireTokenSilent(call: MethodCall, result: Result) {
        val scopes = call.argument<List<String>>("scopes") ?: listOf("User.Read")

        if (msalApp == null) {
            result.error("NOT_INITIALIZED", "MSAL not initialized", null)
            return
        }

        msalApp?.getCurrentAccountAsync(
                object : ISingleAccountPublicClientApplication.CurrentAccountCallback {
                    override fun onAccountLoaded(activeAccount: IAccount?) {
                        if (activeAccount == null) {
                            result.error(
                                    "NO_ACCOUNT",
                                    "No account found. Please sign in first.",
                                    null
                            )
                            return
                        }

                        val authorities = msalApp?.configuration?.authorities ?: emptyList()
                        val authority =
                                if (authorities.isNotEmpty()) {
                                    authorities[0].authorityURL.toString()
                                } else {
                                    val accountAuthority = activeAccount.authority
                                    if (!accountAuthority.isNullOrBlank()) accountAuthority
                                    else "https://login.microsoftonline.com/common"
                                }

                        val scopesArray = scopes.toTypedArray()

                        msalApp?.acquireTokenSilentAsync(
                                scopesArray,
                                authority,
                                object : SilentAuthenticationCallback {
                                    override fun onSuccess(
                                            authenticationResult: IAuthenticationResult
                                    ) {
                                        result.success(
                                                mapOf(
                                                        "accessToken" to
                                                                authenticationResult.accessToken,
                                                        "idToken" to
                                                                authenticationResult
                                                                        .account
                                                                        .idToken,
                                                        "scopes" to
                                                                authenticationResult.scope
                                                                        ?.toList(),
                                                        "expiresOn" to
                                                                authenticationResult.expiresOn.time,
                                                        "accountId" to
                                                                authenticationResult.account.id
                                                )
                                        )
                                    }

                                    override fun onError(exception: MsalException) {
                                        result.error("SILENT_ERROR", exception.message, null)
                                    }
                                }
                        )
                    }

                    override fun onAccountChanged(
                            priorAccount: IAccount?,
                            currentAccount: IAccount?
                    ) {
                        if (currentAccount == null) {
                            result.error(
                                    "NO_ACCOUNT",
                                    "No account found. Please sign in first.",
                                    null
                            )
                            return
                        }

                        val authorities = msalApp?.configuration?.authorities ?: emptyList()
                        val authority =
                                if (authorities.isNotEmpty()) {
                                    authorities[0].authorityURL.toString()
                                } else {
                                    val accountAuthority = currentAccount.authority
                                    if (!accountAuthority.isNullOrBlank()) accountAuthority
                                    else "https://login.microsoftonline.com/common"
                                }

                        val scopesArray = scopes.toTypedArray()

                        msalApp?.acquireTokenSilentAsync(
                                scopesArray,
                                authority,
                                object : SilentAuthenticationCallback {
                                    override fun onSuccess(
                                            authenticationResult: IAuthenticationResult
                                    ) {
                                        result.success(
                                                mapOf(
                                                        "accessToken" to
                                                                authenticationResult.accessToken,
                                                        "idToken" to
                                                                authenticationResult
                                                                        .account
                                                                        .idToken,
                                                        "scopes" to
                                                                authenticationResult.scope
                                                                        ?.toList(),
                                                        "expiresOn" to
                                                                authenticationResult.expiresOn.time,
                                                        "accountId" to
                                                                authenticationResult.account.id
                                                )
                                        )
                                    }

                                    override fun onError(exception: MsalException) {
                                        result.error("SILENT_ERROR", exception.message, null)
                                    }
                                }
                        )
                    }

                    override fun onError(exception: MsalException) {
                        result.error("ACCOUNT_ERROR", exception.message, null)
                    }
                }
        )
    }

    private fun signOut(result: Result) {
        if (msalApp == null) {
            result.error("NOT_INITIALIZED", "MSAL not initialized", null)
            return
        }

        msalApp?.signOut(
                object : ISingleAccountPublicClientApplication.SignOutCallback {
                    override fun onSignOut() {
                        result.success(null)
                    }

                    override fun onError(exception: MsalException) {
                        result.error("SIGN_OUT_ERROR", exception.message, null)
                    }
                }
        )
    }

    private fun getCurrentAccount(result: Result) {
        if (msalApp == null) {
            result.error("NOT_INITIALIZED", "MSAL not initialized", null)
            return
        }

        msalApp?.getCurrentAccountAsync(
                object : ISingleAccountPublicClientApplication.CurrentAccountCallback {
                    override fun onAccountLoaded(activeAccount: IAccount?) {
                        result.success(activeAccount?.username)
                    }

                    override fun onAccountChanged(
                            priorAccount: IAccount?,
                            currentAccount: IAccount?
                    ) {
                        result.success(currentAccount?.username)
                    }

                    override fun onError(exception: MsalException) {
                        result.error("ACCOUNT_ERROR", exception.message, null)
                    }
                }
        )
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

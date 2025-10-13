import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:msal_auth_plugin/msal_auth_plugin.dart';
import 'msal_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSAL Auth Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final MsalAuthService _authService = MsalAuthService();
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isSignedIn = false;
  String? _errorMessage;
  Map<String, dynamic>? _userInfo;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _initializeMsal();
  }

  Future<void> _initializeMsal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.init();
      setState(() {
        _isInitialized = true;
      });

      // Check if user is already signed in
      await _checkCurrentAccount();
    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentAccount() async {
    try {
      final account = await _authService.getCurrentAccount();
      if (account != null && account.isNotEmpty) {
        setState(() {
          _isSignedIn = true;
          _userInfo = account;
        });

        // Try to get token silently
        await _acquireTokenSilent();
      }
    } catch (e) {
      // User not signed in
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthResult result = await _authService.signIn();
      final account = await _authService.getCurrentAccount();

      setState(() {
        _isSignedIn = true;
        _userInfo = account;
        _accessToken = result.accessToken;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign-in failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acquireTokenSilent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthResult result = await _authService.acquireTokenSilent();
      setState(() {
        _accessToken = result.accessToken;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token refreshed successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Token refresh failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signOut();
      setState(() {
        _isSignedIn = false;
        _userInfo = null;
        _accessToken = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign-out failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MSAL Authentication'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  if (!_isInitialized)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Initializing MSAL...',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (!_isSignedIn)
                    _buildSignInView()
                  else
                    _buildSignedInView(),
                ],
              ),
            ),
    );
  }

  Widget _buildSignInView() {
    return Column(
      children: [
        const Icon(Icons.account_circle, size: 100, color: Colors.grey),
        const SizedBox(height: 24),
        const Text(
          'Sign in with Microsoft',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please sign in to continue',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _signIn,
          icon: const Icon(Icons.login),
          label: const Text('Sign In'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedInView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_circle, size: 50),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed In',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_userInfo?['username'] != null)
                            Text(
                              _userInfo!['username'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow('User ID', _userInfo?['id']),
                _buildInfoRow('Username', _userInfo?['username']),
                _buildInfoRow('Home Account ID', _userInfo?['homeAccountId']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_accessToken != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Access Token',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _accessToken!.length > 100
                          ? '${_accessToken!.substring(0, 100)}...'
                          : _accessToken!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: _acquireTokenSilent,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Token'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

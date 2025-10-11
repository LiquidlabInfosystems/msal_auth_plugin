class AuthResult {
  final String accessToken;
  final String? idToken;
  final List<String> scopes;
  final DateTime expiresOn;
  final String? accountId;

  AuthResult({
    required this.accessToken,
    this.idToken,
    required this.scopes,
    required this.expiresOn,
    this.accountId,
  });

  factory AuthResult.fromMap(Map<String, dynamic> map) {
    return AuthResult(
      accessToken: map['accessToken'] as String,
      idToken: map['idToken'] as String?,
      scopes: List<String>.from(map['scopes'] ?? []),
      expiresOn: DateTime.fromMillisecondsSinceEpoch(map['expiresOn'] as int),
      accountId: map['accountId'] as String?,
    );
  }
}

class AuthException implements Exception {
  final String code;
  final String message;

  AuthException(this.code, this.message);

  @override
  String toString() => 'AuthException($code): $message';
}

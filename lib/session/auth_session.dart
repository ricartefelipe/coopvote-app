/// Sessão do associado: token Bearer, expiração e papéis informados pela API.
final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.roles,
  });

  final String accessToken;
  final DateTime expiresAt;
  final List<String> roles;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool get canManage => roles.contains('MANAGER');

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'roles': roles,
  };

  static AuthSession? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final token = value['accessToken'];
    final expires = value['expiresAt'];
    final roles = value['roles'];
    if (token is! String || token.isEmpty || expires is! String) {
      return null;
    }
    final expiresAt = DateTime.tryParse(expires);
    if (expiresAt == null) {
      return null;
    }
    return AuthSession(
      accessToken: token,
      expiresAt: expiresAt.toUtc(),
      roles: roles is List
          ? roles.map((r) => r.toString()).toList(growable: false)
          : const [],
    );
  }
}

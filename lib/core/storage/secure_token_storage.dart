import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/mobile_roles.dart';
import 'token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'ventourkid.accessToken';
  static const _refreshTokenKey = 'ventourkid.refreshToken';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  @override
  Future<String?> getUserRole() async {
    final payload = await _decodeAccessTokenPayload();
    if (payload == null) return null;
    final roles = payload['roles'];
    if (roles is! List || roles.isEmpty) return null;
    final codes = roles
        .map((r) => r?.toString() ?? '')
        .where((r) => r.isNotEmpty)
        .toList(growable: false);
    return resolveMobileSessionRole(codes);
  }

  @override
  Future<String?> getAccountId() async {
    final payload = await _decodeAccessTokenPayload();
    if (payload == null) return null;
    final sub = payload['sub']?.toString();
    if (sub != null && sub.isNotEmpty) return sub;
    final accountId = payload['accountId']?.toString();
    if (accountId != null && accountId.isNotEmpty) return accountId;
    return null;
  }

  @override
  Future<String?> getPhoneNumber() async {
    final payload = await _decodeAccessTokenPayload();
    if (payload == null) return null;
    final phone = payload['phoneNumber']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return null;
  }

  Future<Map<String, dynamic>?> _decodeAccessTokenPayload() async {
    final token = await getAccessToken();
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final normalizedPayload = base64Url.normalize(parts[1]);
      final decodedBytes = base64Url.decode(normalizedPayload);
      final decodedString = utf8.decode(decodedBytes);
      final json = jsonDecode(decodedString);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return Map<String, dynamic>.from(json);
    } catch (_) {
      return null;
    }
    return null;
  }
}

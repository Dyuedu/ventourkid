abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);

  Future<String?> getAccessToken();

  Future<void> saveRefreshToken(String token);

  Future<String?> getRefreshToken();

  Future<void> clearTokens();

  Future<String?> getUserRole();

  Future<String?> getAccountId();

  Future<String?> getPhoneNumber();
}

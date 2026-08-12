import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/core/storage/secure_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'AUTH-TC-MOB-001 stores and clears both tokens in secure storage',
    () async {
      final storage = SecureTokenStorage();

      await storage.saveAccessToken('sensitive-access-token');
      await storage.saveRefreshToken('sensitive-refresh-token');

      expect(await storage.getAccessToken(), 'sensitive-access-token');
      expect(await storage.getRefreshToken(), 'sensitive-refresh-token');

      await storage.clearTokens();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    },
  );
}

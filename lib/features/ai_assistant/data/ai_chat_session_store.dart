import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _guestSessionKey = 'ventourkids.ai.chat.guestSessionId';
const _accountSessionKeyPrefix = 'ventourkids.ai.chat.accountSession.';

class AiChatSessionStore {
  AiChatSessionStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<String> resolveSessionId(String? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId != null && accountId.isNotEmpty) {
      final key = '$_accountSessionKeyPrefix$accountId';
      final existing = prefs.getString(key);
      if (existing != null && existing.startsWith('a-$accountId')) {
        return existing;
      }
      final created = 'a-$accountId';
      await prefs.setString(key, created);
      return created;
    }

    final existing = prefs.getString(_guestSessionKey);
    if (existing != null && existing.startsWith('g-')) {
      return existing;
    }
    final created = 'g-${_uuid.v4()}';
    await prefs.setString(_guestSessionKey, created);
    return created;
  }

  Future<String> resetSession(String? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId != null && accountId.isNotEmpty) {
      final sessionId = 'a-$accountId-x-${_uuid.v4().substring(0, 8)}';
      await prefs.setString('$_accountSessionKeyPrefix$accountId', sessionId);
      return sessionId;
    }
    final created = 'g-${_uuid.v4()}';
    await prefs.setString(_guestSessionKey, created);
    return created;
  }
}

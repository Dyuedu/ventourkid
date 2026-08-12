import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DeviceIdProvider {
  Future<String> getDeviceId();
}

/// Persists a random installation identifier without collecting hardware IDs.
class PersistentDeviceIdProvider implements DeviceIdProvider {
  PersistentDeviceIdProvider({Random? random})
    : _random = random ?? Random.secure();

  static const _storageKey = 'ventourkid.deviceId';

  final Random _random;

  @override
  Future<String> getDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final deviceId = 'mobile-${base64Url.encode(bytes).replaceAll('=', '')}';
    await preferences.setString(_storageKey, deviceId);
    return deviceId;
  }
}

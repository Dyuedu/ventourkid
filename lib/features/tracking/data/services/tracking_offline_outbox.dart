import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../datasources/tracking_remote_data_source.dart';

class TrackingOfflineOutbox {
  static const _storageKey = 'ventourkids.tracking.command_outbox.v1';
  static const _uuid = Uuid();

  /// Commands created by one field account must not be sent under another
  /// account after a device is handed over.
  static Future<void> clearPersistedData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  Future<void> enqueueIncident(
    String operationPlanId,
    Map<String, dynamic> payload,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final queued = preferences.getStringList(_storageKey) ?? <String>[];
    final clientMutationId =
        payload['idempotencyKey']?.toString() ?? _uuid.v4();
    queued.add(
      jsonEncode({
        'type': 'INCIDENT_CREATE',
        'clientMutationId': clientMutationId,
        'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': {
          ...payload,
          'operationPlanId': operationPlanId,
          'idempotencyKey': clientMutationId,
          'offlineCreated': true,
        },
      }),
    );
    await preferences.setStringList(_storageKey, queued);
  }

  Future<void> enqueueTrackerReplacement({
    required String assignmentId,
    required String newDeviceQrPayload,
    required String reason,
  }) async {
    await _enqueueCommand(
      type: 'TRACKER_REPLACEMENT',
      payload: {
        'currentAssignmentId': assignmentId,
        'newDeviceQrPayload': newDeviceQrPayload,
        'reason': reason,
      },
    );
  }

  Future<void> enqueueCheckpointComplete({
    required String tourId,
    required String operationVehicleId,
    required String checkpointId,
  }) async {
    await _enqueueCommand(
      type: 'CHECKPOINT_COMPLETE',
      payload: {
        'tourId': tourId,
        'operationVehicleId': operationVehicleId,
        'checkpointId': checkpointId,
      },
    );
  }

  Future<int> flush(TrackingRemoteDataSource remoteDataSource) async {
    final preferences = await SharedPreferences.getInstance();
    final queued = preferences.getStringList(_storageKey) ?? <String>[];
    if (queued.isEmpty) return 0;
    final remaining = <String>[];
    var sent = 0;
    for (final encoded in queued) {
      try {
        final command = jsonDecode(encoded);
        final envelope = _normalizeCommand(command);
        if (envelope == null) continue;
        await remoteDataSource.syncOfflineCommands([envelope]);
        sent++;
      } catch (_) {
        remaining.add(encoded);
      }
    }
    await preferences.setStringList(_storageKey, remaining);
    return sent;
  }

  Map<String, dynamic>? _normalizeCommand(Object? command) {
    if (command is! Map) return null;
    final type = command['type']?.toString();
    if (type == 'INCIDENT_CREATE' ||
        type == 'TRACKER_REPLACEMENT' ||
        type == 'CHECKPOINT_COMPLETE') {
      return Map<String, dynamic>.from(command);
    }
    if (type != 'CREATE_INCIDENT') return null;
    final payload = Map<String, dynamic>.from(command['payload'] as Map);
    final clientMutationId =
        payload['idempotencyKey']?.toString() ?? _uuid.v4();
    return {
      'type': 'INCIDENT_CREATE',
      'clientMutationId': clientMutationId,
      'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
      'payload': {
        ...payload,
        'operationPlanId': command['operationPlanId']?.toString(),
        'idempotencyKey': clientMutationId,
        'offlineCreated': true,
      },
    };
  }

  Future<void> _enqueueCommand({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final queued = preferences.getStringList(_storageKey) ?? <String>[];
    queued.add(
      jsonEncode({
        'type': type,
        'clientMutationId': _uuid.v4(),
        'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
      }),
    );
    await preferences.setStringList(_storageKey, queued);
  }
}

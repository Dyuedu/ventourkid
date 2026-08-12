import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'data/datasources/tracking_remote_data_source.dart';
import 'data/services/tracking_offline_outbox.dart';

final trackingRemoteDataSourceProvider = Provider<TrackingRemoteDataSource>((ref) {
  return TrackingRemoteDataSource(ref.watch(dioClientProvider));
});

final trackingOfflineOutboxProvider = Provider<TrackingOfflineOutbox>((ref) {
  return TrackingOfflineOutbox();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../core/device/device_id_provider.dart';
import '../core/storage/secure_token_storage.dart';
import '../core/storage/token_storage.dart';
import '../features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import '../features/ai_assistant/presentation/viewmodels/ai_assistant_view_model.dart';
import '../features/ai_assistant/presentation/viewmodels/ai_assistant_view_state.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/datasources/google_sign_in_service.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../features/auth/presentation/viewmodels/auth_view_state.dart';
import '../features/attendance/data/datasources/offline_attendance_data_source.dart';
import '../features/face_attendance/data/datasources/face_remote_data_source.dart';
import '../features/face_attendance/data/services/mobile_face_embedding_service.dart';
import '../features/livestream/data/datasources/livestream_remote_data_source.dart';
import '../features/livestream/data/datasources/livestream_remote_data_source_impl.dart';
import '../features/livestream/data/repositories/livestream_repository_impl.dart';
import '../features/livestream/domain/repositories/livestream_repository.dart';
import '../features/livestream/presentation/viewmodels/livestream_view_model.dart';
import '../features/livestream/presentation/viewmodels/livestream_view_state.dart';
import '../features/media/data/datasources/media_remote_data_source.dart';
import '../features/newsfeed/data/datasources/newsfeed_remote_data_source.dart';

import '../features/parent/data/datasources/parent_dashboard_local_data_source.dart';
import '../features/parent/data/datasources/parent_dashboard_remote_data_source.dart';
import '../features/parent/data/datasources/parent_dashboard_remote_data_source_impl.dart';
import '../features/parent/data/datasources/parent_link_remote_data_source.dart';
import '../features/parent/data/datasources/parent_link_remote_data_source_impl.dart';
import '../features/parent/data/repositories/parent_dashboard_repository_impl.dart';
import '../features/parent/data/repositories/parent_link_repository_impl.dart';
import '../features/parent/domain/repositories/parent_dashboard_repository.dart';
import '../features/parent/domain/repositories/parent_link_repository.dart';
import '../features/parent/presentation/viewmodels/parent_dashboard_view_model.dart';
import '../features/parent/presentation/viewmodels/parent_dashboard_view_state.dart';
import '../features/parent/presentation/viewmodels/parent_link_view_model.dart';
import '../features/parent/presentation/viewmodels/parent_link_view_state.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/incident/data/datasources/incident_remote_data_source.dart';
import '../features/incident/data/datasources/incident_remote_data_source_impl.dart';
import '../features/incident/data/repositories/incident_repository_impl.dart';
import '../features/incident/domain/repositories/incident_repository.dart';
import '../features/incident/presentation/viewmodels/incident_view_model.dart';
import '../features/incident/presentation/viewmodels/incident_view_state.dart';
import '../features/tour_closing/data/datasources/tour_closing_remote_data_source.dart';
import '../features/notification/data/datasources/notification_remote_data_source.dart';
import '../features/notification/data/datasources/notification_remote_data_source_impl.dart';
import '../features/notification/data/services/push_notification_service.dart';
import '../features/notification/presentation/controllers/notification_realtime_controller.dart';
import '../shared/i18n/app_language.dart';
import 'route_guards.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

final deviceIdProvider = Provider<DeviceIdProvider>((ref) {
  return PersistentDeviceIdProvider();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final language = ref.watch(appLanguageControllerProvider);
  return DioClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    languageCode: language.code,
  );
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(dioClientProvider));
});

final googleSignInServiceProvider = Provider<GoogleSignInService>((ref) {
  return GoogleSignInServiceImpl();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    deviceIdProvider: ref.watch(deviceIdProvider),
  );
});

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthViewState>((ref) {
      return AuthViewModel(ref.watch(authRepositoryProvider));
    });

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSourceImpl(ref.watch(dioClientProvider));
});

final routeGuardsProvider = Provider<RouteGuards>((ref) {
  return RouteGuards(ref.watch(authRepositoryProvider));
});

final parentDashboardLocalDataSourceProvider =
    Provider<ParentDashboardLocalDataSource>((ref) {
      return const ParentDashboardLocalDataSourceImpl();
    });

final parentDashboardRemoteDataSourceProvider =
    Provider<ParentDashboardRemoteDataSource>((ref) {
      return ParentDashboardRemoteDataSourceImpl(ref.watch(dioClientProvider));
    });

final parentDashboardRepositoryProvider = Provider<ParentDashboardRepository>((
  ref,
) {
  return ParentDashboardRepositoryImpl(
    localDataSource: ref.watch(parentDashboardLocalDataSourceProvider),
    remoteDataSource: ref.watch(parentDashboardRemoteDataSourceProvider),
    livestreamRemoteDataSource: ref.watch(livestreamRemoteDataSourceProvider),
    parentLinkRemoteDataSource: ref.watch(parentLinkRemoteDataSourceProvider),
  );
});

final parentDashboardViewModelProvider =
    StateNotifierProvider<ParentDashboardViewModel, ParentDashboardViewState>((
      ref,
    ) {
      return ParentDashboardViewModel(
        ref.watch(parentDashboardRepositoryProvider),
      )..load();
    });

final parentLinkRemoteDataSourceProvider = Provider<ParentLinkRemoteDataSource>(
  (ref) {
    return ParentLinkRemoteDataSourceImpl(ref.watch(dioClientProvider));
  },
);

final parentLinkRepositoryProvider = Provider<ParentLinkRepository>((ref) {
  return ParentLinkRepositoryImpl(
    ref.watch(parentLinkRemoteDataSourceProvider),
  );
});

final parentLinkViewModelProvider =
    StateNotifierProvider.autoDispose<ParentLinkViewModel, ParentLinkViewState>(
      (ref) {
        return ParentLinkViewModel(ref.watch(parentLinkRepositoryProvider));
      },
    );

final livestreamRemoteDataSourceProvider = Provider<LivestreamRemoteDataSource>(
  (ref) {
    return LivestreamRemoteDataSourceImpl(ref.watch(dioClientProvider));
  },
);

final livestreamRepositoryProvider = Provider<LivestreamRepository>((ref) {
  return LivestreamRepositoryImpl(
    remoteDataSource: ref.watch(livestreamRemoteDataSourceProvider),
  );
});

final livestreamViewModelProvider =
    StateNotifierProvider<LivestreamViewModel, LivestreamViewState>((ref) {
      return LivestreamViewModel(ref.watch(livestreamRepositoryProvider));
    });

final mediaRemoteDataSourceProvider = Provider<MediaRemoteDataSource>((ref) {
  return MediaRemoteDataSourceImpl(ref.watch(dioClientProvider));
});

final newsfeedRemoteDataSourceProvider = Provider<NewsfeedRemoteDataSource>((
  ref,
) {
  return NewsfeedRemoteDataSourceImpl(ref.watch(dioClientProvider));
});


final attendanceRemoteDataSourceProvider = Provider<AttendanceRemoteDataSource>(
  (ref) {
    return AttendanceRemoteDataSourceImpl(ref.watch(dioClientProvider));
  },
);

final attendanceLocalDataSourceProvider = Provider<AttendanceLocalDataSource>((
  ref,
) {
  return const AttendanceLocalDataSourceImpl();
});

final offlineAttendanceRepositoryProvider =
    Provider<OfflineAttendanceRepository>((ref) {
      return OfflineAttendanceRepository(
        remote: ref.watch(attendanceRemoteDataSourceProvider),
        local: ref.watch(attendanceLocalDataSourceProvider),
      );
    });

final faceRemoteDataSourceProvider = Provider<FaceRemoteDataSource>((ref) {
  return FaceRemoteDataSourceImpl(ref.watch(dioClientProvider));
});

final mobileFaceEmbeddingServiceProvider = Provider<MobileFaceEmbeddingService>(
  (ref) {
    final service = MobileFaceEmbeddingService();
    ref.onDispose(service.dispose);
    return service;
  },
);

// ─── Incident providers (Epic 17) ───────────────────────────────────────────

final incidentRemoteDataSourceProvider = Provider<IncidentRemoteDataSource>(
  (ref) => IncidentRemoteDataSourceImpl(ref.watch(dioClientProvider)),
);

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => IncidentRepositoryImpl(ref.watch(incidentRemoteDataSourceProvider)),
);

final incidentViewModelProvider =
    StateNotifierProvider<IncidentViewModel, IncidentViewState>(
      (ref) => IncidentViewModel(ref.watch(incidentRepositoryProvider)),
    );

final tourClosingRemoteDataSourceProvider =
    Provider<TourClosingRemoteDataSource>(
      (ref) => TourClosingRemoteDataSource(ref.watch(dioClientProvider)),
    );

// ─── Notifications (shared with web inbox API) ──────────────────────────────

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>(
      (ref) => NotificationRemoteDataSourceImpl(ref.watch(dioClientProvider)),
    );

final notificationRealtimeProvider =
    StateNotifierProvider<
      NotificationRealtimeController,
      NotificationRealtimeState
    >((ref) {
      return NotificationRealtimeController(
        remote: ref.watch(notificationRemoteDataSourceProvider),
        tokenStorage: ref.watch(tokenStorageProvider),
        dioClient: ref.watch(dioClientProvider),
      );
    });

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(
    remote: ref.watch(notificationRemoteDataSourceProvider),
    deviceIdProvider: ref.watch(deviceIdProvider),
  );
});

// ─── AI Assistant ───────────────────────────────────────────────────────────

final aiAssistantRemoteDataSourceProvider =
    Provider<AiAssistantRemoteDataSource>((ref) {
      return AiAssistantRemoteDataSourceImpl(ref.watch(dioClientProvider));
    });

final aiAssistantViewModelProvider =
    StateNotifierProvider.autoDispose<
      AiAssistantViewModel,
      AiAssistantViewState
    >(
      (ref) => AiAssistantViewModel(
        remoteDataSource: ref.watch(aiAssistantRemoteDataSourceProvider),
        tokenStorage: ref.watch(tokenStorageProvider),
      ),
    );

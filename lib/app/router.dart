import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../features/ai_assistant/presentation/views/ai_assistant_page.dart';
import '../features/auth/domain/entities/register_draft.dart';
import '../features/auth/domain/mobile_roles.dart';
import '../features/auth/presentation/views/accept_invitation_page.dart';
import '../features/auth/presentation/views/forgot_password_page.dart';
import '../features/auth/presentation/views/login_page.dart';
import '../features/auth/presentation/views/register_parent_page.dart';
import '../features/auth/presentation/views/set_password_from_invite_page.dart';
import '../features/auth/presentation/views/verify_otp_page.dart';
import '../features/attendance/presentation/views/offline_attendance_page.dart';
import '../features/attendance/presentation/views/attendance_history_page.dart';
import '../features/consent/presentation/public_consent_page.dart';
import '../features/face_attendance/presentation/views/face_attendance_page.dart';
import '../features/face_attendance/presentation/views/parent_face_enroll_page.dart';
import '../features/guide/presentation/views/guide_dashboard_page.dart';
import '../features/guide/presentation/views/food_allergy_alerts_page.dart';
import '../features/guide/presentation/views/guide_itinerary_page.dart';
import '../features/tour_closing/presentation/views/tour_closing_page.dart';
import '../features/vehicle_inspection/presentation/views/vehicle_inspection_confirm_page.dart';
import '../features/notification/presentation/views/notifications_page.dart';
import '../features/livestream/presentation/views/guide_active_stream_page.dart';
import '../features/livestream/presentation/views/guide_live_setup_page.dart';
import '../features/livestream/presentation/views/guide_stream_summary_page.dart';
import '../features/livestream/presentation/views/parent_livestream_viewer_page.dart';
import '../features/livestream/presentation/views/parent_replay_history_page.dart';
import '../features/livestream/presentation/views/parent_replay_player_page.dart';
import '../features/media/presentation/views/media_timeline_page.dart';
import '../features/newsfeed/presentation/views/newsfeed_page.dart';
import '../features/parent/presentation/views/parent_dashboard_page.dart';
import '../features/parent/presentation/views/parent_post_tour_feedback_page.dart';
import '../features/parent/presentation/views/parent_tour_history_detail_page.dart';
import '../features/profile/presentation/views/profile_page.dart';
import '../features/tour/presentation/views/tours_page.dart';
import '../features/incident/routes.dart';
import '../features/incident/presentation/views/missing_student_search_map_screen.dart';
import '../shared/widgets/app_bootstrap_splash.dart';
import '../shared/widgets/field_app_shell.dart';
import 'package:ventourkid_mobile/features/tracking/presentation/views/tracking_screen.dart';
import 'package:ventourkid_mobile/features/tracking/presentation/views/tracking_operations_screen.dart';
import 'providers.dart';

bool _isTruthyQuery(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'y';
}

bool _isPublicAuthRoute(String path) {
  if ({
    '/login',
    '/register-parent',
    '/forgot-password',
    '/verify-otp',
    '/invite/set-password',
  }.contains(path)) {
    return true;
  }
  return path.startsWith('/invite/') || path.startsWith('/consent/');
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final routeGuards = ref.watch(routeGuardsProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) async {
      final isAuthenticated = await routeGuards.isAuthenticated;
      final path = state.uri.path;
      final isAuthRoute = _isPublicAuthRoute(path);

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }
      if (isAuthenticated) {
        final role = await routeGuards.userRole;
        if (!isMobileAllowedRole(role)) {
          await ref
              .read(authViewModelProvider.notifier)
              .rejectIfMobileRoleBlocked();
          return '/login';
        }
        if (isAuthRoute || path == '/home') {
          // Stay on invite/consent while challenge is in progress.
          if (path.startsWith('/invite/') || path.startsWith('/consent/')) {
            return null;
          }
          return homePathForMobileRole(role);
        }
      }
      if (isAuthenticated &&
          (path == '/face-attendance' ||
              path == '/attendance/offline' ||
              path == '/attendance/history' ||
              path == '/field/food-allergy-alerts')) {
        final role = await routeGuards.userRole;
        if (role != 'TOUR_GUIDE' && role != 'TEACHER') {
          return homePathForMobileRole(role);
        }
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => FieldAppShell(
          location: state.uri.path,
          tourId: state.uri.queryParameters['tourId'],
          child: child,
        ),
        routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const AppBootstrapHold(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register-parent',
        builder: (context, state) => const RegisterParentPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final extra = state.extra;
          return VerifyOtpPage(
            draft: extra is RegisterDraft ? extra : null,
            identifier: state.uri.queryParameters['identifier'],
          );
        },
      ),
      GoRoute(
        path: '/invite/set-password',
        builder: (context, state) {
          final extra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : <String, dynamic>{};
          final challengeToken = extra['challengeToken']?.toString() ?? '';
          if (challengeToken.isEmpty) {
            return const AcceptInvitationPage(token: '');
          }
          return SetPasswordFromInvitePage(
            challengeToken: challengeToken,
            phoneNumberMasked: extra['phoneNumberMasked']?.toString() ?? '',
            fullName: extra['fullName']?.toString(),
          );
        },
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) =>
            AcceptInvitationPage(token: state.pathParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/consent/:token',
        builder: (context, state) =>
            PublicConsentPage(token: state.pathParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/parent/dashboard',
        builder: (context, state) {
          final rosterStudentId = state.uri.queryParameters['rosterStudentId'];
          final tourId = state.uri.queryParameters['tourId'];
          return ParentDashboardPage(
            initialRosterStudentId: rosterStudentId,
            initialTourId: tourId,
          );
        },
      ),
      GoRoute(
        path: '/parent/feedback',
        builder: (context, state) {
          final tourId = state.uri.queryParameters['tourId'] ?? '';
          final tourName = state.uri.queryParameters['tourName'];
          return ParentPostTourFeedbackPage(
            tourId: tourId,
            tourName: tourName,
            actorRole: 'PARENT',
          );
        },
      ),
      GoRoute(
        path: '/teacher/feedback',
        builder: (context, state) {
          final tourId = state.uri.queryParameters['tourId'] ?? '';
          final tourName = state.uri.queryParameters['tourName'];
          return ParentPostTourFeedbackPage(
            tourId: tourId,
            tourName: tourName,
            actorRole: 'TEACHER',
          );
        },
      ),
      GoRoute(
        path: '/parent/tour-history',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final tourId = q['tourId'] ?? '';
          final child = q['child'] ?? '';
          final childName = q['childName'];
          final extra = state.extra;
          final seededTour =
              extra is Map<String, dynamic> ? extra : null;
          return ParentTourHistoryDetailPage(
            tourId: tourId,
            rosterStudentId: child,
            childName: childName,
            seededTour: seededTour,
          );
        },
      ),
      // Keep legacy path in case an old deep-link still uses it.
      GoRoute(
        path: '/parent/tours/:tourId/history',
        redirect: (context, state) {
          final tourId = state.pathParameters['tourId'] ?? '';
          final q = Map<String, String>.from(state.uri.queryParameters);
          if (tourId.isNotEmpty) q['tourId'] = tourId;
          return Uri(
            path: '/parent/tour-history',
            queryParameters: q.isEmpty ? null : q,
          ).toString();
        },
      ),
      GoRoute(
        path: '/guide/dashboard',
        builder: (context, state) => const GuideDashboardPage(),
      ),
      GoRoute(
        path: '/teacher/dashboard',
        builder: (context, state) =>
            const GuideDashboardPage(role: GuideDashboardRole.teacher),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/guide/itinerary',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final tourId = q['tourId'] ?? '';
          final prep = _isTruthyQuery(q['prep']) || _isTruthyQuery(q['readOnly']);
          return GuideItineraryPage(tourId: tourId, prepReadOnlyHint: prep);
        },
      ),
      GoRoute(
        path: '/field/food-allergy-alerts',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return FoodAllergyAlertsPage(
            tourId: params['tourId'] ?? '',
            tourName: params['tourName'],
          );
        },
      ),
      GoRoute(
        path: '/teacher/vehicle-inspection',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return VehicleInspectionConfirmPage(
            tourId: q['tourId'] ?? '',
            planItemId: q['planItemId'] ?? '',
            operationVehicleId: q['vehicleId'],
            vehicleLabel: q['vehicleLabel'],
            itemTitle: q['title'],
          );
        },
      ),
      GoRoute(
        path: '/closing',
        builder: (context, state) {
          final tourId = state.uri.queryParameters['tourId'] ?? '';
          return TourClosingPage(tourId: tourId);
        },
      ),
      GoRoute(
        path: '/livestream/setup',
        builder: (context, state) {
          final tourId =
              state.uri.queryParameters['tourId'] ??
              (state.extra is Map
                  ? (state.extra as Map)['tourId'] as String?
                  : null) ??
              (state.extra as String?) ??
              'aaaaaaaa-0000-4000-8000-000000000001';
          return GuideLiveSetupPage(
            tourId: tourId,
            initialPlanItemId: state.uri.queryParameters['planItemId'],
            fromItinerary: state.uri.queryParameters['fromItinerary'] == 'true',
            retryStream: state.uri.queryParameters['retryStream'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '/livestream/replay',
        builder: (context, state) {
          final extra = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final tourId =
              extra['tourId'] as String? ??
              state.uri.queryParameters['tourId'] ??
              '';
          final title = extra['title'] as String?;
          return ParentReplayHistoryPage(tourId: tourId, title: title);
        },
        routes: [
          GoRoute(
            path: ':sessionId',
            builder: (context, state) {
              final extra = state.extra is Map<String, dynamic>
                  ? state.extra as Map<String, dynamic>
                  : <String, dynamic>{};
              final tourId =
                  extra['tourId'] as String? ??
                  state.uri.queryParameters['tourId'] ??
                  '';
              final title = extra['title'] as String?;
              return ParentReplayPlayerPage(
                tourId: tourId,
                sessionId: state.pathParameters['sessionId'] ?? '',
                title: title,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/livestream/watch',
        builder: (context, state) {
          final extra = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final tourId =
              extra['tourId'] as String? ??
              state.uri.queryParameters['tourId'] ??
              '';
          final sessionId =
              extra['sessionId'] as String? ??
              state.uri.queryParameters['sessionId'] ??
              '';
          final title = extra['title'] as String?;
          final viewerRole =
              extra['viewerRole'] as String? ??
              state.uri.queryParameters['viewerRole'];
          final viewerName =
              extra['viewerName'] as String? ??
              state.uri.queryParameters['viewerName'];
          return ParentLivestreamViewerPage(
            tourId: tourId,
            sessionId: sessionId,
            title: title,
            viewerRole: viewerRole,
            viewerName: viewerName,
          );
        },
      ),
      GoRoute(
        path: '/livestream/active',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra as Map<String, dynamic>;
            return GuideActiveStreamPage(
              tourId: extra['tourId'] as String,
              title: extra['title'] as String? ?? 'Livestream',
              preInitVideoTrack: extra['videoTrack'] as LocalVideoTrack?,
              preInitAudioTrack: extra['audioTrack'] as LocalAudioTrack?,
            );
          }
          final tourId =
              state.extra as String? ?? '00000000-0000-0000-0000-000000000000';
          return GuideActiveStreamPage(tourId: tourId, title: 'Livestream');
        },
      ),
      GoRoute(
        path: '/livestream/summary',
        builder: (context, state) {
          int duration = 0;
          String title = 'Livestream';
          int maxViewers = 0;

          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra as Map<String, dynamic>;
            duration = extra['durationSeconds'] as int? ?? 0;
            title = extra['title'] as String? ?? 'Livestream';
            maxViewers = extra['maxViewers'] as int? ?? 0;
          } else if (state.extra is int) {
            duration = state.extra as int;
          }

          return GuideStreamSummaryPage(
            durationSeconds: duration,
            title: title,
            maxViewers: maxViewers,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/ai-assistant',
        builder: (context, state) => const AiAssistantPage(),
      ),
      GoRoute(
        path: '/media/timeline',
        builder: (context, state) {
          final tourId =
              state.extra as String? ??
              state.uri.queryParameters['tourId'] ??
              '';
          return MediaTimelinePage(
            tourId: tourId,
            studentId: state.uri.queryParameters['studentId'],
            studentName: state.uri.queryParameters['studentName'],
            activityId: state.uri.queryParameters['activityId'],
            readOnlyUpload: _isTruthyQuery(state.uri.queryParameters['readOnly']) ||
                _isTruthyQuery(state.uri.queryParameters['tourCompleted']),
          );
        },
      ),
      GoRoute(
        path: '/newsfeed',
        builder: (context, state) {
          final tourId =
              state.extra as String? ??
              state.uri.queryParameters['tourId'] ??
              '';
          return NewsfeedPage(
            tourId: tourId.isEmpty ? null : tourId,
            title: state.uri.queryParameters['title'],
            actorLabel: state.uri.queryParameters['actor'],
            studentId: state.uri.queryParameters['studentId'],
            studentName: state.uri.queryParameters['studentName'],
          );
        },
      ),
      GoRoute(
        path: '/face-attendance',
        builder: (context, state) => FaceAttendancePage(
          initialTourId: state.uri.queryParameters['tourId'],
          initialCheckpointId: state.uri.queryParameters['checkpointId'],
          initialVehicleId: state.uri.queryParameters['vehicleId'],
          initialTourName: state.uri.queryParameters['tourName'],
          initialCheckpointLabel: state.uri.queryParameters['checkpointLabel'],
          initialVehicleLabel: state.uri.queryParameters['vehicleLabel'],
        ),
      ),
      GoRoute(
        path: '/face-enroll',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          final extra = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final studentId =
              extra['studentId'] as String? ?? params['studentId'] ?? '';
          final schoolId =
              extra['schoolId'] as String? ?? params['schoolId'] ?? '';
          final studentName =
              extra['studentName'] as String? ?? params['studentName'];
          final operationPlanId =
              extra['operationPlanId'] as String? ??
              params['operationPlanId'] ??
              '';
          final consentRecordId =
              extra['consentRecordId'] as String? ?? params['consentRecordId'];
          return ParentFaceEnrollPage(
            studentId: studentId,
            schoolId: schoolId,
            operationPlanId: operationPlanId,
            studentName: studentName,
            consentRecordId: consentRecordId,
          );
        },
      ),
      GoRoute(
        path: '/attendance/offline',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          final mode = params['mode'] == 'face'
              ? OfflineAttendanceMode.face
              : OfflineAttendanceMode.manual;
          return OfflineAttendancePage(
            initialTourId: params['tourId'],
            initialMode: mode,
            initialPlanItemId: params['planItemId'],
            initialCheckpointId: params['checkpointId'],
            initialVehicleId: params['vehicleId'],
            initialSessionName: params['sessionName'],
            autoStartSession: params['autoStart'] == 'true',
            fromItinerary: params['fromItinerary'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '/attendance/history',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          final extra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : const <String, dynamic>{};
          String? pick(String key) {
            final fromExtra = extra[key]?.toString().trim();
            if (fromExtra != null && fromExtra.isNotEmpty) return fromExtra;
            final fromQuery = params[key]?.trim();
            if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
            return null;
          }

          final tourId = pick('tourId') ?? params['tourId'] ?? '';
          final planItemId = pick('planItemId');
          return AttendanceHistoryPage(
            key: ValueKey('$tourId-$planItemId'),
            tourId: tourId,
            tourName: pick('tourName') ?? params['tourName'],
            initialPlanItemId: planItemId,
            initialActivityName: pick('activityName'),
            initialDestinationName: pick('destinationName'),
            initialCheckpointId: pick('checkpointId'),
          );
        },
      ),
      GoRoute(
        path: '/tours',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'] ?? 'live';
          return ToursPage(initialTab: tab);
        },
      ),
      ...incidentRoutes,
      GoRoute(
        path: '/incident/:id/search-map',
        builder: (context, state) {
          final extra = state.extra;
          final data = extra is Map ? Map<String, dynamic>.from(extra) : const <String, dynamic>{};
          return MissingStudentSearchMapScreen(
            studentName: data['studentName']?.toString() ?? 'Học sinh',
            snapshot: data['snapshot'] is Map
                ? Map<String, dynamic>.from(data['snapshot'] as Map)
                : const <String, dynamic>{},
          );
        },
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => const TrackingOperationsScreen(),
      ),
      GoRoute(
        path: '/tracking/:operationPlanId',
        builder: (context, state) {
          final operationPlanId = state.pathParameters['operationPlanId']!;
          return TrackingScreen(operationPlanId: operationPlanId);
        },
      ),
        ],
      ),
    ],
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ventourkid_mobile/app/app.dart';
import 'package:ventourkid_mobile/app/providers.dart';
import 'package:ventourkid_mobile/core/storage/token_storage.dart';
import 'package:ventourkid_mobile/features/auth/data/models/accept_invitation_model.dart';
import 'package:ventourkid_mobile/features/auth/domain/entities/register_draft.dart';
import 'package:ventourkid_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:ventourkid_mobile/features/auth/presentation/views/login_page.dart';
import 'package:ventourkid_mobile/features/parent/data/datasources/parent_dashboard_local_data_source.dart';
import 'package:ventourkid_mobile/features/parent/domain/entities/parent_dashboard.dart';
import 'package:ventourkid_mobile/features/parent/domain/repositories/parent_dashboard_repository.dart';
import 'package:ventourkid_mobile/features/parent/presentation/views/parent_dashboard_page.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refreshToken = token;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> getUserRole() async => 'PARENT';

  @override
  Future<String?> getAccountId() async => null;

  @override
  Future<String?> getPhoneNumber() async => null;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.authenticated});

  final bool authenticated;

  @override
  Future<bool> isAuthenticated() async => authenticated;

  @override
  Future<void> login({
    required String identifier,
    required String password,
  }) async {}

  @override
  Future<void> googleLogin({required String googleToken}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> register(RegisterDraft draft, String otpCode) async {}

  @override
  Future<void> sendRegisterOtp({required String identifier}) async {}

  @override
  Future<String?> getUserRole() async => 'PARENT';

  @override
  Future<String?> getAccountId() async => null;

  @override
  Future<AcceptInvitationModel> acceptInvitation({
    required String token,
  }) async {
    return const AcceptInvitationModel(
      challengeToken: 'challenge-token',
      expiresInSeconds: 900,
      phoneNumberMasked: '+84***000',
    );
  }

  @override
  Future<void> setInvitationPassword({
    required String challengeToken,
    required String newPassword,
    required String confirmPassword,
  }) async {}
}

class _LocalOnlyParentDashboardRepository implements ParentDashboardRepository {
  @override
  Future<ParentDashboardData> getDashboard({String? selectedRosterStudentId, String? selectedTourId}) {
    return const ParentDashboardLocalDataSourceImpl().getDashboard();
  }
}

void main() {
  testWidgets('shows login page when no token exists', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    expect(
      find.text('Email hoặc số điện thoại', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });

  testWidgets('shows parent dashboard when repository session exists', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parentDashboardRepositoryProvider.overrideWithValue(
            _LocalOnlyParentDashboardRepository(),
          ),
        ],
        child: const MaterialApp(home: ParentDashboardPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bảng điều khiển phụ huynh'), findsOneWidget);
  });
}

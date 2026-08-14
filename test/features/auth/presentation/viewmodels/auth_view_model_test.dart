import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/core/error/app_failure.dart';
import 'package:ventourkid_mobile/features/auth/data/models/accept_invitation_model.dart';
import 'package:ventourkid_mobile/features/auth/domain/entities/register_draft.dart';
import 'package:ventourkid_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:ventourkid_mobile/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel', () {
    test(
      'emits login loading then idle when password login succeeds',
      () async {
        final repository = _FakeAuthRepository();
        final viewModel = AuthViewModel(repository);
        addTearDown(viewModel.dispose);

        final loginFuture = viewModel.login(
          identifier: 'parent@example.com',
          password: 'password1!',
        );

        expect(viewModel.state.isLoggingIn, isTrue);
        repository.completeLogin();
        expect(await loginFuture, isTrue);
        expect(viewModel.state.isLoading, isFalse);
        expect(viewModel.state.errorMessage, isNull);
      },
    );

    test('emits error state when password login fails', () async {
      final viewModel = AuthViewModel(
        _FakeAuthRepository(loginError: const AppFailure('Invalid login')),
      );
      addTearDown(viewModel.dispose);

      final success = await viewModel.login(
        identifier: 'parent@example.com',
        password: 'wrong',
      );

      expect(success, isFalse);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, 'Invalid login');
    });

    test(
      'emits google login loading then idle when Google login succeeds',
      () async {
        final repository = _FakeAuthRepository();
        final viewModel = AuthViewModel(repository);
        addTearDown(viewModel.dispose);

        final loginFuture = viewModel.googleLogin(googleToken: 'google-token');

        expect(viewModel.state.isGoogleLoggingIn, isTrue);
        repository.completeGoogleLogin();
        expect(await loginFuture, isTrue);
        expect(viewModel.state.isLoading, isFalse);
        expect(viewModel.state.errorMessage, isNull);
      },
    );

    test('resets account-scoped state after logout and a successful login', () async {
      final repository = _FakeAuthRepository();
      var sessionTransitions = 0;
      final viewModel = AuthViewModel(
        repository,
        onSessionChanged: () async {
          sessionTransitions++;
        },
      );
      addTearDown(viewModel.dispose);

      expect(await viewModel.logout(), isTrue);
      final login = viewModel.login(
        identifier: 'parent@example.com',
        password: 'password1!',
      );
      repository.completeLogin();
      expect(await login, isTrue);

      expect(sessionTransitions, 2);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.loginError});

  final AppFailure? loginError;
  final Completer<void> _loginCompleter = Completer<void>();
  final Completer<void> _googleLoginCompleter = Completer<void>();

  void completeLogin() {
    if (!_loginCompleter.isCompleted) {
      _loginCompleter.complete();
    }
  }

  void completeGoogleLogin() {
    if (!_googleLoginCompleter.isCompleted) {
      _googleLoginCompleter.complete();
    }
  }

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<void> login({required String identifier, required String password}) {
    final error = loginError;
    if (error != null) {
      return Future<void>.error(error);
    }
    return _loginCompleter.future;
  }

  @override
  Future<void> googleLogin({required String googleToken}) {
    return _googleLoginCompleter.future;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> register(RegisterDraft draft, String otpCode) async {}

  @override
  Future<void> sendRegisterOtp({required String identifier}) async {}

  @override
  Future<void> sendPasswordResetOtp({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) async {}

  @override
  Future<String?> getUserRole() async {
    return 'PARENT';
  }

  @override
  Future<String?> getAccountId() async => null;

  @override
  Future<AcceptInvitationModel> acceptInvitation({required String token}) async {
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

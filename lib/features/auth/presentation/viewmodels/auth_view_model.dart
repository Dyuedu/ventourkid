import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/register_draft.dart';
import '../../domain/mobile_roles.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_view_state.dart';

class AuthViewModel extends StateNotifier<AuthViewState> {
  AuthViewModel(this._repository) : super(const AuthViewState());

  final AuthRepository _repository;

  Future<bool> sendRegisterOtp({required String identifier}) {
    return _execute(
      AuthOperation.sendRegisterOtp,
      () => _repository.sendRegisterOtp(identifier: identifier),
      fallbackMessage: 'Không thể gửi mã OTP. Vui lòng thử lại.',
    );
  }

  Future<bool> register(RegisterDraft draft, String otpCode) {
    return _execute(
      AuthOperation.register,
      () => _repository.register(draft, otpCode),
      fallbackMessage: 'Không thể xác minh OTP. Vui lòng thử lại.',
      // Register API does not issue tokens — role gate belongs to login only.
    );
  }

  Future<bool> login({required String identifier, required String password}) {
    return _execute(
      AuthOperation.login,
      () => _repository.login(identifier: identifier, password: password),
      fallbackMessage: 'Không thể đăng nhập. Vui lòng thử lại.',
      enforceMobileRole: true,
    );
  }

  Future<bool> googleLogin({required String googleToken}) {
    return _execute(
      AuthOperation.googleLogin,
      () => _repository.googleLogin(googleToken: googleToken),
      fallbackMessage: 'Không thể đăng nhập bằng Google. Vui lòng thử lại.',
      enforceMobileRole: true,
    );
  }

  Future<bool> logout() {
    return _execute(
      AuthOperation.logout,
      _repository.logout,
      fallbackMessage: 'Không thể đăng xuất. Vui lòng thử lại.',
    );
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = const AuthViewState();
    }
  }

  /// Clears tokens when the JWT role is not allowed on mobile.
  /// Returns the blocked-role message, or null if the role is allowed.
  Future<String?> rejectIfMobileRoleBlocked() async {
    final role = await _repository.getUserRole();
    if (isMobileAllowedRole(role)) {
      return null;
    }
    try {
      await _repository.logout();
    } on Object {
      // Local session must still be cleared for blocked roles.
    }
    return mobileRoleBlockedMessage(role);
  }

  Future<bool> _enforceMobileRoleAllowed() async {
    final message = await rejectIfMobileRoleBlocked();
    if (message == null) {
      return true;
    }
    state = AuthViewState(errorMessage: message);
    return false;
  }

  Future<bool> _execute(
    AuthOperation operation,
    Future<void> Function() action, {
    required String fallbackMessage,
    bool enforceMobileRole = false,
  }) async {
    if (state.isLoading) {
      return false;
    }

    state = AuthViewState(operation: operation);
    try {
      await action();
      if (enforceMobileRole && !await _enforceMobileRoleAllowed()) {
        return false;
      }
      state = const AuthViewState();
      return true;
    } on Object catch (error) {
      state = AuthViewState(
        errorMessage: error is AppFailure ? error.message : fallbackMessage,
      );
      return false;
    }
  }
}

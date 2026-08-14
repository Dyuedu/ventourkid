enum AuthOperation {
  idle,
  login,
  googleLogin,
  sendRegisterOtp,
  sendPasswordResetOtp,
  resetPassword,
  register,
  logout,
}

class AuthViewState {
  const AuthViewState({this.operation = AuthOperation.idle, this.errorMessage});

  final AuthOperation operation;
  final String? errorMessage;

  bool get isLoading => operation != AuthOperation.idle;
  bool get isLoggingIn => operation == AuthOperation.login;
  bool get isGoogleLoggingIn => operation == AuthOperation.googleLogin;
  bool get isSendingRegisterOtp => operation == AuthOperation.sendRegisterOtp;
  bool get isSendingPasswordResetOtp =>
      operation == AuthOperation.sendPasswordResetOtp;
  bool get isResettingPassword => operation == AuthOperation.resetPassword;
  bool get isRegistering => operation == AuthOperation.register;
  bool get isLoggingOut => operation == AuthOperation.logout;
}

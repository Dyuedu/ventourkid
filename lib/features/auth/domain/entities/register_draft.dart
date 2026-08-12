class RegisterDraft {
  const RegisterDraft({
    required this.identifier,
    required this.fullName,
    required this.password,
    required this.termsAccepted,
  });

  final String identifier;
  final String fullName;
  final String password;
  final bool termsAccepted;
}

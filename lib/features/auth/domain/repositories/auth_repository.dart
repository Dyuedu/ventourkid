import '../entities/register_draft.dart';
import '../../data/models/accept_invitation_model.dart';

abstract interface class AuthRepository {
  Future<void> sendRegisterOtp({required String identifier});

  Future<void> register(RegisterDraft draft, String otpCode);

  Future<void> login({required String identifier, required String password});

  Future<void> googleLogin({required String googleToken});

  Future<AcceptInvitationModel> acceptInvitation({required String token});

  Future<void> setInvitationPassword({
    required String challengeToken,
    required String newPassword,
    required String confirmPassword,
  });

  Future<void> logout();

  Future<bool> isAuthenticated();

  Future<String?> getUserRole();

  Future<String?> getAccountId();
}

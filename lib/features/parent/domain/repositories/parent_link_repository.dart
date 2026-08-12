import '../../data/models/parent_link_api_models.dart';

abstract interface class ParentLinkRepository {
  Future<ParentLinkPrerequisitesModel> getPrerequisites();

  Future<List<TripLinkActivityModel>> getTripLinkCandidates();

  Future<TripLinkOtpResultModel> sendTripLinkOtp({
    required String operationPlanId,
    required TripLinkStudentMatchRequest request,
  });

  Future<void> verifyTripLinkOtp({
    required String rosterStudentId,
    required String otpCode,
  });
}

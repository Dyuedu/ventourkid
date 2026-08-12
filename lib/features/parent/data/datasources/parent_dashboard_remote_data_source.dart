import '../models/parent_dashboard_api_models.dart';

abstract interface class ParentDashboardRemoteDataSource {
  Future<List<LinkedChildModel>> getLinkedChildren();

  Future<ParentCurrentTourModel?> getCurrentTour({
    required String rosterStudentId,
    String? tourId,
  });

  Future<ParentConsentOtpModel> sendTripConsentOtp({
    required String rosterStudentId,
    required String operationPlanId,
  });

  Future<void> submitTripConsents({
    required String rosterStudentId,
    required String operationPlanId,
    required String otpCode,
    required Map<String, bool> scopes,
    required bool acceptedMandatoryTerms,
  });

  Future<Map<String, bool>> getTripConsents({
    required String rosterStudentId,
    required String operationPlanId,
  });

  /// Completed / expired-link tours for post-tour history + feedback CTA.
  Future<List<Map<String, dynamic>>> getTourHistory({
    required String rosterStudentId,
    int? year,
  });

  /// Bucketed tours for this child: upcoming / live / past / active.
  Future<Map<String, dynamic>> listChildTours({
    required String rosterStudentId,
    int? year,
  });

  /// Approved media tagged to the child (optionally scoped to one tour).
  /// Returns `{ total: int, media: List<Map> }`.
  Future<Map<String, dynamic>> getChildMedia({
    required String rosterStudentId,
    String? tourId,
    int page = 0,
    int size = 48,
  });
}

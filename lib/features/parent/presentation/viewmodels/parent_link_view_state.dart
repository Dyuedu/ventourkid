import '../../data/models/parent_link_api_models.dart';

enum ParentLinkStep {
  loading,
  profileGate,
  selectActivity,
  studentForm,
  otpVerify,
}

class ParentLinkViewState {
  const ParentLinkViewState({
    this.step = ParentLinkStep.loading,
    this.prerequisites,
    this.activities = const [],
    this.selectedActivity,
    this.otpCandidate,
    this.otpCode = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.infoMessage,
  });

  final ParentLinkStep step;
  final ParentLinkPrerequisitesModel? prerequisites;
  final List<TripLinkActivityModel> activities;
  final TripLinkActivityModel? selectedActivity;
  final TripLinkOtpResultModel? otpCandidate;
  final String otpCode;
  final bool isSubmitting;
  final String? errorMessage;
  final String? infoMessage;

  ParentLinkViewState copyWith({
    ParentLinkStep? step,
    ParentLinkPrerequisitesModel? prerequisites,
    List<TripLinkActivityModel>? activities,
    TripLinkActivityModel? selectedActivity,
    bool clearSelectedActivity = false,
    TripLinkOtpResultModel? otpCandidate,
    bool clearOtpCandidate = false,
    String? otpCode,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) {
    return ParentLinkViewState(
      step: step ?? this.step,
      prerequisites: prerequisites ?? this.prerequisites,
      activities: activities ?? this.activities,
      selectedActivity: clearSelectedActivity
          ? null
          : selectedActivity ?? this.selectedActivity,
      otpCandidate:
          clearOtpCandidate ? null : otpCandidate ?? this.otpCandidate,
      otpCode: otpCode ?? this.otpCode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearInfo ? null : infoMessage ?? this.infoMessage,
    );
  }
}

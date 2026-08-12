import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../data/models/parent_link_api_models.dart';
import '../../domain/repositories/parent_link_repository.dart';
import 'parent_link_view_state.dart';

class ParentLinkViewModel extends StateNotifier<ParentLinkViewState> {
  ParentLinkViewModel(this._repository) : super(const ParentLinkViewState());

  final ParentLinkRepository _repository;

  Future<void> initialize() async {
    state = state.copyWith(
      step: ParentLinkStep.loading,
      clearError: true,
      clearInfo: true,
      isSubmitting: false,
    );

    try {
      final prerequisites = await _repository.getPrerequisites();
      if (!prerequisites.canLink) {
        state = state.copyWith(
          step: ParentLinkStep.profileGate,
          prerequisites: prerequisites,
          errorMessage: prerequisites.message ??
              'Vui lòng cập nhật hồ sơ và số điện thoại trước khi liên kết.',
        );
        return;
      }

      final activities = await _repository.getTripLinkCandidates();
      if (activities.isEmpty) {
        state = state.copyWith(
          step: ParentLinkStep.selectActivity,
          prerequisites: prerequisites,
          activities: activities,
          infoMessage:
              'Không còn hoạt động trải nghiệm nào chờ liên kết cho tài khoản này.',
        );
        return;
      }

      final selected = activities.length == 1 ? activities.first : null;
      state = state.copyWith(
        step: selected == null
            ? ParentLinkStep.selectActivity
            : ParentLinkStep.studentForm,
        prerequisites: prerequisites,
        activities: activities,
        selectedActivity: selected,
      );
    } on AppFailure catch (error) {
      state = state.copyWith(
        step: ParentLinkStep.profileGate,
        errorMessage: error.message,
      );
    }
  }

  void selectActivity(TripLinkActivityModel activity) {
    state = state.copyWith(
      selectedActivity: activity,
      step: ParentLinkStep.studentForm,
      clearError: true,
    );
  }

  void backToStudentForm() {
    state = state.copyWith(
      step: ParentLinkStep.studentForm,
      clearOtpCandidate: true,
      otpCode: '',
      clearError: true,
      clearInfo: true,
    );
  }

  void backToActivities() {
    state = state.copyWith(
      step: ParentLinkStep.selectActivity,
      clearSelectedActivity: true,
      clearOtpCandidate: true,
      otpCode: '',
      clearError: true,
      clearInfo: true,
    );
  }

  Future<void> sendOtp({
    required String identityNumber,
    required String fullName,
    required String dateOfBirth,
  }) async {
    final activity = state.selectedActivity;
    if (activity == null) {
      state = state.copyWith(errorMessage: 'Vui lòng chọn hoạt động trải nghiệm.');
      return;
    }

    final trimmedIdentity = identityNumber.trim();
    final trimmedName = fullName.trim();
    final trimmedDob = dateOfBirth.trim();
    final hasIdentity = trimmedIdentity.isNotEmpty;
    final hasFallback = trimmedName.isNotEmpty && trimmedDob.isNotEmpty;

    if (!hasIdentity && !hasFallback) {
      state = state.copyWith(
        errorMessage:
            'Nhập mã định danh học sinh hoặc họ tên kèm ngày sinh đúng roster.',
      );
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await _repository.sendTripLinkOtp(
        operationPlanId: activity.operationPlanId,
        request: TripLinkStudentMatchRequest(
          identityNumber: hasIdentity ? trimmedIdentity : null,
          fullName: hasIdentity ? null : trimmedName,
          dateOfBirth: hasIdentity ? null : trimmedDob,
        ),
      );

      state = state.copyWith(
        isSubmitting: false,
        step: ParentLinkStep.otpVerify,
        otpCandidate: result,
        otpCode: '',
        infoMessage:
            'Đã gửi OTP tới ${result.parentPhoneMasked ?? activity.parentPhoneMasked ?? 'số điện thoại trong roster'}.',
      );
    } on AppFailure catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    }
  }

  void updateOtpCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    state = state.copyWith(otpCode: digits.length > 6 ? digits.substring(0, 6) : digits);
  }

  Future<bool> verifyOtp() async {
    final candidate = state.otpCandidate;
    if (candidate == null || candidate.rosterStudentId.isEmpty) {
      state = state.copyWith(errorMessage: 'Thiếu thông tin xác thực OTP.');
      return false;
    }
    if (state.otpCode.length != 6) {
      state = state.copyWith(errorMessage: 'Mã OTP phải gồm 6 chữ số.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.verifyTripLinkOtp(
        rosterStudentId: candidate.rosterStudentId,
        otpCode: state.otpCode,
      );
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppFailure catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    }
  }
}

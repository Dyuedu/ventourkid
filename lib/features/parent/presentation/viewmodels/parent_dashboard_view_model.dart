import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/parent_dashboard_repository.dart';
import 'parent_dashboard_view_state.dart';

class ParentDashboardViewModel extends StateNotifier<ParentDashboardViewState> {
  ParentDashboardViewModel(this._repository)
    : super(const ParentDashboardViewState());

  final ParentDashboardRepository _repository;

  Future<void> load({
    String? selectedRosterStudentId,
    String? selectedTourId,
  }) async {
    state = ParentDashboardViewState(data: state.data, isLoading: true);
    try {
      final dashboard = await _repository.getDashboard(
        selectedRosterStudentId: selectedRosterStudentId,
        selectedTourId: selectedTourId,
      );
      state = ParentDashboardViewState(data: dashboard);
    } on Object {
      state = const ParentDashboardViewState(
        errorMessage: 'Không thể tải bảng điều khiển.',
      );
    }
  }

  Future<void> selectChild(String rosterStudentId) {
    return load(selectedRosterStudentId: rosterStudentId);
  }

  Future<void> selectTour(String tourId) {
    final rosterId = state.data?.child?.rosterStudentId;
    return load(
      selectedRosterStudentId: rosterId,
      selectedTourId: tourId,
    );
  }
}

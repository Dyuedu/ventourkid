import '../entities/parent_dashboard.dart';

abstract interface class ParentDashboardRepository {
  Future<ParentDashboardData> getDashboard({
    String? selectedRosterStudentId,
    String? selectedTourId,
  });
}

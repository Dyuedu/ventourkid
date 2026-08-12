import '../../domain/entities/parent_dashboard.dart';

class ParentDashboardViewState {
  const ParentDashboardViewState({
    this.data,
    this.isLoading = false,
    this.errorMessage,
  });

  final ParentDashboardData? data;
  final bool isLoading;
  final String? errorMessage;
}

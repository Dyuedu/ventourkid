import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/parent/domain/entities/parent_dashboard.dart';
import 'package:ventourkid_mobile/features/parent/domain/repositories/parent_dashboard_repository.dart';
import 'package:ventourkid_mobile/features/parent/presentation/viewmodels/parent_dashboard_view_model.dart';

void main() {
  group('ParentDashboardViewModel', () {
    test('phát loading rồi data state khi repository thành công', () async {
      final repository = _FakeParentDashboardRepository();
      final viewModel = ParentDashboardViewModel(repository);
      addTearDown(viewModel.dispose);

      final loadFuture = viewModel.load();
      expect(viewModel.state.isLoading, isTrue);

      repository.complete(_dashboard);
      await loadFuture;

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.data, same(_dashboard));
      expect(viewModel.state.errorMessage, isNull);
    });

    test('phát error state khi repository thất bại', () async {
      final viewModel = ParentDashboardViewModel(
        _FailingParentDashboardRepository(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.state.data, isNull);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.errorMessage, isNotNull);
    });
  });
}

const _dashboard = ParentDashboardData(
  updatedLabel: 'Vừa cập nhật',
  notificationCount: 0,
  currentJourney: ParentJourneySummary(
    name: 'Chuyến đi thử nghiệm',
    statusLabel: 'Đang di chuyển',
    remainingDistance: '1 km',
    estimatedArrival: '10:00',
    punctualityLabel: 'Đúng giờ',
  ),
  quickActions: [],
  recentAlerts: [],
);

class _FakeParentDashboardRepository implements ParentDashboardRepository {
  final Completer<ParentDashboardData> _completer =
      Completer<ParentDashboardData>();

  void complete(ParentDashboardData data) => _completer.complete(data);

  @override
  Future<ParentDashboardData> getDashboard({String? selectedRosterStudentId, String? selectedTourId}) =>
      _completer.future;
}

class _FailingParentDashboardRepository implements ParentDashboardRepository {
  @override
  Future<ParentDashboardData> getDashboard({String? selectedRosterStudentId, String? selectedTourId}) {
    return Future<ParentDashboardData>.error(StateError('load failed'));
  }
}

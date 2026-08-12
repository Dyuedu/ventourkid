import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/app/providers.dart';
import 'package:ventourkid_mobile/features/parent/data/datasources/parent_dashboard_local_data_source.dart';
import 'package:ventourkid_mobile/features/parent/domain/entities/parent_dashboard.dart';
import 'package:ventourkid_mobile/features/parent/domain/repositories/parent_dashboard_repository.dart';
import 'package:ventourkid_mobile/features/parent/presentation/views/parent_dashboard_page.dart';
import 'package:ventourkid_mobile/shared/theme/app_theme.dart';

class _LocalOnlyParentDashboardRepository implements ParentDashboardRepository {
  @override
  Future<ParentDashboardData> getDashboard({String? selectedRosterStudentId, String? selectedTourId}) {
    return const ParentDashboardLocalDataSourceImpl().getDashboard();
  }
}

void main() {
  testWidgets('shows parent UC-PAR dashboard actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parentDashboardRepositoryProvider.overrideWithValue(
            _LocalOnlyParentDashboardRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ParentDashboardPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bảng điều khiển phụ huynh'), findsOneWidget);
    expect(find.text('Không có tour nào đang diễn ra'), findsOneWidget);
    expect(find.text('Cảnh báo gần đây'), findsNothing);
    expect(find.text('Liên kết con'), findsOneWidget);
    expect(find.text('Livestream'), findsNothing);

    expect(find.text('Thêm thao tác'), findsOneWidget);
  });
}

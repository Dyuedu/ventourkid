import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../attendance/domain/entities/offline_attendance.dart';

class FoodAllergyAlertsPage extends ConsumerStatefulWidget {
  const FoodAllergyAlertsPage({super.key, required this.tourId, this.tourName});

  final String tourId;
  final String? tourName;

  @override
  ConsumerState<FoodAllergyAlertsPage> createState() => _FoodAllergyAlertsPageState();
}

class _FoodAllergyAlertsPageState extends ConsumerState<FoodAllergyAlertsPage> {
  List<FieldFoodAllergyAlert> _alerts = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final alerts = await ref
          .read(offlineAttendanceRepositoryProvider)
          .listFoodAllergyAlerts(widget.tourId);
      if (mounted) setState(() => _alerts = alerts);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<FieldFoodAllergyAlert>>{};
    for (final alert in _alerts) {
      grouped.putIfAbsent(alert.vehicleLabel, () => []).add(alert);
    }
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: const Text('Dị ứng thực phẩm'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SafetyHeader(tourName: widget.tourName, count: _alerts.length),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(onRetry: _load)
            else if (grouped.isEmpty)
              const _EmptyState()
            else
              for (final entry in grouped.entries) ...[
                _VehicleHeader(label: entry.key, count: entry.value.length),
                const SizedBox(height: 8),
                for (final alert in entry.value) ...[
                  _AllergyAlertCard(alert: alert),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _SafetyHeader extends StatelessWidget {
  const _SafetyHeader({this.tourName, required this.count});
  final String? tourName;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        label: '$count học sinh cần lưu ý về dị ứng thực phẩm',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Danh sách an toàn theo xe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF7F1D1D))),
                  const SizedBox(height: 4),
                  Text(
                    '${tourName ?? 'Tour đang chọn'} · $count học sinh có dị ứng thực phẩm. Chỉ hiển thị các xe bạn được phân công.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF991B1B), height: 1.4),
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Row(children: [
          const Icon(Icons.directions_bus_rounded, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.ink))),
          Text('$count HS', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.onSurfaceVariant)),
        ]),
      );
}

class _AllergyAlertCard extends StatelessWidget {
  const _AllergyAlertCard({required this.alert});
  final FieldFoodAllergyAlert alert;

  @override
  Widget build(BuildContext context) {
    final critical = alert.severity == 'CRITICAL';
    final color = critical ? const Color(0xFFB91C1C) : const Color(0xFFB45309);
    final background = critical ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB);
    return Semantics(
      label: '${alert.fullName}, dị ứng ${alert.foodAllergies}, mức ${alert.severity}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: color.withValues(alpha: 0.28))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(alert.fullName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.ink))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)), child: Text(alert.severity, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))),
          ]),
          if (alert.className?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text('Lớp ${alert.className}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          _DetailLine(icon: Icons.restaurant_outlined, label: 'Dị ứng', value: alert.foodAllergies, color: color),
          if (alert.dietaryRestrictions?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _DetailLine(icon: Icons.no_food_outlined, label: 'Chế độ ăn', value: alert.dietaryRestrictions!, color: AppTheme.ink),
          ],
          if (alert.emergencyNote?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _DetailLine(icon: Icons.emergency_outlined, label: 'Khẩn cấp', value: alert.emergencyNote!, color: const Color(0xFFB91C1C)),
          ],
        ]),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: RichText(text: TextSpan(style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.ink, height: 1.35), children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: value)]))),
      ]);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Column(children: [
          Icon(Icons.verified_user_outlined, size: 48, color: const Color(0xFF15803D)),
          const SizedBox(height: 12),
          Text('Không có dị ứng thực phẩm cần lưu ý', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Trong các xe bạn được phân công hiện chưa có học sinh khai báo dị ứng thực phẩm.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant)),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Column(children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Không tải được danh sách dị ứng', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
        ]),
      );
}

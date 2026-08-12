import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../domain/models/tracker_location_view_model.dart';
import '../../providers.dart';

class TrackingOperationsScreen extends ConsumerStatefulWidget {
  const TrackingOperationsScreen({super.key});

  @override
  ConsumerState<TrackingOperationsScreen> createState() =>
      _TrackingOperationsScreenState();
}

class _TrackingOperationsScreenState
    extends ConsumerState<TrackingOperationsScreen> {
  bool _loading = true;
  String? _error;
  List<TrackingOperationViewModel> _operations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final operations = await ref
          .read(trackingRemoteDataSourceProvider)
          .getOperations();
      if (mounted)
        setState(() {
          _operations = operations;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = ApiException.userMessage(
            error,
            fallback: 'Không tải được danh sách chuyến đi. Vui lòng thử lại.',
          );
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: buildAppBackLeading(
          context,
          fallbackRoute: '/parent/dashboard',
        ),
        title: const Text('Chuyến đi được phân quyền'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                ],
              )
            : _operations.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Không có chuyến đi trong phạm vi của bạn.'),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _operations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final operation = _operations[index];
                  final date = operation.tourDate == null
                      ? 'Chưa xếp lịch'
                      : DateFormat('dd/MM/yyyy').format(operation.tourDate!);
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.directions_bus_outlined),
                      title: Text(operation.schoolName ?? 'Chuyến đi'),
                      subtitle: Text(
                        '$date · ${operation.status} · ${operation.vehicleCount} xe',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/tracking/${operation.operationPlanId}',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

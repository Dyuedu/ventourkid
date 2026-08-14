import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../data/datasources/tracking_remote_data_source.dart';
import '../../domain/models/tracker_location_view_model.dart';
import '../../providers.dart';
import '../widgets/map4d_map_panel.dart';
import 'replacement_scanner_screen.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.operationPlanId});

  final String operationPlanId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  StreamSubscription<TrackingRealtimeMessage>? _realtimeSubscription;
  TrackingSnapshotViewModel _snapshot = const TrackingSnapshotViewModel(
    locations: [],
    checkpoints: [],
    alerts: [],
  );
  bool _loading = true;
  bool _isGuide = false;
  bool _isParent = false;
  bool _canReplaceTracker = false;
  List<Map<String, dynamic>> _backupDevices = const [];
  String? _error;
  String _connection = 'CONNECTING';
  String? _lastEventId;
  String? _selectedAssignmentId;
  int _reconnectAttempt = 0;

  TrackingRemoteDataSource get _remote =>
      ref.read(trackingRemoteDataSourceProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_loadRole());
    unawaited(_loadBackupDevices());
    unawaited(_loadSnapshot().then((_) => _connectRealtime()));
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_connection != 'LIVE') unawaited(_loadSnapshot(background: true));
    });
  }

  Future<void> _loadBackupDevices() async {
    try {
      final devices = await _remote.getMyBackupDevices(widget.operationPlanId);
      if (mounted) setState(() => _backupDevices = devices);
    } on Object {
      // The replacement flow remains usable; the server is the authority for custody validation.
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final role = await ref.read(routeGuardsProvider).userRole;
    final accessToken = await ref.read(tokenStorageProvider).getAccessToken();
    if (!mounted) return;
    setState(() {
      _isGuide = role == 'TOUR_GUIDE';
      _isParent = role == 'PARENT';
      _canReplaceTracker = _tokenHasPermission(
        accessToken,
        'TRACKING_REPLACE',
      );
    });
  }

  bool _tokenHasPermission(String? token, String permission) {
    if (token == null || token.isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final permissions = payload is Map ? payload['permissions'] : null;
      return permissions is List &&
          permissions.any((item) => item?.toString() == permission);
    } on Object {
      return false;
    }
  }

  Future<void> _replaceDevice() async {
    final selected = _selectedLocation;
    if (selected == null || !_canReplaceTracker) return;
    final replaced = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReplacementScannerScreen(
          assignmentId: selected.assignmentId,
          targetLabel: selected.displayTitle,
          targetType: selected.isVehicle ? 'xe' : 'học sinh',
        ),
      ),
    );
    if (replaced == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thay thiết bị GPS.')),
      );
      await _loadSnapshot(background: true);
      await _loadBackupDevices();
    }
  }

  Future<void> _loadSnapshot({bool background = false}) async {
    if (!background && mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final snapshot = await _remote.getSnapshot(widget.operationPlanId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
        _selectedAssignmentId ??= snapshot.locations.isEmpty
            ? null
            : snapshot.locations.first.assignmentId;
      });
      unawaited(ref.read(trackingOfflineOutboxProvider).flush(_remote));
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = ApiException.userMessage(
            error,
            fallback: 'Không tải được dữ liệu theo dõi. Vui lòng thử lại.',
          );
        });
    }
  }

  Future<void> _connectRealtime() async {
    await _realtimeSubscription?.cancel();
    if (!mounted) return;
    setState(
      () =>
          _connection = _reconnectAttempt == 0 ? 'CONNECTING' : 'RECONNECTING',
    );
    _realtimeSubscription = _remote
        .openRealtime(widget.operationPlanId, lastEventId: _lastEventId)
        .listen(
          _handleRealtime,
          onError: (_) => _scheduleReconnect(),
          onDone: _scheduleReconnect,
          cancelOnError: true,
        );
  }

  void _handleRealtime(TrackingRealtimeMessage message) {
    if (!mounted) return;
    if (message.id != null && message.id != '0') _lastEventId = message.id;
    if (message.type == 'stream.ready') {
      setState(() {
        _connection = 'LIVE';
        _reconnectAttempt = 0;
        _error = null;
      });
      return;
    }
    if (message.type == 'stream.reset') {
      unawaited(_loadSnapshot(background: true));
      return;
    }
    if (message.type == 'checkpoint.updated') {
      unawaited(_loadSnapshot(background: true));
      return;
    }
    if (message.type == 'location.updated') {
      final assignmentId = message.data['assignmentId']?.toString();
      if (assignmentId == null) return;
      final locations = [..._snapshot.locations];
      final index = locations.indexWhere(
        (item) => item.assignmentId == assignmentId,
      );
      try {
        if (index >= 0) {
          locations[index] = locations[index].mergeRealtime(message.data);
        } else if (_isParent) {
          // Parent snapshot is already scoped — ignore other trackers from SSE.
          return;
        } else {
          locations.add(TrackerLocationViewModel.fromJson(message.data));
        }
        setState(
          () => _snapshot = TrackingSnapshotViewModel(
            locations: locations,
            checkpoints: _snapshot.checkpoints,
            alerts: _snapshot.alerts,
            etas: _snapshot.etas,
          ),
        );
      } on FormatException {
        unawaited(_loadSnapshot(background: true));
      }
      return;
    }
    if (message.type == 'eta.updated') {
      unawaited(_loadSnapshot(background: true));
      return;
    }
    if (message.type == 'device.state.changed') {
      final assignmentId = message.data['assignmentId']?.toString();
      final state = message.data['state']?.toString();
      if (assignmentId == null || state == null) return;
      setState(
        () => _snapshot = TrackingSnapshotViewModel(
          locations: _snapshot.locations
              .map(
                (item) => item.assignmentId == assignmentId
                    ? item.copyWith(signalStatus: state)
                    : item,
              )
              .toList(growable: false),
          checkpoints: _snapshot.checkpoints,
          alerts: _snapshot.alerts,
          etas: _snapshot.etas,
        ),
      );
      return;
    }
    if (message.type == 'alert.updated') {
      final next = TrackingAlertViewModel.fromJson(message.data);
      if (_isParent &&
          next.assignmentId != null &&
          !_snapshot.locations.any(
            (item) => item.assignmentId == next.assignmentId,
          )) {
        return;
      }
      final alerts = [..._snapshot.alerts]
        ..removeWhere((item) => item.id == next.id);
      if (next.status != 'RESOLVED' && next.status != 'SUPPRESSED') {
        alerts.insert(0, next);
      }
      setState(
        () => _snapshot = TrackingSnapshotViewModel(
          locations: _snapshot.locations,
          checkpoints: _snapshot.checkpoints,
          alerts: alerts,
          etas: _snapshot.etas,
        ),
      );
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _realtimeSubscription = null;
    setState(() => _connection = 'POLLING');
    _reconnectTimer?.cancel();
    final cappedAttempt = _reconnectAttempt > 5 ? 5 : _reconnectAttempt;
    final seconds = 1 << cappedAttempt;
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _connectRealtime);
  }

  TrackerLocationViewModel? get _selectedLocation {
    for (final location in _snapshot.locations) {
      if (location.assignmentId == _selectedAssignmentId) return location;
    }
    return _snapshot.locations.isEmpty ? null : _snapshot.locations.first;
  }

  Future<void> _acknowledge(TrackingAlertViewModel alert) async {
    try {
      await _remote.acknowledgeAlert(widget.operationPlanId, alert.id);
      await _loadSnapshot(background: true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiException.userMessage(
                error,
                fallback: 'Không xác nhận được cảnh báo. Vui lòng thử lại.',
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedLocation;
    final vehicles = _snapshot.locations.where((item) => item.isVehicle).toList();
    final students =
        _snapshot.locations.where((item) => item.isStudent).toList();
    final selectedEta = _etaForAssignment(selected?.assignmentId);
    final nextCheckpoint = _checkpointForEta(selectedEta);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(
          context,
          fallbackRoute: '/tracking',
        ),
        title: const Text('Theo dõi an toàn'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Chip(
              backgroundColor: AppTheme.primarySoft,
              avatar: Icon(
                _connection == 'LIVE' ? Iconsax.wifi : Iconsax.wifi_square,
                size: 17,
                color: AppTheme.primary,
              ),
              label: Text(
                _connection == 'LIVE'
                    ? 'Trực tiếp'
                    : _connection == 'POLLING'
                    ? 'Định kỳ'
                    : 'Đang nối',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            onPressed: () => _loadSnapshot(),
            icon: const Icon(Iconsax.refresh_2),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Map4dMapPanel(
              locations: _snapshot.locations,
              checkpoints: _snapshot.checkpoints,
              selectedAssignmentId: _selectedAssignmentId,
              onSelectAssignment: (id) =>
                  setState(() => _selectedAssignmentId = id),
            ),
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: MaterialBanner(
                backgroundColor: AppTheme.primarySoft,
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: () => _loadSnapshot(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          if (selectedEta != null)
            Positioned(
              left: 12,
              right: 12,
              top: _error != null ? 72 : 12,
              child: _EtaCard(
                eta: selectedEta,
                checkpointName: nextCheckpoint?.name,
                vehicleLabel: selected?.displayTitle,
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: 0.16,
            maxChildSize: 0.76,
            builder: (context, controller) => Material(
              elevation: 12,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
              clipBehavior: Clip.antiAlias,
              color: AppTheme.surface,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isParent ? 'Xe của con' : 'Xe',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  if (vehicles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _isParent
                            ? 'Con bạn chưa được phân vào xe trên tour này.'
                            : 'Chưa có xe đang theo dõi.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ...vehicles.map(
                    (location) => _TrackerTile(
                      location: location,
                      selected: location.assignmentId == selected?.assignmentId,
                      onTap: () => setState(
                        () => _selectedAssignmentId = location.assignmentId,
                      ),
                    ),
                  ),
                  if (!_isParent || students.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _isParent ? 'GPS của con' : 'Học sinh GPS',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    if (students.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Chưa có học sinh được gán thiết bị GPS.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                  ...students.map(
                      (location) => _TrackerTile(
                        location: location,
                        selected:
                            location.assignmentId == selected?.assignmentId,
                        onTap: () => setState(
                          () => _selectedAssignmentId = location.assignmentId,
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  if (_isGuide) ...[
                    Text('GPS dự phòng tôi đang giữ', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (_backupDevices.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Chưa có GPS dự phòng được bàn giao.'))
                    else
                      ..._backupDevices.map((device) => ListTile(
                        dense: true,
                        leading: const Icon(Iconsax.gps),
                        title: Text(device['deviceCode']?.toString() ?? '-'),
                        subtitle: const Text('Đã bàn giao cho bạn'),
                      )),
                    const Divider(height: 28),
                  ],
                  Text(
                    'Lịch trình',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CheckpointTimeline(
                    checkpoints: _snapshot.checkpoints
                        .toList()
                        ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo)),
                  ),
                  if (_canReplaceTracker && selected != null) ...[
                    const Divider(height: 28),
                    OutlinedButton.icon(
                      onPressed: _replaceDevice,
                      icon: const Icon(Iconsax.scan_barcode),
                      label: Text(
                        'Thay thiết bị GPS cho ${selected.isVehicle ? 'xe' : 'học sinh'}',
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  Text(
                    'Cảnh báo',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_snapshot.alerts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Không có cảnh báo đang mở.'),
                    ),
                  ..._snapshot.alerts.map(
                    (alert) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Iconsax.warning_2,
                        color: alert.severity == 'CRITICAL'
                            ? AppTheme.accentRed
                            : AppTheme.accentOrange,
                      ),
                      title: Text(alert.title),
                      subtitle: Text(alert.message),
                      trailing: _isGuide && alert.status == 'OPEN'
                          ? IconButton(
                              onPressed: () => _acknowledge(alert),
                              icon: const Icon(Iconsax.tick_circle),
                              tooltip: 'Xác nhận',
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TrackingEtaViewModel? _etaForAssignment(String? assignmentId) {
    if (_snapshot.etas.isEmpty) return null;
    if (assignmentId != null) {
      for (final eta in _snapshot.etas) {
        if (eta.assignmentId == assignmentId) return eta;
      }
      final selected = _selectedLocation;
      if (selected?.coLocatedVehicleId != null) {
        for (final location in _snapshot.locations) {
          if (location.isVehicle &&
              location.targetId == selected!.coLocatedVehicleId) {
            for (final eta in _snapshot.etas) {
              if (eta.assignmentId == location.assignmentId) return eta;
            }
          }
        }
      }
    }
    // Prefer ETA of selected vehicle, else first vehicle ETA, else first ETA.
    for (final location in _snapshot.locations) {
      if (!location.isVehicle) continue;
      for (final eta in _snapshot.etas) {
        if (eta.assignmentId == location.assignmentId) return eta;
      }
    }
    return _snapshot.etas.first;
  }

  TrackingCheckpointViewModel? _checkpointForEta(TrackingEtaViewModel? eta) {
    if (eta?.checkpointId == null) return null;
    for (final checkpoint in _snapshot.checkpoints) {
      if (checkpoint.id == eta!.checkpointId) return checkpoint;
    }
    return null;
  }
}

class _TrackerTile extends StatelessWidget {
  const _TrackerTile({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final TrackerLocationViewModel location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code = location.deviceCode?.trim();
    final statusParts = <String>[
      if (!location.hasLiveSignal)
        location.hasCoordinates
            ? location.signalStatus
            : 'Chưa có tín hiệu vị trí'
      else
        location.signalStatus,
      if (code != null && code.isNotEmpty) code,
      if (location.showsBattery) 'Pin ${location.batteryLevel}%',
      if (location.isVehicleProxy) 'Đang trên xe',
    ];

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      selected: selected,
      leading: Icon(
        location.isStudent ? Iconsax.profile_2user : Iconsax.bus,
        color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
      ),
      title: Text(
        location.displayTitle,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? AppTheme.primary : AppTheme.ink,
        ),
      ),
      subtitle: Text(
        statusParts.join(' · '),
        style: TextStyle(
          color: location.hasCoordinates
              ? AppTheme.onSurfaceVariant
              : AppTheme.accentOrange,
        ),
      ),
      trailing: selected
          ? const Icon(Iconsax.tick_circle, color: AppTheme.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({
    required this.eta,
    this.checkpointName,
    this.vehicleLabel,
  });

  final TrackingEtaViewModel eta;
  final String? checkpointName;
  final String? vehicleLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              eta.delayed || !eta.hasRouteEstimate
                  ? Icons.schedule
                  : Icons.navigation_outlined,
              color: eta.delayed || !eta.hasRouteEstimate
                  ? AppTheme.accentOrange
                  : AppTheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    checkpointName == null
                        ? 'Điểm dừng tiếp theo'
                        : 'Đến: $checkpointName',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    eta.hasRouteEstimate
                        ? [
                            if (vehicleLabel != null) vehicleLabel!,
                            eta.distanceLabel,
                            eta.durationLabel,
                            if (eta.delayed) 'Trễ',
                            if (eta.availabilityLabel != null)
                              eta.availabilityLabel!,
                          ].join(' · ')
                        : eta.availabilityLabel ??
                            'Đang chờ tính thời gian đến',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointTimeline extends StatelessWidget {
  const _CheckpointTimeline({required this.checkpoints});

  final List<TrackingCheckpointViewModel> checkpoints;

  static const _completedColor = Color(0xFF2E7D32);
  static const _arrivedColor = Color(0xFFED6C02);
  static const _pendingColor = Color(0xFFB0BEC5);
  static const _lineColor = Color(0xFFCFD8DC);

  Color _nodeColor(TrackingCheckpointViewModel cp) {
    final status = cp.locationStatus?.toUpperCase() ?? '';
    if (status == 'COMPLETED') return _completedColor;
    if (status == 'ARRIVED' || status == 'CURRENT') return _arrivedColor;
    return _pendingColor;
  }

  String _typeLabel(TrackingCheckpointViewModel cp) {
    switch (cp.checkpointType.toUpperCase()) {
      case 'PICKUP':
        return 'Xuất phát';
      case 'DROPOFF':
        return 'Kết thúc';
      case 'SCHOOL':
        return 'Trường';
      default:
        return cp.address?.isNotEmpty == true ? cp.address! : 'Điểm đến';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checkpoints.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Chưa có lịch trình.'),
      );
    }
    return Column(
      children: List.generate(checkpoints.length, (index) {
        final cp = checkpoints[index];
        final isLast = index == checkpoints.length - 1;
        final color = _nodeColor(cp);
        final isCompleted =
            (cp.locationStatus?.toUpperCase() ?? '') == 'COMPLETED';
        final isActive = (cp.locationStatus?.toUpperCase() ?? '') == 'ARRIVED' ||
            (cp.locationStatus?.toUpperCase() ?? '') == 'CURRENT';

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: line + node
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    // line above
                    if (index == 0)
                      const SizedBox(height: 16)
                    else
                      Expanded(
                        child: Container(
                          width: 2,
                          color: _lineColor,
                        ),
                      ),
                    // node circle
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: _arrivedColor.withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check
                            : isActive
                                ? Icons.location_on
                                : Icons.radio_button_unchecked,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    // line below
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: _lineColor,
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cp.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isCompleted
                              ? _completedColor
                              : isActive
                                  ? _arrivedColor
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _typeLabel(cp),
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? _completedColor.withOpacity(0.8)
                              : Colors.grey,
                        ),
                      ),
                      if (cp.plannedStart != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          () {
                            final local = cp.plannedStart!.toLocal();
                            return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                          }(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}


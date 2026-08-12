import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';

/// Persistent application navigation for field staff. Parent screens retain
/// their separate navigation because their destinations are child-specific.
class FieldAppShell extends ConsumerStatefulWidget {
  const FieldAppShell({
    super.key,
    required this.location,
    required this.tourId,
    required this.child,
  });

  final String location;
  final String? tourId;
  final Widget child;

  @override
  ConsumerState<FieldAppShell> createState() => _FieldAppShellState();
}

class _FieldAppShellState extends ConsumerState<FieldAppShell> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void didUpdateWidget(covariant FieldAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ShellRoute keeps this State alive across login/logout; refresh role
    // whenever the active route changes.
    if (oldWidget.location != widget.location) {
      _loadRole();
    }
  }

  Future<void> _loadRole() async {
    final role = await ref.read(routeGuardsProvider).userRole;
    if (mounted && _role != role) {
      setState(() => _role = role);
    }
  }

  bool get _isFieldRole => _role == 'TOUR_GUIDE' || _role == 'TEACHER';

  /// Parent + public auth screens own their chrome; never nest the field bar.
  bool get _shouldShowFieldNav {
    final path = widget.location;
    if (path.startsWith('/parent') ||
        path == '/login' ||
        path == '/register-parent' ||
        path == '/forgot-password' ||
        path == '/verify-otp' ||
        path.startsWith('/invite/') ||
        path.startsWith('/consent/')) {
      return false;
    }
    return _isFieldRole;
  }

  Future<String?> _resolveTourId() async {
    final routeTourId = widget.tourId;
    if (routeTourId != null && routeTourId.isNotEmpty) return routeTourId;

    final repository = ref.read(offlineAttendanceRepositoryProvider);
    try {
      final activeTours = await repository.refreshTours();
      if (activeTours.isNotEmpty) return activeTours.first.tourId;
    } on Object {
      // The local list is sufficient for navigation while the device is offline.
    }
    final cachedTours = await repository.getCachedTours();
    return cachedTours.isEmpty ? null : cachedTours.first.tourId;
  }

  Future<void> _openItinerary() async {
    final tourId = await _resolveTourId();
    if (!mounted) return;
    if (tourId == null || tourId.isEmpty) {
      context.go(
        _role == 'TEACHER' ? '/teacher/dashboard' : '/guide/dashboard',
      );
      return;
    }
    context.go('/guide/itinerary?tourId=$tourId');
  }

  Future<void> _openTracking() async {
    final tourId = await _resolveTourId();
    if (!mounted) return;
    context.go(tourId == null || tourId.isEmpty ? '/tracking' : '/tracking/$tourId');
  }

  int get _selectedIndex {
    final path = widget.location;
    if (path.startsWith('/guide/itinerary')) return 1;
    if (path.startsWith('/tracking')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Login/logout writes tokens while ShellRoute keeps this State alive.
    ref.listen(authViewModelProvider, (_, __) => _loadRole());

    if (!_shouldShowFieldNav) return widget.child;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go(
                _role == 'TEACHER'
                    ? '/teacher/dashboard'
                    : '/guide/dashboard',
              );
              break;
            case 1:
              _openItinerary();
              break;
            case 2:
              _openTracking();
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Điều khiển',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Lịch trình',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Theo dõi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Widget? buildAppBackLeading(
  BuildContext context, {
  String? fallbackRoute,
  Color? color,
}) {
  final canPop = context.canPop() || Navigator.of(context).canPop();
  if (!canPop && (fallbackRoute == null || fallbackRoute.isEmpty)) {
    return null;
  }
  return AppBackLeading(fallbackRoute: fallbackRoute, color: color);
}

class AppBackLeading extends StatelessWidget {
  const AppBackLeading({super.key, this.fallbackRoute, this.color});

  final String? fallbackRoute;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Quay lại',
      icon: const Icon(Icons.arrow_back_rounded),
      color: color,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }
        final route = fallbackRoute;
        if (route != null && route.isNotEmpty) {
          context.go(route);
        }
      },
    );
  }
}

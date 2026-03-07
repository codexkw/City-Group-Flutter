import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';

/// Shared bottom navigation bar used across main screens.
/// [currentIndex]: 0=Home, 1=Tasks, 2=Attendance, 3=Profile
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == currentIndex) return;
        switch (index) {
          case 0:
            context.go(AppRoutes.home);
          case 1:
            context.push(AppRoutes.tasks);
          case 2:
            context.push(AppRoutes.attendanceHistory);
          case 3:
            context.push(AppRoutes.profile);
        }
      },
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n.home),
        BottomNavigationBarItem(icon: const Icon(Icons.task_alt), label: l10n.tasks),
        BottomNavigationBarItem(icon: const Icon(Icons.access_time), label: l10n.attendance),
        BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.profile),
      ],
    );
  }
}

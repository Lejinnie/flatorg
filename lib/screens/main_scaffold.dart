import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/strings.dart';
import '../router/app_router.dart';

/// Shared scaffold for the three main tabs: Tasks, Shopping, Issues.
///
/// Wraps [child] with a [BottomNavigationBar] that navigates via GoRouter.
/// [currentIndex] must match the tab order (0=Tasks, 1=Shopping, 2=Issues).
class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  static const List<String> _routes = [
    routeTasks,
    routeShopping,
    routeIssues,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          if (i != currentIndex) context.go(_routes[i]);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: navTasks,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: navShopping,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem_outlined),
            activeIcon: Icon(Icons.report_problem),
            label: navIssues,
          ),
        ],
      ),
    );
  }
}

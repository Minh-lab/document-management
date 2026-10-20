import 'package:flutter/material.dart';

import '../colors.dart';
import '../utils/responsive.dart';

class AppDestination {
  const AppDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Khung ứng dụng thích ứng:
/// - Mobile: bottom navigation.
/// - Tablet: navigation rail thu gọn.
/// - Web/desktop: navigation rail mở rộng.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompact;

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: isCompact
          ? body
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  extended: context.isExpanded,
                  minExtendedWidth: 220,
                  backgroundColor: AppColors.surface,
                  labelType: context.isExpanded
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.selected,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _RailLogo(extended: context.isExpanded),
                  ),
                  destinations: destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations
                  .map(
                    (destination) => NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.school_outlined, color: Colors.white, size: 22),
    );

    if (!extended) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 12),
        const Text(
          'StudyDocs',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

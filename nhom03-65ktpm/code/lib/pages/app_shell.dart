import 'package:flutter/material.dart';

import '../widgets/notification_bell_button.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/user_menu_button.dart';
import 'document_list_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

/// Khung chính sau khi đăng nhập, chứa các tab và điều hướng thích ứng.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    AppDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Trang chủ',
    ),
    AppDestination(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      label: 'Tài liệu',
    ),
    AppDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Cài đặt',
    ),
  ];

  String get _title {
    switch (_selectedIndex) {
      case 0:
        return 'Trang chủ';
      case 1:
        return 'Tài liệu của tôi';
      default:
        return 'Cài đặt';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: _title,
      destinations: _destinations,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      actions: [
        const NotificationBellButton(),
        UserMenuButton(
          onOpenSettings: () => setState(() => _selectedIndex = 2),
        ),
      ],
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            onViewAllDocuments: () => setState(() => _selectedIndex = 1),
          ),
          const DocumentListPage(),
          const SettingsPage(),
        ],
      ),
    );
  }
}

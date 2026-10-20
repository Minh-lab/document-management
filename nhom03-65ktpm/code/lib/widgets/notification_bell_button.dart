import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../colors.dart';
import '../functions.dart';
import '../pages/notifications_page.dart';

/// Chuông thông báo trên AppBar kèm badge số thông báo chưa đọc.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _unreadCount = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _subscribe();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) supabaseService.unsubscribe(channel);
    super.dispose();
  }

  Future<void> _loadCount() async {
    try {
      final count = await getUnreadNotificationCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadCount = 0);
    }
  }

  void _subscribe() {
    if (currentUserId.isEmpty) return;
    _channel = supabaseService.subscribeToNotifications(
      userId: currentUserId,
      onChanged: _loadCount,
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    if (mounted) _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Thông báo',
      onPressed: _openNotifications,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (_unreadCount > 0)
            Positioned(
              right: -7,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

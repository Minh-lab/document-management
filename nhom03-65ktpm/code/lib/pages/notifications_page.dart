import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../colors.dart';
import '../functions.dart';
import '../struct/notification_model.dart';
import '../utils/responsive.dart';
import '../widgets/state_views.dart';
import 'document_detail_page.dart';

/// Trung tâm thông báo trong ứng dụng.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  int get _unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) supabaseService.unsubscribe(channel);
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final notifications = await getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _subscribe() {
    if (currentUserId.isEmpty) return;
    _channel = supabaseService.subscribeToNotifications(
      userId: currentUserId,
      onChanged: () => _load(showLoading: false),
    );
  }

  Future<void> _markAllRead() async {
    try {
      await markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((notification) => notification.copyWith(isRead: true))
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu tất cả thông báo là đã đọc')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể cập nhật: $error')));
    }
  }

  Future<void> _openNotification(NotificationModel notification) async {
    if (!notification.isRead) {
      try {
        await markNotificationRead(notification.id);
        if (!mounted) return;
        setState(() {
          _notifications = _notifications
              .map(
                (item) => item.id == notification.id
                    ? item.copyWith(isRead: true)
                    : item,
              )
              .toList();
        });
      } catch (error) {
        debugPrint('Không đánh dấu được thông báo đã đọc: $error');
      }
    }

    final documentId = notification.documentId;
    if (documentId == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailPage(documentId: documentId),
      ),
    );
    if (mounted) _load(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thông báo'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _unreadCount > 0 ? _markAllRead : null,
            child: const Text('Đọc tất cả'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingView(message: 'Đang tải thông báo...');
    }

    if (_error != null) {
      return AppErrorView(
        title: 'Không thể tải thông báo',
        message: _error!,
        onRetry: _load,
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          children: const [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'Chưa có thông báo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Thông báo về tài liệu được chia sẻ và yêu cầu mượn sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ContentWidth(
        maxWidth: 860,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.pagePadding,
          itemCount: _notifications.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            return _NotificationTile(
              notification: notification,
              onTap: () => _openNotification(notification),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final style = _styleFor(notification.type);

    return Material(
      color: unread ? const Color(0xFFF0F7FF) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unread ? const Color(0xFFBBDEFB) : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.isCompact ? 12 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: style.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.body != null &&
                        notification.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.documentId != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationStyle {
  const _NotificationStyle({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

_NotificationStyle _styleFor(String type) {
  switch (type) {
    case 'share':
      return const _NotificationStyle(
        icon: Icons.share_outlined,
        color: AppColors.primary,
        background: AppColors.primaryLight,
      );
    case 'borrow':
      return const _NotificationStyle(
        icon: Icons.swap_horiz_rounded,
        color: AppColors.warning,
        background: Color(0xFFFFF7E6),
      );
    case 'document':
      return const _NotificationStyle(
        icon: Icons.description_outlined,
        color: AppColors.success,
        background: Color(0xFFECFDF3),
      );
    default:
      return const _NotificationStyle(
        icon: Icons.notifications_none_rounded,
        color: AppColors.textSecondary,
        background: Color(0xFFF1F5F9),
      );
  }
}

String _timeAgo(DateTime date) {
  final local = date.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.inMinutes < 1) return 'Vừa xong';
  if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
  if (difference.inDays < 1) return '${difference.inHours} giờ trước';
  if (difference.inDays < 7) return '${difference.inDays} ngày trước';

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

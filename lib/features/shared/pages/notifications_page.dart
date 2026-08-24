import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/notification_navigation.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';

/// Écran listant les notifications reçues (30 derniers jours).
///
/// Sans cet écran, une notification manquée ou balayée était définitivement
/// perdue : rien dans l'application ne permettait de la retrouver.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final PushNotificationService _service = PushNotificationService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final notifications = await _service.getRecentNotifications();

      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      // Un échec réseau ne doit pas se déguiser en « لا توجد إشعارات » :
      // l'écran l'affiche explicitement, avec un bouton pour réessayer.
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذّر تحميل الإشعارات. تحقق من الاتصال بالإنترنت.';
        _isLoading = false;
      });
    }
  }

  bool get _hasUnread =>
      _notifications.any((notification) => notification['is_read'] != true);

  Future<void> _markAllAsRead() async {
    await _service.markAllAsRead();
    if (!mounted) return;

    setState(() {
      _notifications =
          _notifications
              .map((notification) => {...notification, 'is_read': true})
              .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تعليم كل الإشعارات كمقروءة'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = notification['id'] as String?;
    final payload = notification['payload'] as String?;

    if (id != null && notification['is_read'] != true) {
      // ownerUserId : seule une notification personnelle est marquée en base ;
      // pour une notification publique l'état reste sur l'appareil.
      await _service.markAsRead(
        id,
        ownerUserId: notification['user_id'] as String?,
      );
      if (mounted) {
        setState(() => notification['is_read'] = true);
      }
    }

    if (!mounted) return;

    // `push` et non `go` : l'écran ouvert s'empile au-dessus des notifications,
    // donc le bouton retour ramène à la liste.
    final route = NotificationNavigation.routeForPayload(payload);
    if (route == null) return;

    await context.push(route);

    // De retour sur la liste : rafraîchir (des notifications ont pu arriver)
    if (mounted) await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        title: 'الإشعارات',
        actions: [
          if (_hasUnread)
            IconButton(
              tooltip: 'تعليم الكل كمقروء',
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator(message: 'جاري تحميل الإشعارات...')
              : ModernPullToRefresh(
                onRefresh: _loadNotifications,
                child:
                    _errorMessage != null
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            EmptyState(
                              icon: Icons.wifi_off,
                              title: 'تعذّر تحميل الإشعارات',
                              subtitle: _errorMessage,
                              iconColor: AppTheme.errorColor,
                              action: PrimaryButton(
                                text: 'إعادة المحاولة',
                                onPressed: _loadNotifications,
                              ),
                            ),
                          ],
                        )
                        : _notifications.isEmpty
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            EmptyState(
                              icon: Icons.notifications_off_outlined,
                              title: 'لا توجد إشعارات',
                              subtitle: 'ستظهر هنا آخر إشعارات التطبيق',
                            ),
                          ],
                        )
                        : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(
                              _notifications[index],
                            );
                          },
                        ),
              ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] as String? ?? 'إشعار';
    final body = notification['body'] as String? ?? '';
    final type = notification['type'] as String? ?? 'info';
    final isRead = notification['is_read'] == true;
    final createdAt = notification['created_at'] as String?;

    final color = _colorForType(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ModernCard(
        onTap: () => _openNotification(notification),
        backgroundColor: isRead ? null : color.withValues(alpha: 0.06),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconForType(type), color: color, size: 22),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      body,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      _formatDate(createdAt),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'error':
        return AppTheme.errorColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'success':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_none;
    }
  }

  /// Date relative en arabe (« قبل 5 دقائق »), et date complète au-delà d'une
  /// semaine.
  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) return 'قبل ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'قبل ${difference.inHours} ساعة';
    if (difference.inDays < 7) return 'قبل ${difference.inDays} يوم';

    return DateFormat('yyyy/MM/dd - HH:mm').format(date.toLocal());
  }
}

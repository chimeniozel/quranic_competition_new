import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/push_notification_service.dart';

/// Cloche de la barre d'application, avec pastille du nombre de notifications
/// non lues. Ouvre l'écran « الإشعارات ».
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  final PushNotificationService _service = PushNotificationService();

  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rafraîchir au retour dans l'application : des notifications ont pu
    // arriver pendant qu'elle était en arrière-plan.
    if (state == AppLifecycleState.resumed) _refreshCount();
  }

  Future<void> _refreshCount() async {
    final count = await _service.getUnreadCount();
    if (!mounted) return;
    setState(() => _unreadCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'الإشعارات',
          icon: const Icon(Icons.notifications_none),
          onPressed: () async {
            await context.push('/notifications');
            await _refreshCount();
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

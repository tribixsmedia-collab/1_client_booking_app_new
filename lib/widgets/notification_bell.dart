import 'package:flutter/material.dart';

import '../screens/notification_screen.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/profile_gate.dart';

/// Bell button styled to match the cart avatar in home_tab.dart.
///
/// Drop it straight into the header Row:
///     const NotificationBell(),
///
/// The badge updates itself anywhere the widget appears — it listens to the
/// same ValueNotifier the service keeps, so no state management is needed.
class NotificationBell extends StatefulWidget {
  /// Circle colour behind the bell. Defaults to the light tint used on
  /// white backgrounds; pass a translucent white when sitting on the
  /// coloured hero header.
  final Color? backgroundColor;
  final Color? iconColor;

  const NotificationBell({super.key, this.backgroundColor, this.iconColor});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unreadCount,
      builder: (context, count, _) {
        return GestureDetector(
          onTap: () async {
            // Guests have no notification list to open, so ask them to sign
            // in here rather than pushing a screen that can only error.
            if (!await requireSignIn(context)) return;
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
            // The user may have read some while they were in there.
            NotificationService.instance.refreshUnreadCount();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    widget.backgroundColor ??
                    AppColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: widget.iconColor ?? AppColors.primary,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

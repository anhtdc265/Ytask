import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/theme/app_theme.dart';
import '../../services/notification_service.dart';

class ProfileNotificationScreen extends StatefulWidget {
  const ProfileNotificationScreen({super.key});

  @override
  State<ProfileNotificationScreen> createState() =>
      _ProfileNotificationScreenState();
}

class _ProfileNotificationScreenState extends State<ProfileNotificationScreen>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotificationStatus();
    }
  }

  Future<void> _loadNotificationStatus() async {
    final enabled = await _areNotificationsEnabled();

    if (!mounted) return;

    setState(() => _notificationsEnabled = enabled);
  }

  Future<bool> _areNotificationsEnabled() async {
    try {
      await NotificationService.instance.init();

      final androidImplementation = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final androidEnabled =
      await androidImplementation?.areNotificationsEnabled();

      return androidEnabled ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;
    final statusText = _notificationsEnabled ? 'Đã bật' : 'Chưa bật';
    final statusColor = _notificationsEnabled ? colors.brand : colors.textMuted;

    return Scaffold(
      backgroundColor: colors.appBackground,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _NotificationBackButton(
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 34),
            Text(
              'Thông báo',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trạng thái nhắc việc của YTask.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            _NotificationStatusCard(
              statusText: statusText,
              statusColor: statusColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationStatusCard extends StatelessWidget {
  const _NotificationStatusCard({
    required this.statusText,
    required this.statusColor,
  });

  final String statusText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.scheduleCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.scheduleCardBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: colors.brand,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhắc việc',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bật nhắc việc trong nhiệm vụ, YTask sẽ hỏi quyền thông báo. Chọn Cho phép để nhận nhắc đúng giờ.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBackButton extends StatelessWidget {
  const _NotificationBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Material(
      color: colors.brand,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/theme_service.dart';
import '../../../shared/widgets/ytask_avatar.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.onTap,
    this.avatarSize = 112,
  });

  final UserModel? user;
  final VoidCallback onTap;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              YTaskAvatar(
                avatarId: user?.avatarUrl,
                size: avatarSize,
                showShadow: true,
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.appBackground, width: 3),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              user?.name ?? 'Người dùng',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              user?.email ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.children,
    this.showTitle = true,
  });

  final String title;
  final List<Widget> children;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: colors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: colors.scheduleCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.scheduleCardBorder),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                for (int index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 72,
                      color: colors.inputBorder.withValues(alpha: 0.75),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.trailing,
    this.subtitleMaxLines = 2,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;
    final active = enabled && onTap != null;

    return ListTile(
      onTap: active ? onTap : null,
      minTileHeight: 72,
      minLeadingWidth: 44,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _ProfileIconCircle(icon: icon),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: active ? colors.textPrimary : colors.textMuted,
          height: 1.2,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          maxLines: subtitleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
            height: 1.25,
          ),
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textMuted,
            size: 24,
          ),
    );
  }
}

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProfileMenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class ProfileSecurityTile extends StatelessWidget {
  const ProfileSecurityTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;
    final isEnabled = onTap != null;

    return ProfileMenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      subtitleMaxLines: 1,
      enabled: isEnabled,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingLabel != null) ...[
            Text(
              trailingLabel!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isEnabled ? colors.brand : colors.textMuted,
              ),
            ),
            const SizedBox(width: 2),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textMuted,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class ThemeOptionBottomSheet extends StatelessWidget {
  const ThemeOptionBottomSheet({
    super.key,
    required this.currentMode,
  });

  final ThemeMode currentMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;
    final mediaQuery = MediaQuery.of(context);
    final bottomSafe = mediaQuery.padding.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.86;
    final themeService = ThemeService();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colors.scheduleCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomSafe),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.textMuted.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Chọn giao diện',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'YTask sẽ áp dụng lựa chọn này cho toàn bộ ứng dụng.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _ThemeSheetOption(
                  icon: Icons.phone_android_rounded,
                  title: 'Theo hệ thống',
                  subtitle: 'Tự đổi sáng/tối theo thiết bị',
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () => Navigator.pop(context, ThemeMode.system),
                ),
                _ThemeSheetOption(
                  icon: Icons.light_mode_outlined,
                  title: themeService.labelOf(ThemeMode.light),
                  subtitle: 'Luôn dùng giao diện sáng',
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () => Navigator.pop(context, ThemeMode.light),
                ),
                _ThemeSheetOption(
                  icon: Icons.dark_mode_outlined,
                  title: themeService.labelOf(ThemeMode.dark),
                  subtitle: 'Luôn dùng giao diện tối',
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () => Navigator.pop(context, ThemeMode.dark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('ĐĂNG XUẤT'),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.danger,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class ProfileBackButton extends StatelessWidget {
  const ProfileBackButton({
    super.key,
    required this.onTap,
    this.size = 42,
  });

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Material(
      color: colors.brand,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _ProfileIconCircle extends StatelessWidget {
  const _ProfileIconCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colors.brand, size: 22),
    );
  }
}

class _ThemeSheetOption extends StatelessWidget {
  const _ThemeSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ytaskColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected
            ? colors.brand.withValues(alpha: 0.12)
            : colors.appBackground.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colors.brand, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: colors.brand,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
